import unittest2
import std/[tables]
import utils
import ../src/[ffi, database, config, query, query_result, exceptions]

suite "Database settings":

  test "Settings before database init with setConfig":
    let config = newConfig()
    config.setConfig("threads", "8")

    let con = newDatabase(config).connect()
    let outcome =
      con.execute("SELECT current_setting('threads') AS threads;").fetchall()
    assert outcome[0].valueBigint == @[8'i64]

    config.setConfig("threads", "2")

    let con2 = newDatabase(config).connect()
    let outcome2 =
      con2.execute("SELECT current_setting('threads') AS threads;").fetchall()
    assert outcome2[0].valueBigint == @[2'i64]

  test "Settings before database init directly from initialization":
    let config = newConfig({"threads": "3"}.toTable)

    let con = newDatabase(config).connect()
    let outcome =
      con.execute("SELECT current_setting('threads') AS threads;").fetchall()
    assert outcome[0].valueBigint ==
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

      conn.execute(
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

    let results = mainConn.execute("SELECT calculation_result, value_a, value_b, thread_id FROM results ORDER BY thread_id").fetchAll()
    # results is column-major: results[0]=calculation_result, results[1]=value_a,
    # results[2]=value_b, results[3]=thread_id
    # Thread 0: a=0, b=0, res=0; Thread 1: a=10, b=20, res=30; Thread 2: a=20, b=40, res=60
    check results[0].valueInteger[0] == 0'i64  # calculation_result for thread 0
    check results[0].valueInteger[1] == 30'i64 # calculation_result for thread 1
    check results[0].valueInteger[2] == 60'i64 # calculation_result for thread 2

    check results[3].valueInteger[0] == 0'i64  # thread_id for thread 0
    check results[3].valueInteger[1] == 1'i64  # thread_id for thread 1
    check results[3].valueInteger[2] == 2'i64  # thread_id for thread 2

    # Verify all 5 threads produced correct results
    check results[0].valueInteger.len == 5
    check results[1].valueInteger == @[0'i32, 10, 20, 30, 40]  # value_a
    check results[2].valueInteger == @[0'i32, 20, 40, 60, 80]  # value_b

  test "Multiple In-Memory DB Start Up and Shutdown":
    var
      databases: array[10, Database]
      connections: array[100, Connection]

    for i in 0..<10:
      databases[i] = newDatabase()
      check databases[i].handle != nil
      for j in 0..<10:
        connections[i * 10 + j] = databases[i].connect()
        check connections[i * 10 + j].handle != nil

    # Verify each connection can execute a query
    for i in 0..<100:
      let outcome = connections[i].execute("SELECT 1").fetchAll()
      check outcome.len == 1
      check outcome[0].valueInteger == @[1'i32]
