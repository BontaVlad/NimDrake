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
      con.executeMaterialized("SELECT current_setting('threads') AS threads;")
    for chunk in outcome:
      assert chunk.bindAs(0, DuckType.BigInt).toSeq == @[8'i64]

    config.setConfig("threads", "2")

    let con2 = newDatabase(config).connect()
    let outcome2 =
      con2.executeMaterialized("SELECT current_setting('threads') AS threads;")
    for chunk in outcome2:
      assert chunk.bindAs(0, DuckType.BigInt).toSeq == @[2'i64]

  test "Settings before database init directly from initialization":
    let config = newConfig({"threads": "3"}.toTable)

    let con = newDatabase(config).connect()
    let outcome =
      con.executeMaterialized("SELECT current_setting('threads') AS threads;")
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
        let config = newConfig({"threads": "invalid"}.toTable)

suite "Connections":
  test "Thread-safe connection":
    var
      db = newDatabase()
      mainConn = db.connect()

    mainConn.execute("""
         CREATE TABLE IF NOT EXISTS results (
            thread_id INTEGER,
            value_a INTEGER,
            value_b INTEGER,
            calculation_result INTEGER
         )""")

    type
      ThreadData = object
        id: int
        db: ptr Database

    proc workerThread(data: ThreadData) {.thread.} =
      let conn = data.db[].connect()

      let
        a = data.id * 10
        b = data.id * 20
        res = a + b

      conn.executeMaterialized(
         "INSERT INTO results VALUES (?, ?, ?, ?)",
         (data.id, a, b, res)
      )

    let nthreads = 5

    var threads = newSeq[Thread[ThreadData]](nthreads)
    var threadData = newSeq[ThreadData](nthreads)

    for i in 0..<nthreads:
      threadData[i] = ThreadData(id: i, db: db.addr)
      createThread(threads[i], workerThread, threadData[i])

    joinThreads(threads)

    let results = mainConn.executeMaterialized("SELECT calculation_result, value_a, value_b, thread_id FROM results ORDER BY thread_id")
    for chunk in results:
      let calcResult = chunk.bindAs(0, DuckType.Integer).toSeq
      let valueA = chunk.bindAs(1, DuckType.Integer).toSeq
      let valueB = chunk.bindAs(2, DuckType.Integer).toSeq
      let threadId = chunk.bindAs(3, DuckType.Integer).toSeq

      check calcResult[0] == 0'i64
      check calcResult[1] == 30'i64
      check calcResult[2] == 60'i64

      check threadId[0] == 0'i64
      check threadId[1] == 1'i64
      check threadId[2] == 2'i64

      check calcResult.len == 5
      check valueA == @[0'i32, 10, 20, 30, 40]
      check valueB == @[0'i32, 20, 40, 60, 80]

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
      for chunk in connections[i].executeMaterialized("SELECT 1"):
        check chunk.vector(0).kind == DuckType.Integer
        check chunk.bindAs(0, DuckType.Integer).toSeq == @[1'i32]
