import unittest2
import std/[tables]
import utils
import ../src/[ffi, types, database, config, query, qresult, exceptions]

suite "Database settings":

  test "Settings before database init with setConfig":
    let config = newConfig()
    config.setConfig("threads", "8")

    let con = newDatabase(config).connect()
    let outcome =
      con.execute("SELECT current_setting('threads') AS threads;")
    for chunk in outcome:
      assert chunk.bindAs(0, DuckType.BigInt).toSeq == @[8'i64]

    config.setConfig("threads", "2")

    let con2 = newDatabase(config).connect()
    let outcome2 =
      con2.execute("SELECT current_setting('threads') AS threads;")
    for chunk in outcome2:
      assert chunk.bindAs(0, DuckType.BigInt).toSeq == @[2'i64]

  test "Settings before database init directly from initialization":
    let config = newConfig({"threads": "3"}.toTable)

    let con = newDatabase(config).connect()
    let outcome =
      con.execute("SELECT current_setting('threads') AS threads;")
    for chunk in outcome:
      assert chunk.bindAs(0, DuckType.BigInt).toSeq ==
        @[3'i64]

  #   # triggers the memory sanitizer
  test "Incorrect setting key should throw an error":
    ignoreLeak:
      doAssertRaises(OperationError):
        let
          config = newConfig({"invalid": "3"}.toTable)
          con = newDatabase(config).connect()

  test "Incorrect setting value should throw an error":
    ignoreLeak:
      doAssertRaises(OperationError):
        discard newConfig({"threads": "invalid"}.toTable)

suite "Connections":
  test "Thread-safe connection":
    let
      db = newDatabase()
      mainConn = db.connect()

    mainConn.execute("""
         CREATE TABLE IF NOT EXISTS results (
            thread_id INTEGER,
            value_a INTEGER,
            value_b INTEGER,
            calculation_result INTEGER
         )""")

    proc worker(args: tuple[db: Database, id: int]) {.thread.} =
      let conn = args.db.connect()

      let
        a = args.id * 10
        b = args.id * 20
        res = a + b

      conn.executeMaterialized(
         "INSERT INTO results VALUES (?, ?, ?, ?)",
         (args.id, a, b, res)
      )

    let nthreads = 5

    var threads = newSeq[Thread[tuple[db: Database, id: int]]](nthreads)
    for i in 0..<nthreads:
      createThread(threads[i], worker, (db, i))

    joinThreads(threads)

    let results = mainConn.execute(
      "SELECT calculation_result, value_a, value_b, thread_id FROM results ORDER BY thread_id")
    for chunk in results:
      let calcResult = chunk.bindAs(0, DuckType.Integer).toSeq
      let valueA = chunk.bindAs(1, DuckType.Integer).toSeq
      let valueB = chunk.bindAs(2, DuckType.Integer).toSeq
      let threadId = chunk.bindAs(3, DuckType.Integer).toSeq

      check calcResult.len == 5
      check threadId.len == 5

      check calcResult == @[0'i32, 30, 60, 90, 120]
      check valueA == @[0'i32, 10, 20, 30, 40]
      check valueB == @[0'i32, 20, 40, 60, 80]
      check threadId == @[0'i32, 1, 2, 3, 4]

  test "Multiple In-Memory DB Start Up and Shutdown":
    var
      databases: array[10, Database]
      connections: array[100, Connection]

    for i in 0..<10:
      databases[i] = newDatabase()
      check databases[i].rawHandle != nil
      for j in 0..<10:
        connections[i * 10 + j] = databases[i].connect()
        check connections[i * 10 + j].rawHandle != nil

    for i in 0..<100:
      for chunk in connections[i].execute("SELECT 1"):
        check chunk.vector(0).kind == DuckType.Integer
        check chunk.bindAs(0, DuckType.Integer).toSeq == @[1'i32]

  test "Database outlives main Database object via connections":
    var db = newDatabase()
    let mainConn = db.connect()
    mainConn.execute("CREATE TABLE IF NOT EXISTS t(x INTEGER)")

    proc worker(args: tuple[db: Database]) {.thread.} =
      let conn = args.db.connect()
      conn.executeMaterialized("INSERT INTO t VALUES (?)", (1,))

    let nthreads = 3
    var threads = newSeq[Thread[tuple[db: Database]]](nthreads)
    for i in 0..<nthreads:
      createThread(threads[i], worker, (db,))
    joinThreads(threads)

    db = default(Database)

    let outcome = mainConn.execute("SELECT COUNT(*) AS cnt FROM t")
    for chunk in outcome:
      check chunk.bindAs(0, DuckType.BigInt).toSeq == @[3'i64]

  test "Move Database preserves handle, nils source, no double-close":
    var db1 = newDatabase()
    let h = db1.rawHandle
    check h != nil

    var db2 = move(db1)
    check db1.rawHandle == nil
    check db2.rawHandle != nil
    check db2.rawHandle == h
