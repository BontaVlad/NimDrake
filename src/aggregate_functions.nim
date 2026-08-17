## DuckDB aggregate UDFs — ergonomic and vectorized tiers.
##
## An aggregate UDF is built from four (or five) plain Nim procs:
##
##   proc `init`(state: var S)
##   proc `update`(state: var S, p0: T0, ...)               # Tier A (per-row)
##   proc `update`(states: ``States[S]``, v0: ``Vector[kt0]``, ...)  # Tier B (vectorized)
##   proc `combine`(dest: var S, src: S)                    # Tier A
##   proc `combine`(dest, src: ``States[S]``)                   # Tier B
##   proc `finalize`(state: ``S``): R                           # Tier A; R = ``T`` or ``Option[T]``
##   proc `finalize`(src: ``States[S]``, outVec: var ``Vector[kt]``, count, offset: int)  # Tier B
##   proc `destroy`(state: var S)                           # optional, owning states
##
## A single macro `registerAggregate` auto-detects the tier from the update
## proc's first parameter: `var S` → Tier A, `States[S]` → Tier B.
##
## NULL handling: Tier A filters NULL rows before calling `update` (standard
## SQL semantics). If any `update` arg is `Option[T]`, NULLs are passed
## through as `none(T)` (special handling auto-detected). Tier B users check
## `Vector.valid(i)` themselves.
##
## NULL-on-empty: a `finalize` returning `Option[T]` writes the value when
## `isSome` else marks the result cell NULL. A plain `T` return always writes
## a value. In Tier B the user calls `outVec.setNull` themselves.
##
## Exception contract: any `CatchableError` raised in a callback is caught at
## the wrapper boundary and forwarded via `duckdb_aggregate_function_set_error`
## with `getCurrentExceptionMsg()`, aborting the query and surfacing as
## `OperationError` at the Nim call site.
##
## Destructor contract: pass `destroy = myDestroy` only when `S` owns Nim-heap
## resources (e.g. `seq`/`ref` fields). POD states need no destroy.

import std/[macros, strformat, options]
import /[ffi, types, database, qresult, exceptions]
import /tools/wrench

# ---------------------------------------------------------------------------
# FunctionInfo — typed view of the duckdb_function_info handle
# ---------------------------------------------------------------------------

type
  FunctionInfo* = object ## Non-owning view of a `duckdb_function_info`
    ## handle passed to every callback.
    handle*: duckdb_function_info

proc getBindData*(info: FunctionInfo): pointer {.inline.} =
  ## The per-query extra data attached via `setBindData` at bind time.
  duckdb_function_get_extra_info(info.handle)

proc setError*(info: FunctionInfo, msg: string) {.inline.} =
  ## Fails the aggregate query with `msg`; the query is aborted.
  duckdb_aggregate_function_set_error(info.handle, msg.cstring)

# ---------------------------------------------------------------------------
# States[T] — typed zero-cost view over DuckDB's per-row state slots
# ---------------------------------------------------------------------------

type
  States*[T] = object ## Non-owning view over DuckDB's array-of-pointers
    ## state layout. `[]` compiles to `load ptr, load T` — identical to a raw
    ## cast. Bounds are checked via `doAssert` in debug builds.
    raw: ptr UncheckedArray[ptr T]
    count: int

proc initStates*[T](raw: ptr UncheckedArray[ptr T], count: int): States[T] {.inline.} =
  ## Wraps DuckDB's raw state array; mostly used by the generated wrappers.
  States[T](raw: raw, count: count)

proc len*[T](s: States[T]): int {.inline.} =
  ## Number of state slots.
  s.count

proc `[]`*[T](s: States[T], i: int): var T {.inline.} =
  ## Access state slot `i` by reference.
  when not defined(danger):
    doAssert i >= 0 and i < s.count, "States index out of bounds: " & $i
  s.raw[i][]

proc `[]=`*[T](s: States[T], i: int, val: sink T) {.inline.} =
  ## Write state slot `i`.
  when not defined(danger):
    doAssert i >= 0 and i < s.count, "States index out of bounds: " & $i
  s.raw[i][] = val

iterator items*[T](s: States[T]): var T {.inline.} =
  ## Iterates the state slots by reference.
  for i in 0 ..< s.count: yield s.raw[i][]

# ---------------------------------------------------------------------------
# AggregateFunction handle — ref to a duckdb_aggregate_function, move-only
# ---------------------------------------------------------------------------

type
  AggregateFunctionBase* = object of RootObj ## Owns a DuckDB aggregate
    ## function handle; non-copyable.
    name*: string
    handle*: duckdb_aggregate_function

  AggregateFunction* = ref object of AggregateFunctionBase ## A registered
    ## aggregate function; use `register` to expose it to SQL.

proc `=destroy`(agg: var AggregateFunctionBase) =
  if agg.handle != nil:
    duckdb_destroy_aggregate_function(agg.handle.addr)
    agg.handle = nil
  `=destroy`(agg.name)

proc `=wasMoved`(agg: var AggregateFunctionBase) =
  agg.handle = nil
  agg.name = ""

proc `=copy`(dest: var AggregateFunctionBase, source: AggregateFunctionBase) {.error.}
proc `=dup`(agg: AggregateFunctionBase): AggregateFunctionBase {.error.}

proc newAggregateFunction*(name: string): AggregateFunction {.inline.} =
  ## Creates an empty aggregate-function handle; prefer the `registerAggregate`
  ## macro, which wires the callbacks and registers in one call.
  AggregateFunction(name: name, handle: duckdb_create_aggregate_function())

proc register*(con: Connection, fun: AggregateFunction) =
  ## Registers `fun` on `con`; raises `OperationError` on name collision.
  check(duckdb_register_aggregate_function(con.rawHandle, fun.handle),
        fmt"Failed to register aggregate function '{fun.name}'")

# ---------------------------------------------------------------------------
# AST helpers — shared introspection for both tiers
# ---------------------------------------------------------------------------

proc rejectGeneric(p: NimNode) =
  if p[2].kind != nnkEmpty:
    error("registerAggregate: callbacks cannot be generic", p)

proc rejectDefaults(p: NimNode) =
  for j in 1 ..< p[3].len:
    let id = p[3][j]
    if id.len > 0 and id[^1].kind != nnkEmpty:
      error("registerAggregate: parameters cannot have default values", id)

proc unwrapVarTy(n: NimNode): NimNode =
  if n.kind == nnkVarTy: n[0] else: n

proc unwrapRefTy(n: NimNode): NimNode =
  if n.kind == nnkRefTy: n[0] else: n

proc resolveStateType(p: NimNode, label: string, needVar: bool): NimNode =
  ## Extract the state type sym from a callback's first parameter.
  let fp = p[3]
  if fp.len < 2 or fp[1].len < 2:
    error("registerAggregate: " & label & " state parameter missing", p)
  let tyNode = fp[1][1]
  let isVar = tyNode.kind == nnkVarTy
  if needVar and not isVar:
    error("registerAggregate: " & label &
      " state parameter must be `var S`; got " & repr(tyNode), p)
  if not needVar and isVar:
    error("registerAggregate: " & label &
      " state parameter must be a value `S`, not `var S`", p)
  let inner = unwrapRefTy(unwrapVarTy(tyNode))
  if inner.kind notin {nnkSym, nnkBracketExpr}:
    error("registerAggregate: " & label & " could not resolve state type sym", p)
  inner

proc stateTypeEq(a, b: NimNode): bool =
  sameType(getTypeInst(a), getTypeInst(b))

proc returnTypeNode(p: NimNode): NimNode =
  let fp = p[3]
  if fp[0].kind == nnkEmpty:
    error("registerAggregate: finalize must have a non-void return type", p)
  fp[0]

proc optionInnerType(ret: NimNode): NimNode =
  ## Returns the inner `T` of an `Option[T]` type node; nil otherwise.
  if ret.kind == nnkBracketExpr and ret.len == 2:
    let head = ret[0]
    let headSym = if head.kind == nnkSym: head
                  elif head.kind == nnkTypeOfExpr and head[0].kind == nnkSym: head[0]
                  else: nil
    if headSym != nil and headSym.strVal == "Option":
      return ret[1]
  nil

proc unwrapTypeDesc(n: NimNode): NimNode =
  ## `getTypeInst` of a Sym nested inside a generic bracket (e.g. the `T` in
  ## `Option[T]`) resolves to `typeDesc[T]` instead of `T`. Strip that wrapper.
  var t = getTypeInst(n)
  while t.kind == nnkBracketExpr and t.len == 2 and
      t[0].kind == nnkSym and t[0].strVal == "typeDesc":
    t = t[1]
  t

proc ktOf(n: NimNode, label: string): NimNode =
  result = duckTypeDotExpr(unwrapTypeDesc(n))
  if result.isNil:
    error("registerAggregate: " & label & " unsupported type: " & repr(n), n)

proc unwrapStatesSym(n: NimNode, label: string): NimNode =
  ## Given a `States[T]` type node, return the inner `T` sym.
  let inst = getTypeInst(n)
  if inst.kind != nnkBracketExpr or inst.len != 2 or
      inst[0].kind != nnkSym or inst[0].strVal != "States":
    error("registerAggregate: " & label &
      " must be a States[T] type; got " & repr(n), n)
  inst[1]

proc unwrapVectorKt(n: NimNode, label: string): NimNode =
  ## Given a raw `Vector[kt]` parameter type node, return the `kt` node.
  if n.kind != nnkBracketExpr or n.len != 2 or
      n[0].kind != nnkSym or n[0].strVal != "Vector":
    error("registerAggregate: " & label &
      " must be a Vector[kt]; got " & repr(n), n)
  let ktNode = n[1]
  if ktNode.kind notin {nnkSym, nnkDotExpr, nnkIdent}:
    error("registerAggregate: " & label &
      " Vector kt must be a DuckType field; got " & repr(ktNode), n)
  ktNode

# ---------------------------------------------------------------------------
# Codegen helpers — shared AST construction for both tiers
# ---------------------------------------------------------------------------

proc genCdeclProc(name: NimNode, retTy: NimNode, params: openArray[NimNode],
                  body: NimNode): NimNode =
  var allParams = @[retTy]
  for p in params: allParams.add(p)
  newProc(name = name, params = allParams, body = body,
          pragmas = nnkPragma.newTree(ident"cdecl"))

proc wrapErr(body: NimNode, info: NimNode): NimNode =
  ## Wrap body in try/except CatchableError → duckdb_aggregate_function_set_error.
  nnkTryStmt.newTree(body,
    nnkExceptBranch.newTree(newStmtList(newCall(
      bindSym"duckdb_aggregate_function_set_error", info,
      newDotExpr(newCall(ident"getCurrentExceptionMsg"), ident"cstring")))))

proc genStateSize(g: NimNode, stateNode: NimNode): NimNode =
  let info = ident"info"
  genCdeclProc(g, bindSym"idx_t",
    [newIdentDefs(info, bindSym"duckdb_function_info")],
    newStmtList(nnkReturnStmt.newTree(
      newCall(bindSym"idx_t", newCall(bindSym"sizeof", stateNode)))))

proc genStateInit(gi: NimNode, stateNode, initProc: NimNode): NimNode =
  let info = ident"info"
  let stateA = ident"state"
  let s = ident"s"
  let body = newStmtList(
    newLetStmt(s, nnkCast.newTree(nnkPtrTy.newTree(stateNode), stateA)),
    nnkAsgn.newTree(nnkDerefExpr.newTree(s),
      newCall(bindSym"default", newCall(bindSym"typeof",
        nnkDerefExpr.newTree(s)))),
    wrapErr(newStmtList(newCall(initProc, nnkDerefExpr.newTree(s))), info))
  genCdeclProc(gi, newEmptyNode(), [
    newIdentDefs(info, bindSym"duckdb_function_info"),
    newIdentDefs(stateA, bindSym"duckdb_aggregate_state")], body)

proc genBuildBlock(con: NimNode, name: string, argKts: seq[NimNode],
                   retKt: NimNode, g, gi, gu, gc, gf, gd: NimNode,
                   hasDestroy, specialHandling: bool): NimNode =
  let fSym = genSym(nskLet, "aggFun_" & name)
  let handle = newDotExpr(fSym, ident"handle")
  result = newStmtList(
    newLetStmt(fSym, newCall(bindSym"newAggregateFunction", newLit name)),
    newCall(bindSym"duckdb_aggregate_function_set_name", handle,
      newDotExpr(newLit name, ident"cstring")))
  for kt in argKts:
    result.add newCall(bindSym"duckdb_aggregate_function_add_parameter", handle,
      newDotExpr(newCall(bindSym"newLogicalType", kt), ident"handle"))
  result.add newCall(bindSym"duckdb_aggregate_function_set_return_type", handle,
    newDotExpr(newCall(bindSym"newLogicalType", retKt), ident"handle"))
  result.add newCall(bindSym"duckdb_aggregate_function_set_functions", handle,
    g, gi, gu, gc, gf)
  if hasDestroy:
    result.add newCall(bindSym"duckdb_aggregate_function_set_destructor",
      handle, gd)
  if specialHandling:
    result.add newCall(
      bindSym"duckdb_aggregate_function_set_special_handling", handle)
  result.add newCall(bindSym"register", con, fSym)

# ---------------------------------------------------------------------------
# registerAggregate — single macro, auto-detects tier from update signature
# ---------------------------------------------------------------------------

macro registerAggregate*(con: typed,
                         name: static[string],
                         initProc, updateProc, combineProc, finalizeProc: typed,
                         destroy: untyped = nil): untyped =
  ## Register a Nim aggregate UDF. Auto-detects tier from the update proc's
  ## first parameter: `var S` → Tier A (per-row), `States[S]` → Tier B
  ## (vectorized). Auto-detects special NULL handling from `Option[T]` args.
  let
    pI = initProc.getImpl
    pU = updateProc.getImpl
    pC = combineProc.getImpl
    pF = finalizeProc.getImpl

  for p in [pI, pU, pC, pF]:
    if p.kind != nnkProcDef:
      error("registerAggregate expects a proc; got " & $p.kind, p)
    rejectGeneric(p)
    rejectDefaults(p)

  # init: (var S)
  let stateNode = resolveStateType(pI, "init", needVar = true)

  # Detect tier from update's first param type
  let updFirstTy = pU[3][1][1]
  let isTierA = updFirstTy.kind == nnkVarTy

  let hasDestroy = destroy.kind != nnkEmpty and destroy.kind != nnkNilLit

  let g = genSym(nskProc, "agg_stateSize_")
  let gi = genSym(nskProc, "agg_init_")
  let gu = genSym(nskProc, "agg_update_")
  let gc = genSym(nskProc, "agg_combine_")
  let gf = genSym(nskProc, "agg_finalize_")
  let gd = if hasDestroy: genSym(nskProc, "agg_destroy_") else: nil

  let info = ident"info"
  let uncheckedArrPtrSt = nnkPtrTy.newTree(
    nnkBracketExpr.newTree(bindSym"UncheckedArray", nnkPtrTy.newTree(stateNode)))

  result = newStmtList()
  result.add genStateSize(g, stateNode)
  result.add genStateInit(gi, stateNode, initProc)

  if isTierA:
    # ── Tier A: per-row procs ────────────────────────────────────────────
    # update: (var S, T0, T1, ...)
    let uStateNode = resolveStateType(pU, "update", needVar = true)
    if not stateTypeEq(stateNode, uStateNode):
      error("registerAggregate: update state type differs from init", pU)

    let fpU = pU[3]
    let k = fpU.len - 2
    if k < 1:
      error("registerAggregate: update requires at least one SQL argument", pU)

    # Parse args, auto-detect specialHandling from Option[T]
    type Arg = tuple[name, ty, kt: NimNode]
    var args: seq[Arg] = @[]
    var hasOption = false
    for j in 2 ..< fpU.len:
      let id = fpU[j]
      if id.len < 3:
        error("registerAggregate: malformed update parameter", id)
      let argTyNode = id[^2]
      let optInner = optionInnerType(argTyNode)
      let inner =
        if optInner.isNil: argTyNode
        else: (hasOption = true; optInner)
      for k in 0 ..< id.len - 2:
        args.add((id[k], inner, ktOf(inner, "update arg")))
    let specialHandling = hasOption

    # combine: (var S, S)
    let cDestNode = resolveStateType(pC, "combine", needVar = true)
    if not stateTypeEq(stateNode, cDestNode):
      error("registerAggregate: combine dest state type differs from init", pC)
    let fpC = pC[3]
    if fpC.len < 3:
      error("registerAggregate: combine must take 2 parameters", pC)
    let srcTyNode = fpC[2][^2]
    if srcTyNode.kind == nnkVarTy:
      error("registerAggregate: combine source must be a value `S`, not `var S`", pC)
    if not stateTypeEq(stateNode, unwrapRefTy(srcTyNode)):
      error("registerAggregate: combine source state type differs from init", pC)

    # finalize: (S): R | (S): Option[T]
    let fStateNode = resolveStateType(pF, "finalize", needVar = false)
    if not stateTypeEq(stateNode, fStateNode):
      error("registerAggregate: finalize state type differs from init", pF)
    let retNode = returnTypeNode(pF)
    let retOptInner = optionInnerType(retNode)
    let (retNimNode, retKt, isOption) =
      if retOptInner.isNil: (retNode, ktOf(retNode, "finalize"), false)
      else: (retOptInner, ktOf(retOptInner, "finalize Option inner"), true)

    # ── Generate Tier A wrappers ──
    let inputA = ident"input"
    let statesA = ident"states"
    let srcA = ident"source"
    let tgtA = ident"target"
    let countA = ident"count"
    let outputA = ident"output"
    let offsetA = ident"offset"
    let rowCountId = ident"rowCount"
    let stId = ident"st"
    let rowIdx = ident"i"
    let nId = ident"n"
    let offId = ident"off"
    let outVecId = ident"outVec"

    # stateUpdate
    let updateBody = newStmtList()
    updateBody.add newLetStmt(stId, nnkCast.newTree(uncheckedArrPtrSt, statesA))
    updateBody.add newLetStmt(rowCountId, newCall(bindSym"int",
      newCall(bindSym"duckdb_data_chunk_get_size", inputA)))

    var inputIdents: seq[NimNode] = @[]
    for j, a in args:
      let vSym = ident("v" & $j)
      inputIdents.add(vSym)
      updateBody.add newLetStmt(vSym,
        newCall(nnkBracketExpr.newTree(bindSym"initVector", a.kt),
          newCall(bindSym"duckdb_data_chunk_get_vector", inputA,
            newCall(bindSym"idx_t", newLit j)), rowCountId))

    let loopBody = newStmtList()
    if not specialHandling:
      # skip row if ANY arg null
      var nullCheck: NimNode = nil
      for v in inputIdents:
        let term = nnkPrefix.newTree(ident"not",
          newCall(newDotExpr(v, ident"valid"), rowIdx))
        if nullCheck.isNil: nullCheck = term
        else: nullCheck = nnkInfix.newTree(ident"or", nullCheck, term)
      let rowCall = newCall(updateProc,
        nnkDerefExpr.newTree(nnkBracketExpr.newTree(stId, rowIdx)))
      for v in inputIdents:
        rowCall.add(nnkBracketExpr.newTree(v, rowIdx))
      loopBody.add nnkIfStmt.newTree(
        nnkElifBranch.newTree(nullCheck,
          newStmtList(nnkContinueStmt.newTree(newEmptyNode()))),
        nnkElse.newTree(newStmtList(rowCall)))
    else:
      # build Option[T] per arg
      var rowCall = newCall(updateProc,
        nnkDerefExpr.newTree(nnkBracketExpr.newTree(stId, rowIdx)))
      for j in 0 ..< inputIdents.len:
        let v = inputIdents[j]
        let aT = args[j].ty
        let optSym = ident("aOpt" & $j)
        loopBody.add newLetStmt(optSym,
          nnkIfExpr.newTree(
            nnkElifExpr.newTree(newCall(newDotExpr(v, ident"valid"), rowIdx),
              newCall(nnkBracketExpr.newTree(bindSym"some", aT),
                nnkBracketExpr.newTree(v, rowIdx))),
            nnkElseExpr.newTree(
              newCall(nnkBracketExpr.newTree(bindSym"none", aT)))))
        rowCall.add(optSym)
      loopBody.add rowCall

    updateBody.add nnkForStmt.newTree(rowIdx,
      nnkInfix.newTree(ident"..<", newLit 0, rowCountId), loopBody)
    result.add genCdeclProc(gu, newEmptyNode(), [
      newIdentDefs(info, bindSym"duckdb_function_info"),
      newIdentDefs(inputA, bindSym"duckdb_data_chunk"),
      newIdentDefs(statesA, nnkPtrTy.newTree(bindSym"duckdb_aggregate_state")),
    ], wrapErr(updateBody, info))

    # stateCombine
    let combineBody = newStmtList(
      newLetStmt(nId, newCall(bindSym"int", countA)),
      newLetStmt(ident"dest", nnkCast.newTree(uncheckedArrPtrSt, tgtA)),
      newLetStmt(ident"src", nnkCast.newTree(uncheckedArrPtrSt, srcA)),
      nnkForStmt.newTree(rowIdx,
        nnkInfix.newTree(ident"..<", newLit 0, nId),
        newCall(combineProc,
          nnkDerefExpr.newTree(nnkBracketExpr.newTree(ident"dest", rowIdx)),
          nnkDerefExpr.newTree(nnkBracketExpr.newTree(ident"src", rowIdx)))))
    result.add genCdeclProc(gc, newEmptyNode(), [
      newIdentDefs(info, bindSym"duckdb_function_info"),
      newIdentDefs(srcA, nnkPtrTy.newTree(bindSym"duckdb_aggregate_state")),
      newIdentDefs(tgtA, nnkPtrTy.newTree(bindSym"duckdb_aggregate_state")),
      newIdentDefs(countA, bindSym"idx_t"),
    ], wrapErr(combineBody, info))

    # stateFinalize
    let finalizeBody = newStmtList(
      newLetStmt(nId, newCall(bindSym"int", countA)),
      newLetStmt(offId, newCall(bindSym"int", offsetA)),
      newLetStmt(ident"src", nnkCast.newTree(uncheckedArrPtrSt, srcA)),
      newVarStmt(outVecId, newCall(nnkBracketExpr.newTree(
        bindSym"initVector", retKt), outputA,
        nnkInfix.newTree(ident"+", offId, nId))))
    let finLoop = newStmtList()
    let callRes = ident"r"
    finLoop.add newLetStmt(callRes, newCall(finalizeProc,
      nnkDerefExpr.newTree(nnkBracketExpr.newTree(ident"src", rowIdx))))
    if isOption:
      finLoop.add nnkIfStmt.newTree(
        nnkElifBranch.newTree(newDotExpr(callRes, ident"isSome"),
          nnkAsgn.newTree(nnkBracketExpr.newTree(outVecId,
              nnkInfix.newTree(ident"+", offId, rowIdx)),
            newDotExpr(callRes, ident"get"))),
        nnkElse.newTree(newCall(newDotExpr(outVecId, ident"setNull"),
          nnkInfix.newTree(ident"+", offId, rowIdx))))
    else:
      finLoop.add nnkAsgn.newTree(
        nnkBracketExpr.newTree(outVecId, nnkInfix.newTree(ident"+", offId, rowIdx)),
        callRes)
    finalizeBody.add nnkForStmt.newTree(rowIdx,
      nnkInfix.newTree(ident"..<", newLit 0, nId), finLoop)
    result.add genCdeclProc(gf, newEmptyNode(), [
      newIdentDefs(info, bindSym"duckdb_function_info"),
      newIdentDefs(srcA, nnkPtrTy.newTree(bindSym"duckdb_aggregate_state")),
      newIdentDefs(outputA, bindSym"duckdb_vector"),
      newIdentDefs(countA, bindSym"idx_t"),
      newIdentDefs(offsetA, bindSym"idx_t"),
    ], wrapErr(finalizeBody, info))

    # stateDestroy (optional)
    if hasDestroy:
      let destroyBody = newStmtList(
        newLetStmt(nId, newCall(bindSym"int", countA)),
        newLetStmt(stId, nnkCast.newTree(uncheckedArrPtrSt, statesA)),
        nnkForStmt.newTree(rowIdx,
          nnkInfix.newTree(ident"..<", newLit 0, nId),
          newCall(destroy,
            nnkDerefExpr.newTree(nnkBracketExpr.newTree(stId, rowIdx)))))
      result.add genCdeclProc(gd, newEmptyNode(), [
        newIdentDefs(statesA, nnkPtrTy.newTree(bindSym"duckdb_aggregate_state")),
        newIdentDefs(countA, bindSym"idx_t"),
      ], destroyBody)

    # Build & register
    var argKts: seq[NimNode] = @[]
    for a in args: argKts.add(a.kt)
    result.add genBuildBlock(con, name, argKts, retKt,
      g, gi, gu, gc, gf, gd, hasDestroy, specialHandling)

  else:
    # ── Tier B: vectorized procs ─────────────────────────────────────────
    # update: (States[S], Vector[kt0], Vector[kt1], ...)
    let uStatesNode = unwrapStatesSym(updFirstTy, "update state param")
    if not stateTypeEq(stateNode, uStatesNode):
      error("registerAggregate: update state type differs from init", pU)

    let fpU = pU[3]
    let k = fpU.len - 2
    if k < 1:
      error("registerAggregate: update requires States[S] + at least one " &
        "Vector[kt] argument", pU)

    type VecArg = tuple[name, kt: NimNode]
    var vecArgs: seq[VecArg] = @[]
    for j in 2 ..< fpU.len:
      let id = fpU[j]
      if id.len < 3:
        error("registerAggregate: malformed update parameter", id)
      let ktNode = unwrapVectorKt(id[^2], "update Vector arg")
      for k in 0 ..< id.len - 2:
        vecArgs.add((id[k], ktNode))

    # combine: (States[S], States[S]) — may be collapsed as `dest, src: States[S]`
    let fpC = pC[3]
    if fpC.len < 2:
      error("registerAggregate: combine must take 2 parameters", pC)
    # Collect all param type nodes, flattening collapsed IdentDefs
    var combineTypes: seq[NimNode] = @[]
    for j in 1 ..< fpC.len:
      let id = fpC[j]
      for _ in 0 ..< id.len - 2:
        combineTypes.add(id[^2])
    if combineTypes.len != 2:
      error("registerAggregate: combine must take exactly 2 parameters; got " &
        $combineTypes.len, pC)
    let cDestNode = unwrapStatesSym(combineTypes[0], "combine dest")
    let cSrcNode = unwrapStatesSym(combineTypes[1], "combine source")
    if not stateTypeEq(stateNode, cDestNode):
      error("registerAggregate: combine dest state type differs from init", pC)
    if not stateTypeEq(stateNode, cSrcNode):
      error("registerAggregate: combine source state type differs from init", pC)

    # finalize: (States[S], var Vector[kt], int, int) -> void
    let fpF = pF[3]
    if fpF[0].kind != nnkEmpty:
      error("registerAggregate: finalize must return void; got " &
        repr(fpF[0]), pF)
    # Flatten collapsed IdentDefs to get individual param types
    var finTypes: seq[NimNode] = @[]
    for j in 1 ..< fpF.len:
      let id = fpF[j]
      for _ in 0 ..< id.len - 2:
        finTypes.add(id[^2])
    if finTypes.len != 4:
      error("registerAggregate: finalize must take 4 parameters " &
        "(States[S], var Vector[kt], count, offset); got " & $finTypes.len, pF)
    let fSrcNode = unwrapStatesSym(finTypes[0], "finalize src")
    if not stateTypeEq(stateNode, fSrcNode):
      error("registerAggregate: finalize state type differs from init", pF)
    var outVecInner = finTypes[1]
    if outVecInner.kind == nnkVarTy: outVecInner = outVecInner[0]
    let retKt = unwrapVectorKt(outVecInner, "finalize outVec")

    # ── Generate Tier B wrappers ──
    let inputA = ident"input"
    let statesA = ident"states"
    let srcA = ident"source"
    let tgtA = ident"target"
    let countA = ident"count"
    let outputA = ident"output"
    let offsetA = ident"offset"
    let rowCountId = ident"rowCount"
    let nId = ident"n"
    let offId = ident"off"
    let outVecId = ident"outVecDt"
    let srcId = ident"srcSt"
    let destId = ident"destSt"

    # stateUpdate
    let updateBody = newStmtList()
    updateBody.add newLetStmt(rowCountId, newCall(bindSym"int",
      newCall(bindSym"duckdb_data_chunk_get_size", inputA)))
    updateBody.add newLetStmt(srcId, newCall(
      nnkBracketExpr.newTree(bindSym"initStates", stateNode),
      nnkCast.newTree(uncheckedArrPtrSt, statesA), rowCountId))
    for j in 0 ..< vecArgs.len:
      let vSym = ident("v" & $j)
      updateBody.add newLetStmt(vSym,
        newCall(nnkBracketExpr.newTree(bindSym"initVector", vecArgs[j].kt),
          newCall(bindSym"duckdb_data_chunk_get_vector", inputA,
            newCall(bindSym"idx_t", newLit j)), rowCountId))
    var updateCall = newCall(updateProc, srcId)
    for j in 0 ..< vecArgs.len:
      updateCall.add(ident("v" & $j))
    updateBody.add updateCall
    result.add genCdeclProc(gu, newEmptyNode(), [
      newIdentDefs(info, bindSym"duckdb_function_info"),
      newIdentDefs(inputA, bindSym"duckdb_data_chunk"),
      newIdentDefs(statesA, nnkPtrTy.newTree(bindSym"duckdb_aggregate_state")),
    ], wrapErr(updateBody, info))

    # stateCombine
    let combineBody = newStmtList(
      newLetStmt(nId, newCall(bindSym"int", countA)),
      newLetStmt(destId, newCall(
        nnkBracketExpr.newTree(bindSym"initStates", stateNode),
        nnkCast.newTree(uncheckedArrPtrSt, tgtA), nId)),
      newLetStmt(srcId, newCall(
        nnkBracketExpr.newTree(bindSym"initStates", stateNode),
        nnkCast.newTree(uncheckedArrPtrSt, srcA), nId)),
      newCall(combineProc, destId, srcId))
    result.add genCdeclProc(gc, newEmptyNode(), [
      newIdentDefs(info, bindSym"duckdb_function_info"),
      newIdentDefs(srcA, nnkPtrTy.newTree(bindSym"duckdb_aggregate_state")),
      newIdentDefs(tgtA, nnkPtrTy.newTree(bindSym"duckdb_aggregate_state")),
      newIdentDefs(countA, bindSym"idx_t"),
    ], wrapErr(combineBody, info))

    # stateFinalize
    let finalizeBody = newStmtList(
      newLetStmt(nId, newCall(bindSym"int", countA)),
      newLetStmt(offId, newCall(bindSym"int", offsetA)),
      newLetStmt(srcId, newCall(
        nnkBracketExpr.newTree(bindSym"initStates", stateNode),
        nnkCast.newTree(uncheckedArrPtrSt, srcA), nId)),
      newVarStmt(outVecId, newCall(
        nnkBracketExpr.newTree(bindSym"initVector", retKt),
        outputA, nnkInfix.newTree(ident"+", offId, nId))),
      newCall(finalizeProc, srcId, outVecId, nId, offId))
    result.add genCdeclProc(gf, newEmptyNode(), [
      newIdentDefs(info, bindSym"duckdb_function_info"),
      newIdentDefs(srcA, nnkPtrTy.newTree(bindSym"duckdb_aggregate_state")),
      newIdentDefs(outputA, bindSym"duckdb_vector"),
      newIdentDefs(countA, bindSym"idx_t"),
      newIdentDefs(offsetA, bindSym"idx_t"),
    ], wrapErr(finalizeBody, info))

    # stateDestroy (optional)
    if hasDestroy:
      let destroyBody = newStmtList(
        newLetStmt(nId, newCall(bindSym"int", countA)),
        newLetStmt(srcId, newCall(
          nnkBracketExpr.newTree(bindSym"initStates", stateNode),
          nnkCast.newTree(uncheckedArrPtrSt, statesA), nId)),
        newCall(destroy, srcId))
      result.add genCdeclProc(gd, newEmptyNode(), [
        newIdentDefs(statesA, nnkPtrTy.newTree(bindSym"duckdb_aggregate_state")),
        newIdentDefs(countA, bindSym"idx_t"),
      ], destroyBody)

    # Build & register
    var argKts: seq[NimNode] = @[]
    for va in vecArgs: argKts.add(va.kt)
    result.add genBuildBlock(con, name, argKts, retKt,
      g, gi, gu, gc, gf, gd, hasDestroy, false)
