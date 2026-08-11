# Database and Connections

How to create databases, connect, and configure DuckDB.

----

## Create an in-memory database

The simplest database is in-memory — no file, no persistence:

```nim test
import nimdrake

let db = newDatabase()
let con = db.connect()

let r = con.execute("SELECT 42 AS answer")
echo r
```

```
┌────────────────┐
│     answer     │
├────────────────┤
│     42         │
└────────────────┘
```

```
┌────────────────┐
│     answer     │
├────────────────┤
│     42         │
└────────────────┘
```

```

## Create a persistent database

Pass a file path to create a database that survives restarts:

```nim test
import nimdrake
import std/[os]

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
```

```
┌───────────────┬───────────────┐
│     key       │     value     │
├───────────────┼───────────────┤
│     theme     │     dark      │
└───────────────┴───────────────┘
```

```
Error during execution:
/tmp/cookbook_snippet.nim(8) cookbook_snippet
/mnt/c/Users/Vlad/Sandbox/NimDrake/src/query.nim(60) execute
Error: unhandled exception: execute query: Catalog Error: Table with name "settings" already exists! [OperationError]
Error: execution of an external program failed: '/home/vlad/.cache/nim/cookbook_snippet_d/cookbook_snippet_393D3217F8A50B9BC257A91AD71334592602E713'
```

```

## Configure thread count and memory limit

```nim test
import nimdrake
import std/tables

let cfg = newConfig({
  "threads": "4",
  "memory_limit": "2GB"
}.toTable)

let db = newDatabase(cfg)
let con = db.connect()

let r = con.execute("SELECT current_setting('threads') AS t")
echo r
```

```
┌───────────┐
│     t     │
├───────────┤
│     4     │
└───────────┘
```

```
┌───────────┐
│     t     │
├───────────┤
│     4     │
└───────────┘
```

```

## Multiple connections to one database

A single `Database` can serve multiple connections — they share the same data:

```nim test
import nimdrake

let db = newDatabase()
let con1 = db.connect()
let con2 = db.connect()

con1.execute("CREATE TABLE t (i INTEGER)")
con1.execute("INSERT INTO t VALUES (1)")

let r = con2.execute("SELECT * FROM t")
echo r
```

```
┌───────────┐
│     i     │
├───────────┤
│     1     │
└───────────┘
```

```
┌───────────┐
│     i     │
├───────────┤
│     1     │
└───────────┘
```
