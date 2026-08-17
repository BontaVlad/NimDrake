## Database and connection lifecycle.
##
## To use NimDrake, first create a `Database` with `newDatabase`. Pass a file
## path to open (or create) a file-backed database; pass nothing or
## `":memory:"` for an in-memory database (no data is persisted to disk).
## Optional `Config` options apply at creation time, before the first
## connection.
##
## From a `Database` you may `connect` one or more `Connection`s. Connections
## are thread-safe but serialize while a query runs, so for parallel workloads
## open one connection per thread. Optional `Config` options apply at creation
## time, before the first connection.
##
## For a complete example, see the `nimdrake` module docs.
import /[ffi, config, exceptions]
import threading/smartptrs

type
  DbObj = object
    handle: duckdbDatabase

  Database* = object ## Owns a DuckDB database handle via a shared pointer.
    p: SharedPtr[DbObj]

  ConnObj* = object ## Connection internals; kept exported for FFI accessors.
    handle: duckdbConnection
    db: SharedPtr[DbObj]      # keeps the database alive as long as this connection does

  Connection* = object ## A live connection into a `Database`. Thread-safe but
                       ## serialized while a query runs; prefer one per thread.
    p*: ref ConnObj            # never shared across threads -> stays a plain (fast) ref

  QueryProgress* = object ## Execution progress snapshot from `queryProgress`.
    p: duckdb_query_progress_type

proc rawDbHandle*(con: Connection): duckdb_database {.inline.} =
  ## Underlying database handle of a connection; FFI forwarding.
  con.p.db[].handle

## Hook invoked with the raw database handle just before it is closed; lets
## companion modules (e.g. `table_scan`) clean their registries. Must not raise.
var dbCloseHook*: proc(dbHandle: pointer) {.raises: [].} = nil

proc `=destroy`(obj: var DbObj) =
  if obj.handle != nil:
    if dbCloseHook != nil:
      dbCloseHook(cast[pointer](obj.handle))
    duckdb_close(obj.handle.addr)

proc `=destroy`(obj: var ConnObj) =
  if obj.handle != nil:
    duckdb_disconnect(obj.handle.addr)
  reset(obj.db)

# --- Accessors ----------------------------------------------------------------

proc rawHandle*(db: Database): duckdbDatabase {.inline.} =
  ## Underlying DuckDB handle; `nil` for a moved-from database.
  if db.p.isNil: nil else: db.p[].handle

proc rawHandle*(con: Connection): duckdbConnection {.inline.} =
  ## Underlying DuckDB handle; `nil` for a moved-from connection.
  if con.p.isNil: nil else: con.p.handle

# --- QueryProgress accessors --------------------------------------------------

proc percentage*(q: QueryProgress): float {.inline.} =
  ## Fraction of work done: -1.0 when idle, otherwise 0.0..1.0.
  q.p.percentage.float

proc rowsProcessed*(q: QueryProgress): uint64 {.inline.} =
  ## Rows processed so far by the running query.
  q.p.rows_processed

proc totalRows*(q: QueryProgress): uint64 {.inline.} =
  ## Rows the running query will process in total.
  q.p.total_rows_to_process

# --- Database construction / open-n-create -----------------------------------

proc newDatabase*(path: string = ":memory:", config: Config = Config()): Database =
  ## Create or open a DuckDB database.
  ##
  ## If called with no arguments or with `":memory:"`, an in-memory database is
  ## created (no data persisted to disk). If called with a file path, that
  ## database file is opened (or created if it does not exist). An optional
  ## `Config` can be passed to configure the database engine before startup.
  runnableExamples:
    let db = newDatabase()
    let conn = db.connect()
    assert conn.rawHandle != nil

  var h: duckdbDatabase
  var err: cstring = nil
  let st = duckdbOpenExt(path.cstring, h.addr, config.rawHandle, err.addr)
  if st != enumDuckDbState.Duckdbsuccess:
    let msg = if err.isNil: "Failed to open database" else: $err
    if not err.isNil: duckdbFree(cast[pointer](err))
    raise newException(OperationError, msg)
  result = Database(p: newSharedPtr(DbObj(handle: h)))

proc newDatabase*(config: Config): Database {.inline.} =
  ## Create an in-memory database with the given configuration.
  runnableExamples:
    import std/tables
    let conf = newConfig({"threads": "3"}.toTable)
    let db = newDatabase(conf)
    let conn = db.connect()
    assert conn.rawHandle != nil

  newDatabase(":memory:", config)

# --- Connections --------------------------------------------------------------

proc connect*(db: Database): Connection =
  ## Create one or many Connections from a single Database. While individual
  ## connections are thread-safe, they will be locked during querying.
  runnableExamples:
    let db = newDatabase()
    let conn = db.connect()
    let conn2 = db.connect()
    assert conn.rawHandle != nil
    assert conn2.rawHandle != nil

  result = Connection(p: new(ref ConnObj))
  result.p.db = db.p              # atomic-refcounted copy: safe from any thread
  check(
    duckdbConnect(db.p[].handle, result.p.handle.addr),
    "Failed to connect to database",
  )

# --- Query progress -----------------------------------------------------------

proc queryProgress*(con: Connection): QueryProgress {.inline.} =
  ## Returns the current progress of the execution engine.
  ## `percentage` is -1.0 when idle, otherwise between 0.0 and 1.0.
  runnableExamples:
    let db = newDatabase()
    let conn = db.connect()
    let progress = conn.queryProgress()
    assert progress.percentage <= 0.0

  QueryProgress(p: duckdbQueryProgress(con.p.handle))

proc interrupt*(con: Connection) {.inline.} =
  ## Interrupt all pending operations on this connection.

  duckdbInterrupt(con.p.handle)
