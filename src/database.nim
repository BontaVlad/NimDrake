import /[ffi, config, exceptions]

## To use NimDrake, you must first initialize a Database obj using newDatabase.
## newDatabase takes as parameter the database file to read and write from, or it
## can be used to create an in-memory database if no path or `:memory:` is provided.
## Note that for an in-memory database no data is persisted to disk.
## With the Database obj, you can create one or many Connection using db.connect().
## While individual connections are thread-safe, they will be locked during querying.
## It is therefore recommended that each thread uses its own connection to allow
## for the best parallel performance.
##
## For a complete example, see the runnableExamples on `connect` or the top-level
## `nimdrake` module.

type
  DbObj = object
    handle: duckdbDatabase

  Database* = object
    p: ref DbObj

  ConnObj = object
    handle: duckdbConnection
    db: ref DbObj

  Connection* = object
    p: ref ConnObj

  QueryProgress* = object
    p: duckdb_query_progress_type

proc `=destroy`(obj: var DbObj) =
  if obj.handle != nil:
    duckdb_close(obj.handle.addr)

proc `=destroy`(obj: var ConnObj) =
  if obj.handle != nil:
    duckdb_disconnect(obj.handle.addr)

# --- Accessors ----------------------------------------------------------------

proc rawHandle*(db: Database): duckdbDatabase {.inline.} =
  if db.p.isNil: nil else: db.p.handle

proc rawHandle*(con: Connection): duckdbConnection {.inline.} =
  if con.p.isNil: nil else: con.p.handle

# --- QueryProgress accessors --------------------------------------------------

proc percentage*(q: QueryProgress): float {.inline.} =
  q.p.percentage.float

proc rowsProcessed*(q: QueryProgress): uint64 {.inline.} =
  q.p.rows_processed

proc totalRows*(q: QueryProgress): uint64 {.inline.} =
  q.p.total_rows_to_process

# --- Database construction / open-n-create -----------------------------------

proc newDatabase*(path: string = ":memory:", config: Config = Config()): Database =
  ## Create or open a DuckDB database.
  ##
  ## If called with no arguments or with `":memory:"`, an in-memory database is
  ## created (no data persisted to disk). If called with a file path, that
  ## database file is opened (or created if it does not exist). An optional
  ## `Config` can be passed to configure the database engine before startup.
  ##
  ## runnableExamples:
  ##   let db = newDatabase()
  ##   let conn = db.connect()
  ##   assert conn.rawHandle != nil

  var h: duckdbDatabase
  var err: cstring = nil
  let st = duckdbOpenExt(path.cstring, h.addr, config.rawHandle, err.addr)
  if st != enumDuckDbState.Duckdbsuccess:
    let msg = if err.isNil: "Failed to open database" else: $err
    if not err.isNil: duckdbFree(cast[pointer](err))
    raise newException(OperationError, msg)
  result = Database(p: new(ref DbObj))
  result.p.handle = h

proc newDatabase*(config: Config): Database {.inline.} =
  ## Create an in-memory database with the given configuration.
  ##
  ## runnableExamples:
  ##   import std/tables
  ##   let conf = newConfig({"threads": "3"}.toTable)
  ##   let db = newDatabase(conf)
  ##   let conn = db.connect()
  ##   assert conn.rawHandle != nil

  newDatabase(":memory:", config)

# --- Connections --------------------------------------------------------------

proc connect*(db: Database): Connection =
  ## Create one or many Connections from a single Database. While individual
  ## connections are thread-safe, they will be locked during querying.
  ##
  ## runnableExamples:
  ##   let db = newDatabase()
  ##   let conn = db.connect()
  ##   let conn2 = db.connect()
  ##   assert conn.rawHandle != nil
  ##   assert conn2.rawHandle != nil

  result = Connection(p: new(ref ConnObj))
  result.p.db = db.p
  check(
    duckdbConnect(db.p.handle, result.p.handle.addr),
    "Failed to connect to database",
  )

# --- Query progress -----------------------------------------------------------

proc queryProgress*(con: Connection): QueryProgress {.inline.} =
  ## Returns the current progress of the execution engine.
  ## `percentage` is -1.0 when idle, otherwise between 0.0 and 1.0.
  ##
  ## runnableExamples:
  ##   let db = newDatabase()
  ##   let conn = db.connect()
  ##   let progress = conn.queryProgress()
  ##   assert progress.percentage <= 0.0

  QueryProgress(p: duckdbQueryProgress(con.p.handle))

proc interrupt*(con: Connection) {.inline.} =
  ## Interrupt all pending operations on this connection.

  duckdbInterrupt(con.p.handle)
