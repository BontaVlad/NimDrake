import nimib, nimibook
import nimdrake
import std/sequtils
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
## Working with Results

Accessing query results with zero-copy typed vectors.

```nim
import nimdrake
```
"""

nbText: """
## Access columns by index

`chunk.vector(i)` returns a zero-copy view. Use `bindAs` to type it:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute("SELECT 42::BIGINT AS num, 'hello'::VARCHAR AS msg")

    for chunk in r:
      let nums = chunk.vector(0).bindAs DuckType.BigInt
      let msgs = chunk.vector(1).bindAs DuckType.Varchar
      echo nums[0], " ", msgs[0]

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Access columns by name

Use `chunk["name"]` for named access:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute("SELECT 1::INTEGER AS x, 2::INTEGER AS y")

    for chunk in r:
      let x = chunk["x"].bindAs DuckType.Integer
      let y = chunk["y"].bindAs DuckType.Integer
      echo x[0] + y[0]

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Collect all values into a seq

`toSeq` materializes a column into a Nim sequence:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute("SELECT i FROM generate_series(1, 5) AS t(i)")

    for chunk in r:
      let vals = chunk.vector(0).bindAs(DuckType.BigInt).toSeq
      echo vals

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Check for NULL values

Use `valid(i)` to check if a value is NULL:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute("SELECT NULL::BIGINT AS val, 42::BIGINT AS val2")

    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.BigInt
      echo "NULL? ", not v.valid(0)  # true
      echo "NULL? ", not v.valid(1)  # false

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Cross-chunk random access with Table API

For random access across all chunks, use the `Table` API:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute("SELECT i FROM generate_series(1, 5000) AS t(i)")
    let tbl = initTable(r)

    let col = tbl.bindAs(0, DuckType.BigInt)
    echo col[0]     # first row
    echo col[4999]  # last row
nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbSave