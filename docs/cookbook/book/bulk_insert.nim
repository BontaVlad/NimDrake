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
    con.newAppender("pairs", data)

    let r = con.execute("SELECT * FROM pairs ORDER BY a")
    echo r
nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbSave