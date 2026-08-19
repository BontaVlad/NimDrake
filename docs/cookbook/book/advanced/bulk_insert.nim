import nimib, nimibook
import nimdrake
import std/options
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
## Bulk Insert with Appender

High-throughput data loading with the Appender API.

```nim
import nimdrake
```
"""

nbText: """
## Basic appender usage

The Appender is the fastest way to insert large volumes of data:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE logs (ts VARCHAR, level VARCHAR, msg VARCHAR)")

    var appender = con.newAppender("logs")
    for i in 0 ..< 100:
      appender.append("2024-01-01 00:00:00")
      appender.append("INFO")
      appender.append("Event " & $i)
      appender.endRow()
    appender.close()

    let r = con.execute("SELECT count(*)::BIGINT AS n FROM logs")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Appender with typed columns

Match the column types in your table:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("""
      CREATE TABLE metrics (
        id BIGINT,
        value DOUBLE,
        label VARCHAR,
        active BOOLEAN
      )
    """)

    var appender = con.newAppender("metrics")
    for i in 1 .. 5:
      appender.append(int64(i))
      appender.append(i.float64 * 1.5)
      appender.append("metric_" & $i)
      appender.append(i mod 2 == 0)
      appender.endRow()
    appender.close()

    let r = con.execute("SELECT * FROM metrics ORDER BY id")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Appender from a sequence of tuples

Bulk insert from existing data:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE pairs (a INTEGER, b VARCHAR)")

    let data = @[
      @["1", "one"],
      @["2", "two"],
      @["3", "three"],
    ]
    con.appendRows("pairs", data)

    let r = con.execute("SELECT * FROM pairs ORDER BY a")
    echo r
nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Append NULL values with Option

`append(none(T))` writes SQL NULL, `append(some(v))` a value:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE null_test (i INTEGER, s VARCHAR, d DOUBLE)")

    var appender = con.newAppender("null_test")
    appender.append(some(1'i32))
    appender.append(none(string))
    appender.append(none(float64))
    appender.endRow()
    appender.append(some(2'i32))
    appender.append(some("b"))
    appender.append(some(2.5))
    appender.endRow()
    appender.close()

    let r = con.execute("SELECT * FROM null_test ORDER BY i")
    for chunk in r:
      for row in 0 ..< chunk.len:
        echo chunk.bindAs(0, DuckType.Integer)[row],
          " s_valid=", chunk.vector(1).valid(row),
          " d_valid=", chunk.vector(2).valid(row)

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Append DEFAULT values

`append()` with no argument lets DuckDB fill in the column default:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE default_test (a INTEGER, b INTEGER DEFAULT 5)")

    var appender = con.newAppender("default_test")
    appender.append(42'i32)
    appender.append()
    appender.endRow()
    appender.close()

    let r = con.execute("SELECT * FROM default_test")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Append typed nullable rows

Use `appendRows` when your input already exists as Nim values. A tuple gives
the row shape, and `Option[T]` maps directly to a nullable DuckDB column.
"""

nbCode:
  block:
    type Reading = tuple[id: int64, label: string, value: Option[float64]]

    let con = newDatabase().connect()
    con.execute("CREATE TABLE readings (id BIGINT, label VARCHAR, value DOUBLE)")

    let rows: seq[Reading] = @[
      (int64(1), "temperature", some(21.5)),
      (int64(2), "temperature", none(float64)),
      (int64(3), "temperature", some(22.0)),
    ]
    con.appendRows("readings", rows)

    echo con.execute("SELECT id, label, value FROM readings ORDER BY id")

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Column-count errors surface at endRow

Column-count mistakes raise `OperationError` when the row is closed:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE no_default_test (a INTEGER, b INTEGER)")

    var appender = con.newAppender("no_default_test")
    appender.append(1'i32)  # b has no default and was never appended
    try:
      appender.endRow()
    except OperationError as e:
      echo "Caught error: ", e.msg
nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbSave
