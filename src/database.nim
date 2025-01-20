import /[api, config, exceptions]

## To use NimDrake, you must first initialize a Database obj using newDatabase.
## newDatabase takes as parameter the database file to read and write from, or it can be used to create an in-memory database if no parameters is provided.
## Note that for an in-memory database no data is persisted to disk (i.e., all data is lost when you exit the process).
## With the Database obj, you can create one or many Connection using db.connect(). While individual connections are thread-safe, they will be locked during querying. It is therefore recommended that each thread uses its own connection to allow for the best parallel performance.

type
  Database* = object
    handle*: duckdbDatabase

  Connection* = object
    handle*: duckdbConnection

proc `=destroy`(db: Database) =
  if not isNil(db.addr):
    duckdbClose(db.handle.addr)

proc `=destroy`(con: Connection) =
  if not isNil(con.addr):
    duckdbDisconnect(cast[ptr duckdbConnection](con.addr))

proc newDatabase*(path: string, config: Config): Database =
  ## Creates a new preconfigured database or opens an existing database file stored at the given path.

  runnableExamples:
    import std/tables
    import nimdrake

    let
      conf = newConfig({"threads": "3"}.toTable)
      db = newDatabase("duckdb.db", conf)
      conn = db.connect()

    let outcome = conn.execute("SELECT * FROM range(3);").fetchall()

    assert outcome[0].valueBigInt == @[0'i64, 1'i64, 2'i64]

  result = Database(handle: nil)
  var error: cstring = ""
  let state: duckdbState = duckdbOpenExt(path.cstring, result.handle.addr, config, error.addr)
  check(state, $error, `=destroy`(result))

proc newDatabase*(path: string): Database =
  ## Creates a new database or opens an existing database file stored at the given path.

  runnableExamples:
    import nimdrake

    let db = newDatabase("duckdb.db")

  result = Database(handle: nil)
  check(duckdbOpen(path.cstring, result.handle.addr), "Failed to open database")

proc newDatabase*(config: Config): Database =
  ##  Create a new in-memory database preconfigured.

  runnableExamples:
    import std/tables
    import nimdrake

    let conf = newConfig({"threads": "3"}.toTable)
    let db = newDatabase(conf)

  result = newDatabase(":memory:", config)

proc newDatabase*(): Database =
  ##  Create a new in-memory database.

  runnableExamples:
    import nimdrake

    let db = newDatabase()

  result = newDatabase(":memory:")

proc connect*(db: Database): Connection =
  ## Create one or many Connections from a single Database. While individual connections are thread-safe, they will be locked during querying

  runnableExamples:
    import nimdrake

    let db = newDatabase()
    let conn = db.connect()
    let conn2 = db.connect()

    conn.execute("CREATE TABLE combined(i INTEGER, j VARCHAR);")
    conn.execute(
      "INSERT INTO combined VALUES (6, 'foo'), (5, 'bar'), (?, ?);", ("7", "baz")
    )
    let outcome = conn2.execute("SELECT * FROM combined").fetchall()
    assert outcome[0].valueInteger == @[6'i32, 5'i32, 7'i32]

  result = Connection(handle: nil)
  check(duckdbConnect(db.handle, result.handle.addr), "Failed to connect to database")
