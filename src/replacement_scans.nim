## Replacement scans let you intercept table names that DuckDB cannot resolve
## against the catalog and rewrite them as calls to a registered table function
## (most commonly ``range``). Use this to expose virtual tables whose content is
## derived from the table name alone, e.g. ``SELECT * FROM "5"`` → ``range(5)``.
##
## Register a replacement scan before issuing queries:
##
## .. code-block:: nim
##
##   let db = newDatabase()
##   let conn = db.connect()
##   db.register(newReplacementScan(
##     proc(info, tableName: string, data: pointer) =
##       try:
##         info.setFunctionName("range")
##         info.addParameter(parseInt(tableName).int64)
##       except ValueError:
##         discard  # let DuckDB treat the name as a real table
##   ))
##   for chunk in conn.execute(""" SELECT * FROM "5" """):
##     assert chunk.bindAs(0, DuckType.BigInt).toSeq == @[0'i64, 1, 2, 3, 4]
##
## Thread-safety: replacement scans are registered on the Database (not
## Connection) and DuckDB may invoke the callback from any thread running a
## query. Ensure your callback is thread-safe.
##
## .. note::
##   Replacement scans are invoked in registration order until one calls
##   ``setFunctionName``. Any scan that returns without calling
##   ``setFunctionName`` signals to DuckDB that it should try the next scan
##   (or fall through to the regular table-lookup path).

import std/[macros]
import /[ffi, database, complex]

type
  ReplacementScanInfo* = object ## Context for one table-name interception.
    handle*: duckdb_replacement_scan_info

  ReplacementScanBase* = object of RootObj ## Base for a replacement scan;
    ## carries the user callback and its payload.
    callback*: proc(info: ReplacementScanInfo, tableName: string,
                    data: pointer) {.cdecl.}
    extraData*: ref RootObj

  ReplacementScan* = ref object of ReplacementScanBase ## A registered
    ## replacement scan; use `register` to install it on a `Database`.

proc `=wasMoved`(rs: var ReplacementScanBase) =
  rs.callback = nil
  rs.extraData = nil

proc `=copy`(dest: var ReplacementScanBase; src: ReplacementScanBase) {.error.}
proc `=dup`(rs: ReplacementScanBase): ReplacementScanBase {.error.}

# ---------------------------------------------------------------------------
# ReplacementScanInfo accessors
# ---------------------------------------------------------------------------

proc setFunctionName*(info: ReplacementScanInfo, name: string) {.inline.} =
  ## Declares that this scan handles `name`; bypasses the default catalog and
  ## any remaining replacement scans.
  duckdb_replacement_scan_set_function_name(info.handle, name.cstring)

proc setError*(info: ReplacementScanInfo, msg: string) {.inline.} =
  ## Fails the lookup with `msg`; the query aborts with the message.
  duckdb_replacement_scan_set_error(info.handle, msg.cstring)

proc addParameter*(info: ReplacementScanInfo, value: duckdb_value) {.inline.} =
  ## Appends a raw `duckdb_value` as a parameter of the rewritten function call.
  duckdb_replacement_scan_add_parameter(info.handle, value)
  duckdb_destroy_value(value.addr)

proc addParameter*(info: ReplacementScanInfo, v: bool) {.inline.} =
  ## Appends a bool parameter.
  let val = duckdb_create_bool(v)
  duckdb_replacement_scan_add_parameter(info.handle, val)
  duckdb_destroy_value(val.addr)

proc addParameter*(info: ReplacementScanInfo, v: int8) {.inline.} =
  ## Appends an int8 parameter.
  let val = duckdb_create_int8(v)
  duckdb_replacement_scan_add_parameter(info.handle, val)
  duckdb_destroy_value(val.addr)

proc addParameter*(info: ReplacementScanInfo, v: int16) {.inline.} =
  ## Appends an int16 parameter.
  let val = duckdb_create_int16(v)
  duckdb_replacement_scan_add_parameter(info.handle, val)
  duckdb_destroy_value(val.addr)

proc addParameter*(info: ReplacementScanInfo, v: int32) {.inline.} =
  ## Appends an int32 parameter.
  let val = duckdb_create_int32(v)
  duckdb_replacement_scan_add_parameter(info.handle, val)
  duckdb_destroy_value(val.addr)

proc addParameter*(info: ReplacementScanInfo, v: int64) {.inline.} =
  ## Appends an int64 parameter.
  let val = duckdb_create_int64(v)
  duckdb_replacement_scan_add_parameter(info.handle, val)
  duckdb_destroy_value(val.addr)

proc addParameter*(info: ReplacementScanInfo, v: uint8) {.inline.} =
  ## Appends a uint8 parameter.
  let val = duckdb_create_uint8(v)
  duckdb_replacement_scan_add_parameter(info.handle, val)
  duckdb_destroy_value(val.addr)

proc addParameter*(info: ReplacementScanInfo, v: uint16) {.inline.} =
  ## Appends a uint16 parameter.
  let val = duckdb_create_uint16(v)
  duckdb_replacement_scan_add_parameter(info.handle, val)
  duckdb_destroy_value(val.addr)

proc addParameter*(info: ReplacementScanInfo, v: uint32) {.inline.} =
  ## Appends a uint32 parameter.
  let val = duckdb_create_uint32(v)
  duckdb_replacement_scan_add_parameter(info.handle, val)
  duckdb_destroy_value(val.addr)

proc addParameter*(info: ReplacementScanInfo, v: uint64) {.inline.} =
  ## Appends a uint64 parameter.
  let val = duckdb_create_uint64(v)
  duckdb_replacement_scan_add_parameter(info.handle, val)
  duckdb_destroy_value(val.addr)

proc addParameter*(info: ReplacementScanInfo, v: float32) {.inline.} =
  ## Appends a float32 parameter.
  let val = duckdb_create_float(v.cfloat)
  duckdb_replacement_scan_add_parameter(info.handle, val)
  duckdb_destroy_value(val.addr)

proc addParameter*(info: ReplacementScanInfo, v: float64) {.inline.} =
  ## Appends a float64 parameter.
  let val = duckdb_create_double(v.cdouble)
  duckdb_replacement_scan_add_parameter(info.handle, val)
  duckdb_destroy_value(val.addr)

proc addParameter*(info: ReplacementScanInfo, v: string) {.inline.} =
  ## Appends a varchar parameter; embedded NULs are preserved.
  let val = duckdb_create_varchar_length(v.cstring, v.len.idx_t)
  duckdb_replacement_scan_add_parameter(info.handle, val)
  duckdb_destroy_value(val.addr)

proc addParameter*(info: ReplacementScanInfo, v: seq[byte]) {.inline.} =
  ## Appends a blob parameter.
  let val = duckdb_create_blob(
    if v.len == 0: nil else: cast[ptr uint8](unsafeAddr v[0]), v.len.idx_t)
  duckdb_replacement_scan_add_parameter(info.handle, val)
  duckdb_destroy_value(val.addr)

proc addParameter*(info: ReplacementScanInfo, nv: NimValue) {.inline.} =
  ## Appends a param derived from a `NimValue` (complex kinds included).
  addParameter(info, nv.toDuckValue)

# ---------------------------------------------------------------------------
# Internal trampoline + ownership
# ---------------------------------------------------------------------------

proc destroyScanContext(p: pointer) {.cdecl.} =
  if p != nil:
    GC_unref(cast[ReplacementScan](p))

proc trampoline(info: duckdb_replacement_scan_info;
                tableName: cstring;
                data: pointer) {.cdecl.} =
  if data != nil:
    let rs = cast[ReplacementScan](data)
    if rs[].callback != nil:
      try:
        rs[].callback(
          ReplacementScanInfo(handle: info), $tableName,
          cast[pointer](rs[].extraData))
      except Exception:
        duckdb_replacement_scan_set_error(info, getCurrentExceptionMsg().cstring)

# ---------------------------------------------------------------------------
# Constructor + registration
# ---------------------------------------------------------------------------

proc newReplacementScan*(
    callback: proc(info: ReplacementScanInfo, tableName: string,
                   data: pointer) {.cdecl.} = nil,
    extraData: ref RootObj = nil,
  ): ReplacementScan =
  ## Builds a replacement scan from a `cdecl` callback. Return the object and
  ## register it on the `Database`; see the module docs for a full example.
  result = ReplacementScan(callback: callback, extraData: extraData)

proc register*(db: Database, scan: ReplacementScan) =
  ## Installs `scan` on `db`; from then on every unresolved table name goes
  ## through its callback before the catalog lookup fails. Registration order
  ## decides precedence between multiple scans.
  GC_ref(scan)
  duckdb_add_replacement_scan(
    db.rawHandle, trampoline, cast[pointer](scan), destroyScanContext)

# ---------------------------------------------------------------------------
# Macro: registerReplacementScan
# ---------------------------------------------------------------------------

macro registerReplacementScan*(db: typed, procSym: typed): untyped =
  ## Registers a plain Nim `proc` as a replacement scan. The proc receives the
  ## table name and, via `setFunctionName` / `addParameter`, rewrites the
  ## lookup into a table-function call:
  ##
  ## .. code-block:: nim
  ##
  ##    proc scan(info: ReplacementScanInfo, tableName: string) =
  ##      if tableName[0] in {'0'..'9'}:
  ##        info.setFunctionName("range")
  ##        info.addParameter(parseInt(tableName))
  ##    registerReplacementScan(db, scan)
  ##
  ## Returning without calling `setFunctionName` lets the next scan (or the
  ## catalog lookup) handle the name. The proc runs on a DuckDB worker thread
  ## and must be thread-safe.
  let procDef = procSym.getImpl
  if procDef.kind != nnkProcDef:
    error("registerReplacementScan expects a proc; got " & $procDef.kind, procSym)
  if procDef[2].kind != nnkEmpty:
    error("registerReplacementScan procs cannot be generic.", procSym)

  let formalParams = procDef[3]
  let nameStr = procSym.strVal

  if formalParams[0].kind != nnkEmpty:
    error(
      "registerReplacementScan proc must return void (no return type).",
      procSym)

  let paramCount = formalParams.len - 1
  if paramCount < 2 or paramCount > 3:
    error(
      "registerReplacementScan proc must have 2 params " &
      "(info: ReplacementScanInfo, tableName: string) " &
      "or 3 params (info, tableName, data: pointer).",
      procSym)

  let p1Type = repr(getTypeInst(formalParams[1][^2]))
  if p1Type != "ReplacementScanInfo":
    error(
      "First param must be ReplacementScanInfo, got: " & p1Type,
      formalParams[1][0])

  let p2Type = repr(getTypeInst(formalParams[2][^2]))
  if p2Type != "string":
    error(
      "Second param must be string, got: " & p2Type,
      formalParams[2][0])

  if paramCount == 3:
    let p3Type = repr(getTypeInst(formalParams[3][^2]))
    if p3Type != "pointer":
      error(
        "Third param must be pointer, got: " & p3Type,
        formalParams[3][0])

  let wrapperSym = genSym(nskProc, "replacementScanWrapper_" & nameStr)
  let infoSym = ident"info"
  let tableNameSym = ident"tableName"
  let dataSym = ident"data"

  var callArgs = @[infoSym, tableNameSym]
  if paramCount == 3:
    callArgs.add(dataSym)

  let wrapperBody = newStmtList()
  let tryBody = newStmtList(newCall(procSym, callArgs))
  let excBody = newStmtList(
    newCall(bindSym"duckdb_replacement_scan_set_error",
      newDotExpr(infoSym, ident"handle"),
      newDotExpr(
        newCall(ident"getCurrentExceptionMsg"), ident"cstring")))
  wrapperBody.add(nnkTryStmt.newTree(
    tryBody, nnkExceptBranch.newTree(excBody)))

  let wrapperProc = newProc(
    name = wrapperSym,
    params = [
      newEmptyNode(),
      newIdentDefs(infoSym, bindSym"ReplacementScanInfo"),
      newIdentDefs(tableNameSym, bindSym"string"),
      newIdentDefs(dataSym, bindSym"pointer"),
    ],
    body = wrapperBody,
    pragmas = nnkPragma.newTree(ident"cdecl"))

  let scanSym = genSym(nskLet, "scan")
  let regBlock = newStmtList()
  regBlock.add(newLetStmt(scanSym,
    newCall(bindSym"newReplacementScan",
      nnkExprEqExpr.newTree(ident"callback", wrapperSym))))
  regBlock.add(newCall(bindSym"register", db, scanSym))

  result = newStmtList(wrapperProc, regBlock)
