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
## Create an in-memory database

The simplest database is in-memory — no file, no persistence:
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

Pass a file path to create a database that survives restarts:
"""

nbCode:
  block:
    let path = getTempDir() / "my_app.duckdb"
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
## Configure thread count and memory limit
"""

nbCode:
  block:
    let cfg = newConfig({
      "threads": "4",
      "memory_limit": "2GB"
    }.toTable)

    let db = newDatabase(cfg)
    let con = db.connect()

    let r = con.execute("SELECT current_setting('threads') AS t")
    echo r

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
nbSave