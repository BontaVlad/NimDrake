# Configuration

Tuning DuckDB settings for your workload.

----

## Set thread count

Control parallelism with the `threads` setting:

```nim test
import nimdrake
import std/tables

let cfg = newConfig({"threads": "8"}.toTable)
let con = newDatabase(cfg).connect()

let r = con.execute("SELECT current_setting('threads') AS t")
echo r
```

```
┌───────────┐
│     t     │
├───────────┤
│     8     │
└───────────┘
```

## Set memory limit

Cap memory usage for embedded or shared environments:

```nim test
import nimdrake
import std/tables

let cfg = newConfig({"memory_limit": "512MB"}.toTable)
let con = newDatabase(cfg).connect()

let r = con.execute("SELECT current_setting('memory_limit') AS ml")
echo r
```

```
┌───────────────────┐
│     ml            │
├───────────────────┤
│     488.2 MiB     │
└───────────────────┘
```

## Multiple settings at once

```nim test
import nimdrake
import std/[tables, os]

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
```

```
┌─────────────────┬──────────────────────┐
│     threads     │     memory_limit     │
├─────────────────┼──────────────────────┤
│     4           │     488.2 MiB        │
└─────────────────┴──────────────────────┘
```

## Invalid settings raise errors

```nim test
import nimdrake
import std/tables

try:
  let cfg = newConfig({"invalid_key": "value"}.toTable)
except OperationError as e:
  echo "Caught error for invalid key"
```

```

```

