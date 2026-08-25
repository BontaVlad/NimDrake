import nimib, nimibook
import ../cookbook_theme
import nimdrake
import std/strutils

nbInit(theme = useCookbook)

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
## Prepared Statements

Type-safe parameter binding for repeated queries.

```nim
import nimdrake
```
"""

nbText: """
## Basic parameter binding

Use `?` as placeholders and pass a tuple of values:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE people (id BIGINT, name VARCHAR, active BOOLEAN)")

    let stmt = con.newStatement("INSERT INTO people VALUES (?, ?, ?)")
    con.executeMaterialized(stmt, (int64(1), "Alice", true))
    con.executeMaterialized(stmt, (int64(2), "Bob", false))

    let r = con.execute("SELECT * FROM people ORDER BY id")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Named parameters: bind and execute

Use `$name` syntax when a parameter name makes a query easier to read. Resolve
the name once, bind a typed value, and then execute the statement:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let stmt = con.newStatement("SELECT CAST($val AS BIGINT) AS result")

    let idx = stmt.bindParameter("val")
    discard stmt.bindVal(idx, 42'i64)

    let r = con.executeStreaming(stmt)
    for chunk in r:
      echo chunk.bindAs(0, DuckType.BigInt)[0]

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Inspect parameter types

Query the `parameters` field to see what DuckDB expects:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE t (a INTEGER, b VARCHAR, c BOOLEAN)")
    let stmt = con.newStatement("INSERT INTO t VALUES (?, ?, ?)")

    for param in stmt.parameters:
      echo param.name, " -> ", param.tpy

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## DML statements use executeMaterialized

`INSERT`, `UPDATE`, `DELETE` don't produce streaming results:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE counters (id INTEGER, val INTEGER)")
    con.executeMaterialized("INSERT INTO counters VALUES (1, 100)", ())
    con.executeMaterialized("UPDATE counters SET val = 200 WHERE id = 1", ())
    con.executeMaterialized("DELETE FROM counters WHERE id = 1", ())

    let r = con.execute("SELECT count(*)::BIGINT AS n FROM counters")
    echo r
nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Reuse a prepared statement

Prepare once, bind many times — DuckDB reuses the parsed plan:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE reuse_test (x BIGINT, y VARCHAR)")

    let stmt = con.newStatement("INSERT INTO reuse_test VALUES (?, ?)")
    for i in 1 .. 3:
      con.executeMaterialized(stmt, (i.int64, "item_" & $i))

    let r = con.execute("SELECT * FROM reuse_test ORDER BY x")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Bind NULL values

`bindNull(statement, index)` marks a parameter as SQL NULL:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE nullable_table (int_val INTEGER, str_val VARCHAR)")

    let stmt = con.newStatement("INSERT INTO nullable_table VALUES (?, ?)")
    discard bindNull(stmt, 1)
    discard bindNull(stmt, 2)
    con.executeMaterialized(stmt)

    let r = con.execute("SELECT int_val, str_val FROM nullable_table")
    for chunk in r:
      echo "int is NULL? ", not chunk.vector(0).valid(0)
      echo "str is NULL? ", not chunk.vector(1).valid(0)

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Prepared SELECT

Prepared statements aren't just for DML — parameterized reads stream
results like any other query:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE people (id BIGINT, name VARCHAR)")
    for i in 1 .. 5:
      con.executeMaterialized("INSERT INTO people VALUES (?, ?)", (i.int64, "p" & $i))

    let stmt = con.newStatement("SELECT name FROM people WHERE id >= ?")
    let r = con.executeStreaming(stmt, (3.int64,))
    for chunk in r:
      for name in chunk.bindAs(0, DuckType.Varchar):
        echo name
nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Choose the execution method

Use `executeMaterialized` for DML because DuckDB does not return a streaming
result for `INSERT`, `UPDATE`, or `DELETE`. Use `executeStreaming` for a
prepared `SELECT` when the rows can be processed incrementally.
"""
nbSave
