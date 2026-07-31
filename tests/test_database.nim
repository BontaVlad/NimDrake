import unittest2
import std/[tables, os]
import utils
import ../src/[ffi, types, database, config, query, qresult, exceptions, scalar_functions]

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

  test "Database works after move — query via moved handle":
    var db1 = newDatabase()
    let conn1 = db1.connect()
    var db2 = move(db1)
    let conn2 = db2.connect()
    conn2.execute("CREATE TABLE moved_t (x INTEGER)")
    conn2.executeMaterialized("INSERT INTO moved_t VALUES (?)", (42,))
    let r = conn2.execute("SELECT x FROM moved_t")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Integer)[0] == 42'i32

suite "On-disk persistence":
  test "On-disk DB: create, close, reopen, verify data survives":
    let path = getTempDir() / "nd_test_persist.db"
    withTempDb(path):
      block writePhase:
        let db = newDatabase(path)
        let conn = db.connect()
        conn.execute("CREATE TABLE persisted (i INTEGER)")
        conn.executeMaterialized("INSERT INTO persisted VALUES (?), (?), (?)", (1, 2, 3))
      block readPhase:
        let db = newDatabase(path)
        let conn = db.connect()
        let r = conn.execute("SELECT i FROM persisted ORDER BY i")
        for chunk in r:
          check chunk.bindAs(0, DuckType.Integer).toSeq == @[1'i32, 2, 3]

  test "On-disk DB with access_mode=read_only rejects writes":
    let path = getTempDir() / "nd_test_readonly.db"
    withTempDb(path):
      block setup:
        let db = newDatabase(path)
        let conn = db.connect()
        conn.execute("CREATE TABLE ro_test (x INTEGER)")
        conn.executeMaterialized("INSERT INTO ro_test VALUES (?)", (99,))
      block readOnly:
        let config = newConfig({"access_mode": "read_only"}.toTable)
        let db = newDatabase(path, config)
        let conn = db.connect()
        let r = conn.execute("SELECT x FROM ro_test")
        for chunk in r:
          check chunk.bindAs(0, DuckType.Integer)[0] == 99'i32
        expect(OperationError):
          conn.execute("INSERT INTO ro_test VALUES (1)")

  test "Opening a directory path as a DB raises OperationError":
    let dirPath = getTempDir() / "nd_test_dir_as_db"
    createDir(dirPath)
    defer: removeDir(dirPath)
    expect(OperationError):
      discard newDatabase(dirPath)

  test "Opening a garbage binary file as a DB raises OperationError":
    let path = getTempDir() / "nd_test_garbage.db"
    writeFile(path, "this is definitely not a duckdb database file")
    defer: removeFile(path)
    expect(OperationError):
      discard newDatabase(path)

suite "Concurrent SharedPtr":
  test "16 threads share Database, each does 1000 SELECT 1":
    # Leak detection is delegated to the sanitizer: CI runs with
    # ASAN_OPTIONS=detect_leaks=1 + LSAN_OPTIONS=suppressions=lsan.supp, so a
    # SharedPtr refcount/teardown leak in Database/Connection fails the run.
    let db = newDatabase()
    proc worker(args: tuple[db: Database]) {.thread.} =
      let conn = args.db.connect()
      for _ in 0 ..< 1000:
        discard conn.execute("SELECT 1")
    let nthreads = 16
    var threads = newSeq[Thread[tuple[db: Database]]](nthreads)
    for i in 0 ..< nthreads:
      createThread(threads[i], worker, (db,))
    joinThreads(threads)
    check db.rawHandle != nil

  test "Concurrent prepared statement inserts on same Database":
    let db = newDatabase()
    let conn = db.connect()
    conn.execute("CREATE TABLE concurrent_t (id INTEGER, val VARCHAR)")
    var prep = conn.newStatement("INSERT INTO concurrent_t VALUES (?, ?)")
    proc worker(args: tuple[db: Database, prepIdx: int]) {.thread.} =
      let c = args.db.connect()
      let s = c.newStatement("INSERT INTO concurrent_t VALUES (?, ?)")
      c.executeMaterialized(s, (args.prepIdx, "thread_" & $args.prepIdx))
    let n = 8
    var threads = newSeq[Thread[tuple[db: Database, prepIdx: int]]](n)
    for i in 0 ..< n:
      createThread(threads[i], worker, (db, i))
    joinThreads(threads)
    let r = conn.execute("SELECT count(*)::BIGINT FROM concurrent_t")
    for chunk in r:
      check chunk.bindAs(0, DuckType.BigInt)[0] == n

  test "Concurrent scalar UDF on same Database":
    proc doubler(x: int64): int64 = x * 2
    let db = newDatabase()
    let conn = db.connect()
    conn.registerScalar(doubler)
    for chunk in conn.execute("SELECT doubler(5::BIGINT)"):
      check chunk.bindAs(0, DuckType.BigInt)[0] == 10'i64
    proc worker(args: tuple[db: Database]) {.thread.} =
      let c = args.db.connect()
      for _ in 0 ..< 10:
        discard c.execute("SELECT doubler(3::BIGINT)")
    let n = 4
    var threads = newSeq[Thread[tuple[db: Database]]](n)
    for i in 0 ..< n:
      createThread(threads[i], worker, (db,))
    joinThreads(threads)



suite "Memory ownership — Database/Connection":
  test "Moving a Database preserves its handle, source is nil":
    var db1 = newDatabase()
    let handle1 = db1.rawHandle
    var db2 = move(db1)
    check db1.rawHandle.isNil
    check db2.rawHandle == handle1

  test "Connection outlives Database object via SharedPtr":
    var db = newDatabase()
    let conn = db.connect()
    conn.execute("CREATE TABLE live_test (x INTEGER)")
    conn.execute("INSERT INTO live_test VALUES (42)")
    # Drop the database reference
    db = move(db)
    # Connection should still work because SharedPtr keeps DbObj alive
    let r = conn.execute("SELECT x FROM live_test")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Integer)[0] == 42'i32

  test "Database move and reuse pattern is safe":
    var db1 = newDatabase()
    var db2 = newDatabase()
    let conn1 = db1.connect()
    discard conn1.execute("SELECT 1")
    # Move db1 to db2 and verify db2 works
    db2 = move(db1)
    check db1.rawHandle.isNil
    check db2.rawHandle != nil
    let conn2 = db2.connect()
    let r = conn2.execute("SELECT 42 AS answer")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Integer)[0] == 42'i32
