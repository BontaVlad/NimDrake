import nimib, nimibook
import nimdrake
import std/tables
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
## Configuration

Tuning DuckDB settings for your workload.

```nim
import nimdrake
```
"""

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
nbSave