<div align="center">
  <picture>
    <source media="(prefers-color-scheme: light)" srcset="drake-svg-light-theme.svg">
    <source media="(prefers-color-scheme: dark)" srcset="drake-svg-dark-theme.svg">
    <img alt="NimDrake logo" src="drake-svg-light-theme.svg" height="200">
  </picture>
  <br>
  <img src="https://github.com/BontaVlad/NimDrake/actions/workflows/tests.yml/badge.svg" alt="MainBranch">
  <img src="https://img.shields.io/badge/unstable-pre_alpha-blue" alt="Status">
</div>
<br>

## Overview

NimDrake is a [Nim](https://nim-lang.org/) package for [DuckDB](https://duckdb.org/), an
in-process OLAP database engine. It provides a dual-layer API:

- **High level** — `execute`, `$` pretty-printing, scalar/table UDF macros, prepared
  statements with Nim-tuple binding, appenders, cross-chunk `Table` views.
- **Low level** — zero-copy `Vector[kt]` views, streaming chunk iteration, `bindAs`
  type dispatch, `ChunkBuilder`, raw DuckDB FFI handles.

NimDrake targets DuckDB v1.5.4 and Nim `>= 2.0.0`.

> NimDrake is pre-alpha. It contains bugs and missing features. Use with caution.

---

## Installation

### From the package registry

```bash
nimble install nimdrake
```

### With dev dependencies (tests, benchmarks, FFI regeneration)

```bash
nimble install nimdrake --parser:declarative --features:dev
```

`--parser:declarative` is required for nimble's declarative parser to recognise the
`dev` feature set that pulls in `unittest2` and `criterion`.

### From source

```bash
git clone https://github.com/BontaVlad/NimDrake
cd NimDrake
nimble install
```

### DuckDB native library

NimDrake needs `libduckdb.so` (Linux), `libduckdb.dylib` (macOS), or `duckdb.dll`
(Windows). The build resolves it in this order:

1. **Vendored** under `src/include/` — populate with `just fetch-lib`
2. **System-installed** — discovered via `pkg-config duckdb` or `ldconfig`
3. **Error** — if neither is present

The vendored path is preferred for reproducible builds.

---

## Quick start

```nim
import nimdrake

let db = newDatabase()
let con = db.connect()

let r = con.execute("""
  SELECT i, i * i AS sq
  FROM generate_series(1, 5) AS t(i)
""")
echo r
# ┌─────────────┬─────────────┐
# │      i      │     sq      │
# ├─────────────┼─────────────┤
# │     1       │     1       │
# │     2       │     4       │
# │     3       │     9       │
# │     4       │     16      │
# │     5       │     25      │
# └─────────────┴─────────────┘
```

---

## API guide

### Database and configuration

```nim
import nimdrake

# In-memory (default)
let db = newDatabase()
let con = db.connect()

# Persistent file
let db2 = newDatabase("mydb.duckdb")
let con2 = db2.connect()
```

### Config flags

```nim
let cfg = newConfig({"threads": "4", "memory_limit": "2GB"}.toTable)
let con = newDatabase(cfg).connect()
```

### Query execution

`con.execute("SELECT ...")` returns `QResult[Materialized]` — a fully materialised
in-memory result. `con.execute(stmt)` with a prepared statement returns
`QResult[Streaming]` for lazy chunk-by-chunk consumption.

### Accessing results — typed Vector views

```nim
let r = con.execute("SELECT 42::BIGINT AS answer, 'hello'::VARCHAR AS greeting")

for chunk in r:
  let answer   = chunk.vector(0).bindAs DuckType.BigInt
  let greeting = chunk.vector(1).bindAs DuckType.Varchar
  # or by name:
  # let answer   = chunk["answer"].bindAs DuckType.BigInt
  for i in 0 ..< answer.len:
    echo answer[i], " — ", greeting[i]
```

`Vector[kt]` is a zero-copy typed view over a DuckDB column's raw data buffer.
Use `bindAs(DuckType.X)` to select the Nim type. See the type-mapping table at
the bottom for the full `DuckType` → Nim mapping.

### Streaming iteration

```nim
let stmt = con.newStatement("SELECT i FROM generate_series(1, 1_000_000) AS t(i)")
for chunk in con.execute(stmt):
  let v = chunk.vector(0).bindAs DuckType.BigInt
  for x in v:
    discard  # process row by row
```

### Prepared statements with Nim-tuple binding

```nim
con.execute("""
  CREATE TABLE people (id BIGINT, name VARCHAR, active BOOLEAN)
""")
let stmt = con.newStatement("INSERT INTO people VALUES (?, ?, ?)")
con.execute(stmt, (int64(1), "Alice", true))
con.execute(stmt, (int64(2), "Bob", false))
echo con.execute("SELECT * FROM people ORDER BY id")
```

### Appender (bulk insert)

```nim
let appender = con.newAppender("people")
for i in 3 .. 100_000:
  appender.append(int64(i))
  appender.append("person_" & $i)
  appender.append(true)
  appender.endRow()
appender.close()
```

### Transaction helpers

```nim
con.transaction:
  con.execute("INSERT INTO people VALUES (999, 'inside', true)")
  # auto-commits on success, rolls back on exception
```

### Cross-chunk random access — Table API

```nim
let r = con.execute("SELECT i FROM generate_series(1, 5000) AS t(i)")
let tbl = initTable(r)
let col = tbl.bindAs(0, DuckType.BigInt)
echo col[4999]   # O(log n) binary search across chunks
```

---

## User-defined functions

### Scalar UDF (`registerScalar`)

Register any non-generic Nim proc as a DuckDB scalar function. The macro
introspects parameter and return types at compile time. NULL input cells
propagate to NULL output automatically (null-propagating semantics).

```nim
proc multiply(a, b: int64): int64 = a * b

let con = newDatabase().connect()
con.registerScalar(multiply)

let r = con.execute("SELECT multiply(3::BIGINT, 7::BIGINT)")
for chunk in r:
  let v = chunk.vector(0).bindAs DuckType.BigInt
  echo v[0]  # 21
```

Supported types: `bool`, `int8`–`int64`, `uint8`–`uint64`, `float32`, `float64`,
`string`, `seq[byte]`, `DateTime`, `Time`, `TimeInterval`, `Int128`, `UInt128`,
`Uuid`, `ZonedTime`.

### Table function UDF (`registerTableFunction`)

Register a `{.closure.}` iterator as a DuckDB table function. Parameters are
automatically bound from SQL.

```nim
iterator countToN(count: int): int {.closure.} =
  for i in 0 ..< count:
    yield i

let con = newDatabase().connect()
con.registerTableFunction(countToN)
echo con.execute("SELECT * FROM countToN(5)")
# ┌─────┬──────────────────┐
# │  #  │     countToN     │
# ├─────┼──────────────────┤
# │  0  │     0            │
# │  1  │     1            │
# │  2  │     2            │
# │  3  │     3            │
# │  4  │     4            │
# └─────┴──────────────────┘
```

### `{.producer.}` pragma

Sugar that auto-generates a `registerXxx(con)` proc:

```nim
iterator fibNumbers(limit: int): int {.producer, closure.} =
  var (a, b) = (0, 1)
  while a <= limit:
    yield a
    (a, b) = (b, a + b)

let con = newDatabase().connect()
registerFibNumbers(con)          # auto-generated
echo con.execute("SELECT * FROM fibNumbers(100)")
```

### Multi-column tables — tuple yields

Iterators yielding Nim named or anonymous tuples produce multi-column DuckDB output:

```nim
iterator namedCols(n: int): tuple[idx: int, label: string] {.closure.} =
  for i in 0 ..< n:
    yield (idx: i, label: "row " & $i)

con.registerTableFunction(namedCols)
let r = con.execute("SELECT * FROM namedCols(3)")
echo r.column(0).name   # "idx"
echo r.column(1).name   # "label"
```

Anonymous tuples produce default `col0`, `col1`, ... names, overridable with
`columnNames = @["name1", "name2"]`.

### NULL handling — `Option[T]`

`Option[T]` return types produce SQL NULL; `Option[T]` parameters accept NULL
bind values:

```nim
iterator withNulls(n: int): Option[int] {.closure.} =
  for i in 0 ..< n:
    if i == 0:
      yield none(int)       # NULL in DuckDB
    else:
      yield some(i)
```

### Advanced options

```nim
# Cardinality hint
con.registerTableFunction(myIter, cardinality = 1000, exact = true)

# Named SQL parameters (call-site: my_func(a := 1))
con.registerTableFunction(myIter, named = true)

# Per-thread local-init callback
con.registerTableFunction(myIter, localInit = myLocalInit)
```

---

## Complex types — List, Struct, Map, Union

```nim
let r = con.execute("SELECT [1, 2, 3] AS nums, {'k': 'v'}::MAP(VARCHAR, VARCHAR) AS mp")
for chunk in r:
  let listCol = chunk.vector(0).bindAs DuckType.List
  let child   = listCol.listChild().bindAs DuckType.Integer
  let (offset, length) = listCol.listEntry(0)
  for j in offset ..< offset + length:
    echo child[j]

  # Map key/value access
  let mapCol = chunk.vector(1).bindAs DuckType.Map
  echo mapCol.mapKeyType()    # Varchar
  echo mapCol.mapValueType()  # Varchar
```

Recursive materialisation via `NimValue` is also available:

```nim
let r = con.execute("SELECT [1, 2, 3]")
let nv = r.scalar  # NimValue(kind: nvList, ...)
```

---

## Arrow export

When `features.nimdrake.arrow` is defined and `narrow >= 0.0.1` is installed:

```nim
let r = con.execute("SELECT * FROM generate_series(1, 100) AS t(i)")
for batch in r.toArrowStream():
  echo batch.schema
  echo batch.column(0).toSeq(float64)   # or any arrow-backed type
```

---

## Type mapping

| DuckType | Nim type |
|---|---|
| `Boolean` | `bool` |
| `TinyInt` | `int8` |
| `SmallInt` | `int16` |
| `Integer` | `int32` |
| `BigInt` | `int64` / `int` |
| `UTinyInt` | `uint8` / `byte` |
| `USmallInt` | `uint16` |
| `UInteger` | `uint32` |
| `UBigInt` | `uint64` |
| `Float` | `float32` |
| `Double` | `float64` |
| `Timestamp` / `TimestampS` / `TimestampMs` / `TimestampNs` / `Date` | `DateTime` |
| `Time` | `Time` |
| `TimeTz` / `TimestampTz` | `ZonedTime` |
| `Interval` | `TimeInterval` |
| `HugeInt` | `Int128` |
| `UHugeInt` | `UInt128` |
| `Varchar` / `Bit` | `string` |
| `Blob` | `seq[byte]` |
| `Decimal` | `DecimalType` |
| `UUID` | `Uuid` |
| `Enum` | `uint` |
| `List` / `Array` | child access via `listEntry` / `arrayChild` |
| `Struct` | child access via `structChild` / `structChildName` |
| `Map` | key/value access via `mapKeyType` / `mapValueType` |
| `Union` | tag + member child access |

---

## Dependencies

**Production** (required):

```
nim >= 2.0.0
nint128
decimal >= 0.0.2
terminaltables >= 0.1.1
uuid4 >= 0.9.3
fusion >= 1.2
threading >= 0.2.1
```

**Dev** (tests, benchmarks, FFI regeneration):

```
unittest2 >= 0.2.3
criterion >= 0.3.1
```

**Optional** — Arrow export:

```
narrow >= 0.0.1    # via feature "arrow"
```

**Native**: DuckDB C library v1.5.4 (vendored or system-installed).

---

## Development

NimDrake uses [just](https://github.com/casey/just) for build orchestration.

```bash
just test                # all tests, debug + ASan, sequential
just test isParallel=true cores=8  # parallel
just test-release        # release mode, no leak checks
just test-arc            # ARC mm
just test-arrow          # include Arrow tests
just coverage            # lcov → coverage/index.html
just benchmark           # run benchmarks
just format src          # format with nph
just generate            # regenerate FFI from duckdb.h via Futhark
just debug nim_file="tests/test_query.nim"  # debug with rr+lldb
just valgrind nim_file="..."                # Valgrind leak check
```

See [WORKBOARD.md](WORKBOARD.md) for the project status and TODO list.

---

## Acknowledgements

- Portions inspired by [DuckDB Julia](https://duckdb.org/docs/api/julia.html)
- [Futhark](https://github.com/arnetheduck/nim-futhark) for FFI generation
- [nint128](https://github.com/cheatfate/nim-nint128) and [decimal](https://github.com/ba0f3/decimal) for 128-bit and decimal types
- [terminaltables](https://github.com/ThomasTJdev/nim-terminaltables) for pretty-printing
- [uuid4](https://github.com/krux02/uuid4) for UUID support
