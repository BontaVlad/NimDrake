import unittest2
import std/[cpuinfo, tables]
import taskpools
import utils
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
# import std/[os, locks]

# var
#   db = newDatabase()
#   mainConn = db.connect()

# mainConn.execute("""
#      CREATE TABLE IF NOT EXISTS results (
#         thread_id INTEGER,
#         value_a INTEGER,
#         value_b INTEGER,
#         calculation_result INTEGER
#      )""")

# type
#   ThreadData = object
#     id: int
#     db: ptr Database

# # Mark the worker function with {.thread.} pragma as recommended
# proc workerThread(data: ThreadData) {.thread.} =
#   let conn = data.db[].connect()

#   let
#     a = data.id * 10
#     b = data.id * 20
#     res = a + b

#   conn.execute(
#      "INSERT INTO results VALUES (?, ?, ?, ?)",
#      (data.id, a, b, res)
#   )

# let n = 5
# let nthreads = min(n, countProcessors())  # Don't create more threads than tasks

# # Create an array to hold thread objects
# var threads: seq[Thread[ThreadData]]
# threads.setLen(nthreads)

# # Create thread data objects
# var threadDataArray: seq[ThreadData]
# threadDataArray.setLen(n)

# # Initialize thread data
# for i in 0..<n:
#   threadDataArray[i] = ThreadData(id: i, db: db.addr)

# # Create and start threads
# var taskIndex = 0
# for i in 0..<nthreads:
#   if taskIndex < n:
#     createThread(threads[i], workerThread, threadDataArray[taskIndex])
#     inc taskIndex

# # Wait for initial batch of threads to complete and start remaining tasks
# var completedThreads = 0
# while completedThreads < n:
#   for i in 0..<nthreads:
#     if threads[i].running == false:
#       joinThread(threads[i])
#       inc completedThreads

#       # Start next task if available
#       if taskIndex < n:
#         createThread(threads[i], workerThread, threadDataArray[taskIndex])
#         inc taskIndex

#       break

#   # Small delay to prevent busy waiting
#   sleep(1)

# # Join any remaining threads
# for i in 0..<nthreads:
#   if threads[i].running:
#     joinThread(threads[i])

# let results = mainConn.execute("SELECT calculation_result, value_a, value_b, thread_id FROM results ORDER BY thread_id").fetchAll()
# check results[0].valueInteger[0] == 0'i64
# check results[0].valueInteger[1] == 30'i64
# check results[0].valueInteger[2] == 60'i64

# check results[3].valueInteger[0] == 0'i64
# check results[3].valueInteger[1] == 1'i64
# check results[3].valueInteger[2] == 2'i64

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

    for i in 0..<n:
      threadData[i] = ThreadData(id: i, db: db.addr)
      createThread(threads[i], workerThread, data)

    joinThreads(threads)

    let results = mainConn.execute("SELECT calculation_result, value_a, value_b, thread_id FROM results ORDER BY thread_id").fetchAll()
    check results[0].valueInteger[0] == 0'i64
    check results[0].valueInteger[1] == 30'i64
    check results[0].valueInteger[2] == 60'i64

    check results[3].valueInteger[0] == 0'i64
    check results[3].valueInteger[1] == 1'i64
    check results[3].valueInteger[2] == 2'i64

  test "Multiple In-Memory DB Start Up and Shutdown":
    var
      databases: array[10, Database]
      connections: array[100, Connection]

    for i in 0..<10:
      databases[i] = newDatabase()
      for j in 0..<10:
        connections[i * 10 + j] = databases[i].connect()
