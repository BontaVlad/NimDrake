import nimib, nimibook
import nimdrake
import std/[os, strutils]

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
nbSave