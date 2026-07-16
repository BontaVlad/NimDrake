import std/[tables, strformat, strutils, locks, macros]
import /[ffi, database, types, qresult, table_functions, query]

# ---------------------------------------------------------------------------
# Kinds supported at bind time.
# ---------------------------------------------------------------------------

const TableScanSupportedKinds* = {
  DuckType.Boolean,
  DuckType.TinyInt, DuckType.SmallInt, DuckType.Integer, DuckType.BigInt,
  DuckType.UTinyInt, DuckType.USmallInt, DuckType.UInteger, DuckType.UBigInt,
  DuckType.Float, DuckType.Double,
  DuckType.Timestamp, DuckType.Date, DuckType.Time, DuckType.Interval,
  DuckType.HugeInt, DuckType.Varchar, DuckType.Blob, DuckType.Decimal,
  DuckType.TimestampS, DuckType.TimestampMs, DuckType.TimestampNs,
  DuckType.Enum, DuckType.UUID, DuckType.Bit, DuckType.TimeTz,
  DuckType.TimestampTz, DuckType.UHugeInt,
}

# ---------------------------------------------------------------------------
# Registry types
# ---------------------------------------------------------------------------

type
  FillerFactory = proc(): FillFn {.closure, gcsafe.}

  RegistryEntry = ref object
    columns: seq[Column]
    cardinality: Cardinality
    makeFiller: FillerFactory

  ExtraData = ref object of RootObj
    data: Table[string, RegistryEntry]

  BindData = ref object
    entry: RegistryEntry

  InitData = ref object
    fill: FillFn

var
  extraDataRegistry: Table[pointer, ExtraData]
  scanLock: Lock

scanLock.initLock()

# ---------------------------------------------------------------------------
# =destroy hooks for DuckDB-owned bind/init data (GC_ref/unref dance)
# ---------------------------------------------------------------------------

proc destroyBindData(p: pointer) {.cdecl.} =
  `=destroy`(cast[BindData](p))

proc destroyInitData(p: pointer) {.cdecl.} =
  `=destroy`(cast[InitData](p))

# ---------------------------------------------------------------------------
# Table function callbacks
# ---------------------------------------------------------------------------

proc scanBind(info: BindInfo) {.cdecl.} =
  let tf = cast[ptr TableFunctionBase](duckdb_bind_get_extra_info(info.handle))
  let extra = cast[ExtraData](tf.extraData)

  let val = info.getParameter(0)
  let cs = duckdb_get_varchar(val)
  let name = $cs
  duckdb_free(cast[pointer](cs))
  duckdb_destroy_value(val.addr)

  scanLock.acquire()
  let entry = extra.data.getOrDefault(name)
  scanLock.release()
  if entry.isNil:
    info.setError(fmt"nim_tbl_scan: table '{name}' not found")
    return

  for col in entry.columns:
    if col.kind notin TableScanSupportedKinds:
      info.setError(
        fmt"nim_tbl_scan: column '{col.name}' has unsupported type {col.kind}")
      return
    info.addResultColumn(col.name, col.ltype)

  case entry.cardinality.kind
  of ckKnown:
    info.setCardinality(entry.cardinality.count, entry.cardinality.isExact)
  of ckUnknown:
    ## -1 is DuckDB's convention for "unknown cardinality".
    info.setCardinality(-1, false)

  var bd = BindData(entry: entry)
  GC_ref(bd)
  info.setBindData(cast[pointer](bd), destroyBindData)

proc scanInit(info: InitInfo) {.cdecl.} =
  let bindData = cast[BindData](info.getBindData())
  var id = InitData(fill: bindData.entry.makeFiller())
  GC_ref(id)
  info.setInitData(cast[pointer](id), destroyInitData)

proc scanMain(info: FunctionInfo, rawChunk: duckdb_data_chunk) {.cdecl.} =
  let initData = cast[InitData](info.getInitData())
  let n = initData.fill(rawChunk)
  duckdb_data_chunk_set_size(rawChunk, n.idx_t)

# ---------------------------------------------------------------------------
# Per-DB registration — shared ExtraData per database, function per connection
# ---------------------------------------------------------------------------

proc ensureRegistered(con: Connection): ExtraData =
  let dbKey = cast[pointer](con.rawDbHandle)
  scanLock.acquire()
  if dbKey in extraDataRegistry:
    result = extraDataRegistry[dbKey]
    scanLock.release()
  else:
    result = ExtraData(data: initTable[string, RegistryEntry]())
    extraDataRegistry[dbKey] = result
    scanLock.release()

  if not con.p.scanFnRegistered:
    let tf = newTableFunction(
      name = "nim_tbl_scan",
      parameters = @[newLogicalType(DuckType.Varchar)],
      bindProc = scanBind,
      initProc = scanInit,
      mainProc = scanMain,
      extraData = result,
    )
    con.register(tf)
    con.p.scanFnRegistered = true

  con.p.scanData = cast[ref RootObj](result)

# ---------------------------------------------------------------------------
# Database close hook — clean up the registry entry when a DB is destroyed
# ---------------------------------------------------------------------------

database.dbCloseHook = proc(dbKey: pointer) {.raises: [].} =
  scanLock.acquire()
  extraDataRegistry.del(dbKey)
  scanLock.release()

# ---------------------------------------------------------------------------
# SQL helpers — quoting identifiers and literals
# ---------------------------------------------------------------------------

proc quoteIdentifier(s: string): string {.inline.} =
  "\"" & s.replace("\"", "\"\"") & "\""

proc quoteLiteral(s: string): string {.inline.} =
  "'" & s.replace("'", "''") & "'"

# ---------------------------------------------------------------------------
# registerEntry — internal: low-level snapshot of a source
# ---------------------------------------------------------------------------

proc registerEntry(
    con: Connection, name: string,
    columns: seq[Column], card: Cardinality,
    makeFiller: FillerFactory
) =
  let extra = ensureRegistered(con)
  let entry = RegistryEntry(
    columns: columns, cardinality: card, makeFiller: makeFiller)
  scanLock.acquire()
  try:
    extra.data[name] = entry
  finally:
    scanLock.release()
  con.execute(
    "CREATE OR REPLACE VIEW " & quoteIdentifier(name) &
      " AS SELECT * FROM nim_tbl_scan(" & quoteLiteral(name) & ")"
  )

# ---------------------------------------------------------------------------
# registerImpl — generic (any TableSource) + specific QResult[Streaming]
# ---------------------------------------------------------------------------

proc registerImpl*[S: TableSource](
    con: Connection, name: string, source: sink S
) =
  ## Register any source that satisfies the `TableSource` concept.
  ## The concept (defined in qresult.nim) requires:
  ##   columns(s): seq[Column],  cardinality(s): Cardinality,  newFiller(s): FillFn
  mixin columns, cardinality, newFiller
  registerEntry(con, name, source.columns, source.cardinality,
    proc(): FillFn {.closure, gcsafe.} = source.newFiller)

proc registerImpl*(con: Connection, name: string, source: sink QResult[Streaming]) =
  ## Register a streaming result by eagerly materializing it first.
  ## After this call `source` is consumed; the registered view is
  ## fully re-scannable and thread-safe.
  let mat = materialize(source)
  registerImpl(con, name, mat)

# ---------------------------------------------------------------------------
# register macro — deduce name from variable, overridable via `name=`
# ---------------------------------------------------------------------------

macro register*(con: Connection, source: typed, name: static string = ""): untyped =
  ## Register a `TableSource` as a DuckDB view.
  ##
  ## The view name is deduced from the `source` variable name, or
  ## overridden via `name = "..."`. Non-identifier expressions
  ## (e.g., `conn.execute(...)`) require an explicit `name` parameter.
  ##
  ## .. code-block:: nim
  ##   conn.register(myTable)               # → name = "myTable"
  ##   conn.register(q, name = "t")          # → name = "t"
  ##   conn.register(conn.execute("..."), name = "src")  # explicit
  let nm = if name.len > 0:
      name
    elif source.kind == nnkIdent:
      $source
    else:
      error("register: cannot deduce a name from this expression; pass name= explicitly", source)
  result = newCall(bindSym"registerImpl", con, newLit(nm), source)
