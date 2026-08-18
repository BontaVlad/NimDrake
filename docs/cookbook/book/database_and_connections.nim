import nimib, nimibook
import nimdrake
import std/[os, tables]
import std/strutils
nbInit(theme = useNimibook)

proc stripBlockCode(code: string): string =
  let lines = code.splitLines()
  if lines.len == 0 or lines[0].strip != "block:":
    return code
  var outLines: seq[string]
  for i in 1 ..< lines.len:
    var l = lines[i]
    if l.startsWith("  "):
      l = l[2 .. ^1]
    outLines.add l
  outLines.join("\n")

nbText: """
## Database and Connections

How to create databases, connect, and configure DuckDB.

```nim
import nimdrake
```
"""

nbText: """
## Connect or create a Database

To use DuckDB, you must first create a connection to a database.

DuckDB can operate in both persistent mode, where the data is saved to disk, and in in-memory mode, where the entire dataset is stored in main memory.

"""

nbText: """
## Create an in-memory database

The simplest database is in-memory — no file, no persistence, therefore, all data is lost when the process finishes:
"""

nbCode:
  block:
    let db = newDatabase()
    let con = db.connect()

    let r = con.execute("SELECT 42 AS answer")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Create a persistent database

To create or open a persistent database, pass the database file path to
`newDatabase`, for example `my_database.duckdb`.
The path can point to an existing file or to a file that does not yet exist.
DuckDB opens the existing database or creates a new one at that path.
"""

nbCode:
  block:
    let path = getTempDir() / "my_app.duckdb"
    if fileExists(path):
      removeFile(path)  # clean slate from any previous run

    let db = newDatabase(path)
    let con = db.connect()

    con.execute("CREATE TABLE settings (key VARCHAR, value VARCHAR)")
    con.execute("INSERT INTO settings VALUES ('theme', 'dark')")

    # Reopen — data persists
    let db2 = newDatabase(path)
    let con2 = db2.connect()
    let r = con2.execute("SELECT * FROM settings")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Set thread count

Control parallelism with the `threads` setting:
"""

nbCode:
  block:
    let cfg = newConfig({"threads": "8"}.toTable)
    let con = newDatabase(cfg).connect()

    let r = con.execute("SELECT current_setting('threads') AS t")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Set memory limit

Cap memory usage for embedded or shared environments:
"""

nbCode:
  block:
    let cfg = newConfig({"memory_limit": "512MB"}.toTable)
    let con = newDatabase(cfg).connect()

    let r = con.execute("SELECT current_setting('memory_limit') AS ml")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Multiple settings at once
"""

nbCode:
  block:
    let cfg = newConfig({
      "threads": "4",
      "memory_limit": "512MB"
    }.toTable)

    let con = newDatabase(cfg).connect()

    let r = con.execute("""
      SELECT
        current_setting('threads') AS threads,
        current_setting('memory_limit') AS memory_limit
    """)
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Invalid settings raise errors
"""

nbCode:
  block:
    try:
      let cfg = newConfig({"invalid_key": "value"}.toTable)
    except OperationError as e:
      echo "Caught error for invalid key"
nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Concurrency

So far every recipe used a single connection. This section looks at what
happens when several connections, threads, or processes use the same data
at the same time, and what guarantees each setup offers.

### Handling concurrency

In in-process mode, DuckDB has two configurable options for concurrency:

* **Read-write mode**: one process can both read and write to the database.
* **Read-only mode**: multiple processes can read from the database, but no
  processes can write (`access_mode = 'READ_ONLY'`, see the read-only section).

When using read-write mode, DuckDB supports multiple writer threads using a
combination of MVCC (Multi-Version Concurrency Control) and optimistic
concurrency control (see below), but all within that single writer process.
The reason for this concurrency model is to allow for the caching of data in
RAM for faster analytical queries, rather than going back and forth to disk
during each query. It also allows the caching of function pointers, the
database catalog, and other items so that subsequent queries on the same
connection are faster.

### Concurrency model within a single process

DuckDB supports concurrency within a single process according to the
following rules. As long as there are no write conflicts, multiple concurrent
writes will succeed:

* Appends will never conflict, even on the same table.
* Multiple threads can also simultaneously update separate tables or separate
  subsets of the same table.

Optimistic concurrency control comes into play when two threads attempt to
edit (update or delete) the same row at the same time. In that situation, the
second thread to attempt the edit will fail with a conflict error.

Two connections appending to the same table in simultaneous transactions are
both allowed to commit:
"""

nbCode:
  block:
    let db = newDatabase()
    let con1 = db.connect()
    let con2 = db.connect()
    con1.execute("CREATE TABLE log (id INTEGER, note VARCHAR)")

    con1.execute("BEGIN")
    con2.execute("BEGIN")
    con1.execute("INSERT INTO log VALUES (1, 'from connection 1')")
    con2.execute("INSERT INTO log VALUES (2, 'from connection 2')")
    con1.execute("COMMIT")
    con2.execute("COMMIT")

    let r = con1.execute("SELECT id, note FROM log ORDER BY id")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
## Open an on-disk database read-only

Reopen an existing database with `access_mode = read_only` to prevent writes:
"""

nbCode:
  block:
    let path = getTempDir() / "readonly.duckdb"
    if fileExists(path):
      removeFile(path)  # clean slate

    block setup:
      let db = newDatabase(path)
      let con = db.connect()
      con.execute("CREATE TABLE ro_test (x INTEGER)")
      con.executeMaterialized("INSERT INTO ro_test VALUES (?)", (99,))

    let cfg = newConfig({"access_mode": "read_only"}.toTable)
    let db = newDatabase(path, cfg)
    let con = db.connect()

    let r = con.execute("SELECT x FROM ro_test")
    echo r

    try:
      con.execute("INSERT INTO ro_test VALUES (1)")
    except OperationError as e:
      echo "write rejected: ", e.msg

    removeFile(path)

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
## Multiple connections to one database

A single `Database` can serve multiple connections — they share the same data:
"""

nbCode:
  block:
    let db = newDatabase()
    let con1 = db.connect()
    let con2 = db.connect()

    con1.execute("CREATE TABLE t (i INTEGER)")
    con1.execute("INSERT INTO t VALUES (1)")

    let r = con2.execute("SELECT * FROM t")
    echo r
nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
### Multiple processes

DuckDB uses optimistic concurrency control, an approach generally considered
to be the best fit for read-intensive analytical database systems, as it
speeds up read query processing. As a result, any transactions that modify
the same rows at the same time will cause a transaction conflict error:

* In plain words: instead of taking locks on rows before reading them, every
  transaction works on its own snapshot of the data and only checks for
  conflicts when it tries to modify a row.
* MVCC (Multi-Version Concurrency Control): each transaction sees a
  consistent snapshot of the data, so readers never block writers and vice
  versa.
* Conflict error: a transaction receives this error when it modifies a row
  that another, still uncommitted, transaction has already modified.

The conflict surfaces at write time. A rolled-back transaction can be retried
after the first transaction finishes:
"""

nbCode:
  block:
    let db = newDatabase()
    let con1 = db.connect()
    let con2 = db.connect()
    con1.execute("CREATE TABLE ticket (id INTEGER, available INTEGER)")
    con1.execute("INSERT INTO ticket VALUES (1, 5)")

    # Both connections start a transaction and edit the same row
    con1.execute("BEGIN")
    con2.execute("BEGIN")
    con1.execute("UPDATE ticket SET available = available - 1 WHERE id = 1")

    try:
      con2.execute("UPDATE ticket SET available = available - 1 WHERE id = 1")
      echo "second update: no conflict"
      con2.execute("COMMIT")
    except OperationError as e:
      echo "second update: conflict -> ", e.msg
      con2.execute("ROLLBACK")

    con1.execute("COMMIT")

    # Retry after the rollback: the first transaction is done, so this works.
    # The connection is back in autocommit mode, so no COMMIT is needed.
    con2.execute("UPDATE ticket SET available = available - 1 WHERE id = 1")

    let r = con1.execute("SELECT available FROM ticket WHERE id = 1")
    echo "remaining tickets: ", r.scalar

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
## Thread-safe connections

A single `Database` can be shared across threads. Each thread opens its own
connection with `connect()`; connections themselves are not shared between
threads:
"""

nbCode:
  block:
    let db = newDatabase()
    let mainConn = db.connect()

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
        (args.id, a, b, res))

    var threads = newSeq[Thread[tuple[db: Database, id: int]]](5)
    for i in 0..<5:
      createThread(threads[i], worker, (db, i))
    joinThreads(threads)

    let r = mainConn.execute(
      "SELECT thread_id, value_a, value_b, calculation_result FROM results ORDER BY thread_id")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)


nbSave
