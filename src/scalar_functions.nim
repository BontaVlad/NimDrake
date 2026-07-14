import std/[macros, strformat]
import /[ffi, database, types, qresult, exceptions]
import /tools/wrench

type
  ScalarFunctionBase* = object of RootObj
    name*: string
    handle*: duckdb_scalar_function

  ScalarFunction* = ref object of ScalarFunctionBase

proc `=destroy`(s: ScalarFunctionBase) =
  if s.handle != nil:
    duckdb_destroy_scalar_function(s.handle.addr)

proc `=wasMoved`(s: var ScalarFunctionBase) =
  s.handle = nil
  s.name = ""

proc `=copy`(dest: var ScalarFunctionBase, source: ScalarFunctionBase) {.error.}
proc `=dup`(s: ScalarFunctionBase): ScalarFunctionBase {.error.}

proc newScalarFunction*(name: string): ScalarFunction =
  result = ScalarFunction(name: name, handle: duckdb_create_scalar_function())

proc register*(con: Connection, fun: ScalarFunction) =
  check(
    duckdb_register_scalar_function(con.rawHandle, fun.handle),
    fmt"Failed to register function '{fun.name}'",
  )

macro registerScalar*(con: typed, procSym: typed): untyped =
  ## Register a Nim proc as a DuckDB scalar UDF.
  ##
  ## Usage:
  ##   proc doubleValue(a, b: int64): int64 = a * b
  ##   conn.registerScalar(doubleValue)
  ##   conn.execute("SELECT doubleValue(i, i) FROM range(3) t(i)")
  ##
  ## The user proc is a normal, callable, unit-testable Nim proc. The macro
  ## introspects its param/return types, emits a `{.cdecl.}` DuckDB wrapper
  ## bound to compile-time-dispatched `Vector[kt]` views, builds the
  ## `ScalarFunction`, and registers it against `con`.
  ##
  ## NULL contract: SQL null-propagating. If ANY input cell is NULL the body
  ## is NOT called and the output cell is NULL. Use `Option[T]` params (planned,
  ## v2) for null-aware bodies.
  ##
  ## Type contract: param/return types must be supported by `duckTypeDotExpr`
  ## (bool, ints, uints, floats, string, seq[byte], Timestamp/DateTime, Time,
  ## TimeInterval, Int128, UInt128, Uuid). Decimal/Enum/complex kinds are
  ## rejected at compile time. Zero-param procs are allowed (constant function).
  ##
  ## Exception contract: if the body raises, the wrapper calls
  ## `duckdb_scalar_function_set_error` with `currentExceptionMsg()` and aborts.
  let procDef = procSym.getImpl
  if procDef.kind != nnkProcDef:
    error("registerScalar expects a proc; got " & $procDef.kind, procSym)
  if procDef[2].kind != nnkEmpty:        # generic params
    error("registerScalar procs cannot be generic.", procSym)

  let formalParams = procDef[3]
  let nameStr = procSym.strVal

  # return type
  if formalParams[0].kind == nnkEmpty:
    error("registerScalar proc must have a non-void return type.", procSym)
  let retTypeNode = getTypeInst(formalParams[0])
  let retKt = duckTypeDotExpr(retTypeNode)

  # params — collect (sym, kt) pairs, reject defaults
  type Param = tuple[sym: NimNode, kt: NimNode]
  var params: seq[Param]
  for j in 1 ..< formalParams.len:
    let id = formalParams[j]
    if id[^1].kind != nnkEmpty:
      error("registerScalar proc params cannot have default values.", id)
    let tyNode = getTypeInst(id[^2])
    let kt = duckTypeDotExpr(tyNode)
    for k in 0 ..< id.len - 2:
      params.add((id[k], kt))

  # wrapper proc — gensymmed, cdecl, local
  let wrapperSym = genSym(nskProc, "scalarWrapper_" & nameStr)
  let infoSym  = ident"info"
  let rawSym   = ident"rawChunk"
  let outSym   = ident"output"
  let sizeSym  = ident"size"
  let iSym     = ident"i"

  let wrapperBody = newStmtList()

  # let size = int(duckdb_data_chunk_get_size(rawChunk))
  wrapperBody.add(newLetStmt(sizeSym,
    newCall(bindSym"int",
      newCall(bindSym"duckdb_data_chunk_get_size", rawSym))))

  # one let per input: let pJ = initVector[ktJ](
  #   duckdb_data_chunk_get_vector(rawChunk, idx_t(j)), size)
  var inputIdents: seq[NimNode]
  for j, p in params:
    let pSym = genSym(nskLet, "p" & $j)
    inputIdents.add(pSym)
    let getVec = newCall(bindSym"duckdb_data_chunk_get_vector",
      rawSym, newCall(bindSym"idx_t", newLit j))
    wrapperBody.add(newLetStmt(pSym,
      newCall(nnkBracketExpr.newTree(bindSym"initVector", p.kt),
        getVec, sizeSym)))

  # var outVec = initVector[retKt](output, size)
  let outVecSym = genSym(nskVar, "outVec")
  wrapperBody.add(newVarStmt(outVecSym,
    newCall(nnkBracketExpr.newTree(bindSym"initVector", retKt),
      outSym, sizeSym)))

  # per-row loop — if null then setNull else try-write
  let loopBody = newStmtList()

  var nullCheck: NimNode = nil
  for pSym in inputIdents:
    let term = nnkPrefix.newTree(ident"not",
      newCall(newDotExpr(pSym, ident"valid"), iSym))
    if nullCheck.isNil:
      nullCheck = term
    else:
      nullCheck = nnkInfix.newTree(ident"or", nullCheck, term)

  # callArgs: p0[i], p1[i], …
  var callArgs: seq[NimNode]
  for pi in inputIdents:
    callArgs.add(nnkBracketExpr.newTree(pi, iSym))
  let write = nnkAsgn.newTree(
    nnkBracketExpr.newTree(outVecSym, iSym),
    newCall(procSym, callArgs))
  let tryBody = newStmtList(write)
  let excBody = newStmtList(
    newCall(bindSym"duckdb_scalar_function_set_error",
      infoSym,
      newDotExpr(      newCall(ident"getCurrentExceptionMsg"), ident"cstring")),
    nnkReturnStmt.newTree(newEmptyNode()))
  let exceptBranch = nnkExceptBranch.newTree(excBody)

  if nullCheck.isNil:
    # zero-param scalar — no null check, just try/write per row
    loopBody.add(nnkTryStmt.newTree(tryBody, exceptBranch))
  else:
    loopBody.add(nnkIfStmt.newTree(
      nnkElifBranch.newTree(nullCheck,
        newCall(newDotExpr(outVecSym, ident"setNull"), iSym)),
      nnkElse.newTree(
        newStmtList(nnkTryStmt.newTree(tryBody, exceptBranch)))))

  wrapperBody.add(nnkForStmt.newTree(
    iSym, nnkInfix.newTree(ident"..<", newLit 0, sizeSym), loopBody))

  # assemble the wrapper proc
  let wrapperParams = @[
    newEmptyNode(),
    newIdentDefs(infoSym, bindSym"duckdb_function_info"),
    newIdentDefs(rawSym,  bindSym"duckdb_data_chunk"),
    newIdentDefs(outSym, bindSym"duckdb_vector")]
  let wrapperProc = newProc(
    name = wrapperSym,
    params = wrapperParams,
    body = wrapperBody,
    pragmas = nnkPragma.newTree(ident"cdecl"))

  # build + register block (runs at call site)
  let fSym = genSym(nskLet, "f_" & nameStr)
  let buildStmts = newStmtList(
    newLetStmt(fSym,
      newCall(bindSym"newScalarFunction", newLit nameStr)),
    newCall(bindSym"duckdb_scalar_function_set_name",
      newDotExpr(fSym, ident"handle"),
      newDotExpr(newLit nameStr, ident"cstring")))

  for p in params:
    buildStmts.add(
      newCall(bindSym"duckdb_scalar_function_add_parameter",
        newDotExpr(fSym, ident"handle"),
        newDotExpr(newCall(bindSym"newLogicalType", p.kt), ident"handle")))

  buildStmts.add(
    newCall(bindSym"duckdb_scalar_function_set_return_type",
      newDotExpr(fSym, ident"handle"),
      newDotExpr(newCall(bindSym"newLogicalType", retKt), ident"handle")))
  buildStmts.add(
    newCall(bindSym"duckdb_scalar_function_set_function",
      newDotExpr(fSym, ident"handle"), wrapperSym))
  buildStmts.add(
    newCall(bindSym"register", con, fSym))

  result = newStmtList(wrapperProc, buildStmts)
