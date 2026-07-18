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

  ScanRegistry = ref object
    ## One per database (keyed by `rawDbHandle` in `extraDataRegistry`).
    ## Carries the registered name -> entry table shared by every connection
    ## on that database.
    data: Table[string, RegistryEntry]

  InitData = ref object
    ## The per-scan fill closure, boxed so it can live in DuckDB's init-data
    ## slot.  `FillFn` is a closure value, not a ref, so it must be heap-boxed.
    fill: FillFn

# ---------------------------------------------------------------------------
# TableSource concept — structural type for register()-able sources.
#
# A conforming type must provide these three free procs:
#   columns(s): seq[Column]
#   cardinality(s): Cardinality
#   newFiller(s): FillFn
#
# Two things were required to make this concept work in Nim 2.2:
#
# 1. `mixin columns, cardinality, newFiller` inside the concept body.
#    Without it, Nim resolves these free-proc calls at the concept's
#    definition scope (this module), so overloads a user defines in another
#    module are invisible and the concept silently fails to match.
#
# 2. The `columns` iterator that previously shared the name `columns` with
#    the `proc columns*(q: QResult): seq[Column]` was renamed to
#    `columnItems`.  Nim's concept matcher cannot disambiguate a proc/iterator
#    name clash — it picks the iterator, sees yield type `Column` (not
#    `seq[Column]`), and rejects the match even for `QResult` itself.
# ---------------------------------------------------------------------------

type
  TableSource* = concept s
    mixin columns, cardinality, newFiller
    columns(s) is seq[Column]
    cardinality(s) is Cardinality
    newFiller(s) is FillFn

var
  extraDataRegistry: Table[pointer, ScanRegistry]
  scanLock: Lock

scanLock.initLock()

# ---------------------------------------------------------------------------
# =destroy hooks for DuckDB-owned bind/init data (GC_ref/unref dance)
# ---------------------------------------------------------------------------

proc destroyEntry(p: pointer) {.cdecl.} =
  ## Releases the `RegistryEntry` ref that was GC_ref'd in scanBind.  The entry
  ## is also held by `ScanRegistry.data`, so the registry keeps it alive until
  ## the database is closed; this only balances the bind-time ref.
  GC_unref(cast[RegistryEntry](p))

proc destroyInitData(p: pointer) {.cdecl.} =
  `=destroy`(cast[InitData](p))

# ---------------------------------------------------------------------------
# Table function callbacks
# ---------------------------------------------------------------------------

proc scanBind(info: BindInfo) {.cdecl.} =
  let tf = cast[ptr TableFunctionBase](duckdb_bind_get_extra_info(info.handle))
  let registry = cast[ScanRegistry](cast[pointer](tf.extraData))

  let val = info.getParameter(0)
  let cs = duckdb_get_varchar(val)
  let name = $cs
  duckdb_free(cast[pointer](cs))
  duckdb_destroy_value(val.addr)

  scanLock.acquire()
  let entry = registry.data.getOrDefault(name)
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

  GC_ref(entry)
  info.setBindData(cast[pointer](entry), destroyEntry)

proc scanInit(info: InitInfo) {.cdecl.} =
  let entry = cast[RegistryEntry](info.getBindData())
  var id = InitData(fill: entry.makeFiller())
  GC_ref(id)
  info.setInitData(cast[pointer](id), destroyInitData)

proc scanMain(info: FunctionInfo, rawChunk: duckdb_data_chunk) {.cdecl.} =
  let initData = cast[InitData](info.getInitData())
  let n = initData.fill(rawChunk)
  duckdb_data_chunk_set_size(rawChunk, n.idx_t)

# ---------------------------------------------------------------------------
# Per-DB registration — shared ScanRegistry per database, function per connection
# ---------------------------------------------------------------------------

proc ensureRegistered(con: Connection): ScanRegistry =
  let dbKey = cast[pointer](con.rawDbHandle)
  scanLock.acquire()
  if dbKey in extraDataRegistry:
    result = extraDataRegistry[dbKey]
    scanLock.release()
  else:
    result = ScanRegistry(data: initTable[string, RegistryEntry]())
    extraDataRegistry[dbKey] = result
    scanLock.release()

  if not con.p.scanFnRegistered:
    let tf = newTableFunction(
      name = "nim_tbl_scan",
      parameters = @[newLogicalType(DuckType.Varchar)],
      bindProc = scanBind,
      initProc = scanInit,
      mainProc = scanMain,
      extraData = cast[ref RootObj](cast[pointer](result)),
    )
    con.register(tf)
    con.p.scanFnRegistered = true

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
  # Single-allocation SQL composition for the view. The identifier and the
  # literal string are the same `name` (already validated by the lookup above),
  # so both quote passes share one escaped form.
  var sql = newStringOfCap(64 + 4 * name.len)
  sql.add "CREATE OR REPLACE VIEW \""
  for c in name:
    if c == '"': sql.add "\"\""
    else: sql.add c
  sql.add "\" AS SELECT * FROM nim_tbl_scan('"
  for c in name:
    if c == '\'': sql.add "''"
    else: sql.add c
  sql.add "')"
  con.execute(sql)

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
