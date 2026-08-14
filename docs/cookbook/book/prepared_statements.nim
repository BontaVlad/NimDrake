import nimib, nimibook
import nimdrake
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
## Named parameters

Use `$name` syntax for named parameters:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let stmt = con.newStatement("SELECT CAST($val AS BIGINT) AS result")

    let idx = stmt.bindParameter("val")
    echo "Parameter index: ", idx

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
nbSave