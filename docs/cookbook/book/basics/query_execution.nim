import nimib, nimibook
import nimdrake
import nimdrake/dsl/queries
import std/[os, strutils, tables, algorithm]

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
## Query Execution

Running SQL queries, streaming results, and handling errors.

```nim
import nimdrake
```
"""

nbText: """
## Execute a simple query

`execute` runs SQL and returns a `QResult`. Print it for a formatted table:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute("""
      SELECT i, i * i AS sq
      FROM generate_series(1, 5) AS t(i)
    """)
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Stream results chunk by chunk

For large result sets, iterate chunks to avoid loading everything into memory:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let stmt = con.newStatement(
      "SELECT i FROM generate_series(1, 1_000_000) AS t(i)"
    )
    var count = 0
    for chunk in con.executeStreaming(stmt):
      let v = chunk.vector(0).bindAs DuckType.BigInt
      count += v.len
    echo "Total rows: ", count

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Use prepared statements for repeated queries

Prepare once, execute many times with different parameters:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE items (id INTEGER, name VARCHAR)")

    let stmt = con.newStatement("INSERT INTO items VALUES (?, ?)")
    con.executeMaterialized(stmt, (1, "apple"))
    con.executeMaterialized(stmt, (2, "banana"))
    con.executeMaterialized(stmt, (3, "cherry"))

    let r = con.execute("SELECT * FROM items ORDER BY id")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Query CSV and Parquet files directly

DuckDB can query files without importing them:
"""

nbCode:
  block:
    let con = newDatabase().connect()

    # Create a sample CSV
    let csvPath = getTempDir() / "sample.csv"
    writeFile(csvPath, "id,name\n1,alice\n2,bob\n")

    let r = con.execute("SELECT * FROM read_csv_auto('" & csvPath & "')")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Query with the compile-time DSL

`nimdrake/dsl/queries` provides a `query` macro that builds SQL from Nim
expressions. Parameters are bound with `?expr`, raw SQL can be spliced with
`!!"..."`, and the result is a materialized `QResult`:

```nim
import nimdrake/dsl/queries
```

Insert rows with bound parameters and select them back with a `where` clause:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE thread (id INTEGER, name VARCHAR, views INTEGER)")

    discard query(con):
      insert thread(id = ?(1), name = ?"intro", views = ?(10))
    discard query(con):
      insert thread(id = ?(2), name = ?"deep dive", views = ?(3))

    let res = query(con):
      select thread(id, name, views)
      where id == ?(2)
    echo res

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## DSL: update and delete

DML works the same way; `rowsChanged` reports how many rows were touched:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE item (id INTEGER, price DOUBLE, name VARCHAR)")
    discard query(con):
      insert item(id = ?(1), price = ?(9.99), name = ?"shirt")

    let upd = query(con):
      update item(price = ?(12.49))
      where id == ?(1)
    echo "updated rows: ", upd.rowsChanged

    discard query(con):
      delete item
      where id == ?(1)

    let remaining = query(con):
      select item(id)
    echo "rows after delete: ", remaining.len

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## DSL: join two tables

The `select` table is alias `t1`, each `join` table gets `t2`, `t3`, ... in
order. Columns of later tables must be qualified with their alias:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE customer (id INTEGER, name VARCHAR)")
    con.execute("CREATE TABLE orders (id INTEGER, customer_id INTEGER, amount DOUBLE)")
    discard query(con):
      insert customer(id = ?(1), name = ?"Alice")
    discard query(con):
      insert orders(id = ?(1), customer_id = ?(1), amount = ?(25.0))

    let res = query(con):
      select customer(name, t2.amount)
      join orders() on t1.id == t2.customer_id
      where t1.id == ?(1)
    echo res

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## DSL: aggregate with groupby

Aggregates go in the select; `groupby`, `having`, and `orderby` follow. SQL's
`*` is spelled `_` inside the DSL:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE sales (region VARCHAR, amount DOUBLE)")
    discard query(con):
      insert sales(region = ?"EU", amount = ?(100.0))
    discard query(con):
      insert sales(region = ?"EU", amount = ?(50.0))
    discard query(con):
      insert sales(region = ?"US", amount = ?(200.0))

    let res = query(con):
      select sales(region, sum(amount) as total)
      groupby(region)
      having sum(amount) > ?(75.0)
      orderby desc(total)
    echo res

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## DSL: upsert with onconflict

`onconflict(columns)` with `doupdate(...)` implements upsert; `donothing()`
keeps the existing row:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE counter (id INTEGER PRIMARY KEY, views INTEGER)")
    discard query(con):
      insert counter(id = ?(1), views = ?(10))
    discard query(con):
      insert counter(id = ?(1), views = ?(20))
      onconflict(id)
      doupdate(views = ?(20))
    let res = query(con):
      select counter(views)
    echo res

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## DSL: orderby, limit, offset

Pagination composes like plain SQL:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE scores (player VARCHAR, score INTEGER)")
    for i in 1 .. 5:
      discard query(con):
        insert scores(player = ?("p" & $i), score = ?(i * 10))
    let res = query(con):
      select scores(player, score)
      orderby desc(score)
      limit 3 offset 1
    echo res

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## A complex DSL query

The DSL scales to full OLAP queries — multi-table joins, grouped aggregates,
`having`, ordering, and limits, all in one statement. This mirrors the shape
of TPC-H Q5 from the test suite. Note the auto-aliases: `department` is `t1`,
`employee` is `t2`, so the join column is `t2.dept`:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE department (id INTEGER, name VARCHAR, budget DOUBLE)")
    con.execute("CREATE TABLE employee (id INTEGER, name VARCHAR, dept INTEGER, salary DOUBLE)")
    discard query(con):
      insert department(id = ?(1), name = ?"eng", budget = ?(500.0))
    discard query(con):
      insert department(id = ?(2), name = ?"sales", budget = ?(400.0))
    discard query(con):
      insert employee(id = ?(1), name = ?"Alice", dept = ?(1), salary = ?(80.0))
    discard query(con):
      insert employee(id = ?(2), name = ?"Bob", dept = ?(1), salary = ?(60.0))
    discard query(con):
      insert employee(id = ?(3), name = ?"Carol", dept = ?(2), salary = ?(90.0))
    discard query(con):
      insert employee(id = ?(4), name = ?"Dave", dept = ?(2), salary = ?(10.0))

    let res = query(con):
      select department(name, sum(t2.salary) as payroll)
      join employee() on t1.id == t2.dept
      groupby(t1.name)
      having sum(t2.salary) > ?(100.0)
      orderby desc(payroll)
      limit 10
    echo res

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Execute a query step by step

Pending results let you drive execution manually with `step()` until
`isFinished`, useful for progress reporting or cancellation:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let stmt = con.newStatement("SELECT i FROM range(100) t(i)")
    var pending = newPendingStreamingResult(stmt)
    while true:
      let state = pending.step()
      if state.isFinished or state == PendingState.Error:
        break
    var total = 0
    for chunk in pending.executeStreaming():
      total += chunk.len
    echo "rows: ", total

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Query progress and interrupt

`queryProgress` reports how far a running query has gotten (`-1` when no
query is in flight). With `step()` you can watch progress advance, and
`interrupt()` requests cancellation from another context. Output below is
timing-dependent, so exact numbers vary between runs:
"""

nbCode:
  block:
    let cfg = newConfig({"threads": "1"}.toTable)
    let con = newDatabase(cfg).connect()

    con.execute("CREATE TABLE tbl AS SELECT RANGE a, MOD(RANGE,10) b FROM RANGE(10000)")
    con.execute("CREATE TABLE tbl_2 AS SELECT RANGE a FROM RANGE(10000)")
    con.execute("SET enable_progress_bar=true")
    con.execute("SET enable_progress_bar_print=false")

    echo "idle progress: ", con.queryProgress.percentage

    let stmt = con.newStatement("SELECT COUNT(*) FROM tbl WHERE a = (SELECT MIN(a) FROM tbl_2)")
    var pending = newPendingStreamingResult(stmt)

    var sawProgress = false
    var steps = 0
    while true:
      let state = pending.step()
      if con.queryProgress.percentage > 0.0:
        sawProgress = true
      if state.isFinished or state == PendingState.Error:
        break
      inc steps
      if steps >= 1_000_000:  # hang guard only
        break

    let progress = con.queryProgress
    echo "saw progress during run: ", sawProgress
    echo "final progress: ", progress.percentage.formatFloat(ffDecimal, 2),
      "% (rows processed: ", progress.rowsProcessed, ")"

    # Interrupt mid-flight: safe to call at any point. The pending resolves
    # to Error when interrupted, or to Ready if it already completed.
    con.interrupt()
    var finalState = PendingState.NotReady
    var guard = 0
    while true:
      finalState = pending.step()
      if finalState.isFinished or finalState == PendingState.Error:
        break
      inc guard
      if guard >= 1_000_000:  # hang guard only
        break
    echo "state after interrupt: ", finalState

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Pending states observed while stepping

While `step()` drives execution, the pending result reports the states the
wrapper enum exposes: `Ready`, `NotReady`, `Error`, and `NoTasksAvailable`.
`isFinished` marks completion — in the run below the query finishes with
`Ready`:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let stmt = con.newStatement("SELECT SUM(i) FROM range(1000000) tbl(i)")
    let pending = newPendingStreamingResult(stmt)
    var observed: set[PendingState]
    var lastState = PendingState.NotReady
    var steps = 0
    while true:
      let state = pending.step()
      lastState = state
      observed.incl state
      inc steps
      if state.isFinished or state == PendingState.Error:
        break
      if steps >= 1_000_000:  # hang guard only
        break
    var seen: seq[string]
    for s in observed:
      seen.add $s
    seen.sort
    echo "steps: ", steps, "  last state: ", lastState, "  observed: ", seen.join(", ")

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Handle errors gracefully

Invalid SQL raises `OperationError`:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    try:
      con.execute("THIS IS NOT VALID SQL")
    except OperationError as e:
      echo "Caught error: ", e.msg
nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Transactions: commit on success

Wrap a group of statements in `transaction` — committed automatically when
the block ends, rolled back if anything raises:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE accounts (id INTEGER, balance INTEGER)")
    con.execute("INSERT INTO accounts VALUES (1, 1000), (2, 500)")

    con.transaction:
      con.execute("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
      con.execute("UPDATE accounts SET balance = balance + 100 WHERE id = 2")

    let r = con.execute("SELECT * FROM accounts ORDER BY id")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Transactions: rollback on exception

If an exception occurs inside the block, all changes are rolled back:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE items (id INTEGER, name VARCHAR)")
    con.execute("INSERT INTO items VALUES (1, 'existing')")

    try:
      con.transaction:
        con.execute("INSERT INTO items VALUES (2, 'new')")
        raise newException(ValueError, "something went wrong")
    except ValueError:
      discard

    let r = con.execute("SELECT count(*)::BIGINT AS n FROM items")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Transactions: readback inside the block

Uncommitted changes are visible to subsequent queries on the same connection,
so you can read intermediate state before deciding to commit:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE counter (val INTEGER)")
    con.execute("INSERT INTO counter VALUES (0)")

    con.transaction:
      con.execute("UPDATE counter SET val = val + 10")
      let r = con.execute("SELECT val FROM counter")
      echo "inside: ", r.scalar

    let r2 = con.execute("SELECT val FROM counter")
    echo "after commit: ", r2.scalar
nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Transactions: transient — always roll back

`transient` runs a block inside a transaction that is **always** rolled back.
Use it for experiments or staging work you never want to commit:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE scratch (v INTEGER)")

    con.transient:
      con.execute("INSERT INTO scratch VALUES (1), (2), (3)")
      echo "inside: ", con.execute("SELECT count(*)::BIGINT AS n FROM scratch").scalar

    echo "after rollback: ", con.execute("SELECT count(*)::BIGINT AS n FROM scratch").scalar
nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbSave