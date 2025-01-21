import unittest2
# import std/[threadpool, tables]
import std/[cpuinfo, tables]
import taskpools
import ../src/[api, database, config, query, query_result, exceptions]


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
  # test "Incorrect setting key should throw an error":
  #   doAssertRaises(OperationError):
  #     let
  #      config = newConfig({"invalid": "3"}.toTable)
  #      con = newDatabase(config).connect()

  # test "Incorrect setting value should throw an error":
  #   doAssertRaises(OperationError):
  #     let config = newConfig({"threads": "invalid"}.toTable)

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

    proc workerThread(data: ThreadData) {.gcsafe.} =
      let conn = data.db[].connect()

      let
        a = data.id * 10
        b = data.id * 20
        res = a + b

      conn.execute(
         "INSERT INTO results VALUES (?, ?, ?, ?)",
         (data.id, a, b, res)
      )

    let n = 5
    let nthreads = countProcessors()

    var tp = Taskpool.new(num_threads = nthreads)

    for i in 0..<n:
      let data = ThreadData(id: i, db: db.addr)  # Pass address of db
      tp.spawn workerThread(data)

    tp.syncAll()
    tp.shutdown()

    let results = mainConn.execute("SELECT calculation_result, value_a, value_b, thread_id FROM results ORDER BY thread_id").fetchAll()
    check results[0].valueInteger[0] == 0'i64
    check results[0].valueInteger[1] == 30'i64
    check results[0].valueInteger[2] == 60'i64

    check results[3].valueInteger[0] == 0'i64
    check results[3].valueInteger[1] == 1'i64
    check results[3].valueInteger[2] == 2'i64
