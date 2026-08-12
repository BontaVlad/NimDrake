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

NimDrake is a [Nim](https://nim-lang.org/) binding for
[DuckDB](https://duckdb.org/) — the in-process analytical SQL engine.
## Features

- **Zero-copy reads** — results are exposed as typed views over DuckDB's own
  columnar buffers. Primitives (`int64`, `float64`, …) are read in place;
  only `string`, `blob`, `decimal`, `UUID` are copied per value.
- **Layered API** — high-level `execute`, pretty-printing, tuple-bound
  prepared statements, appender, cross-chunk `Table` views; low-level
  `Vector[kt]`, streaming chunks, raw FFI handles.
- **UDFs** — register Nim procs and `{.closure.}` iterators as DuckDB scalar,
  aggregate, and table functions. Per-row work stays inside the engine.
- **Arrow export** — optional `narrow` integration streams results as Arrow
  record batches.
- **Full type system** — all 42 DuckDB types mapped, including List, Array,
  Struct, Map, Union, Decimal, UUID, and 128-bit integers. Complex kinds are
  exposed via zero-copytyped container views: `bindAs Table[K,V]`,
  `bindAs seq[T]`, `bindAsArray(kt)`.

**Target versions:** DuckDB v1.5.4, Nim `>= 2.0.0`.

> NimDrake is pre-alpha. APIs and behavior may change.

**[Cookbook](https://bontavlad.github.io/NimDrake/cookbook/cookbook.html)** — recipes for common tasks.

---

## Installation

```bash
nimble install nimdrake
```

With dev dependencies (tests, benchmarks, FFI regeneration):

```bash
nimble install nimdrake --parser:declarative --features:dev
```

### DuckDB native library

NimDrake needs `libduckdb.so` / `libduckdb.dylib` / `duckdb.dll`. The build
looks in two places, in order:

1. **Vendored** — `src/include/`, populate with `just fetch-lib`
2. **System** — `pkg-config duckdb` or `ldconfig`

---

## Quick start

```nim
import nimdrake

let db = newDatabase()       # in-memory
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

# Or iterate chunks with zero-copy column access
for chunk in r:
  let sq = chunk.vector(1).bindAs DuckType.BigInt
  echo sq[0]   # 1
```

---

## API

### Database and configuration

```nim
# In-memory
let db = newDatabase()

# Persistent file
let db = newDatabase("mydb.duckdb")

# With config
let cfg = newConfig({"threads": "4", "memory_limit": "2GB"}.toTable)
let db = newDatabase(cfg)
let con = db.connect()
```

### Query execution

```nim
# Materialised — all rows in memory
let r = con.execute("SELECT 1")

# Streaming — chunk by chunk (for large results)
let stmt = con.newStatement("SELECT i FROM generate_series(1, 1_000_000) AS t(i)")
for chunk in con.execute(stmt):
  let v = chunk.vector(0).bindAs DuckType.BigInt
  for x in v:
    discard
```

### Typed vector views

`Vector[kt]` is a zero-copy view over a DuckDB column's raw buffer.

```nim
let r = con.execute("SELECT 42::BIGINT AS answer, 'hello'::VARCHAR AS greeting")
for chunk in r:
  let answer   = chunk.vector(0).bindAs DuckType.BigInt
  let greeting = chunk.vector(1).bindAs DuckType.Varchar
  # or by name:
  # let answer = chunk["answer"].bindAs DuckType.BigInt
  for i in 0 ..< answer.len:
    echo answer[i], " — ", greeting[i]
```

### Prepared statements

```nim
con.execute("CREATE TABLE people (id BIGINT, name VARCHAR, active BOOLEAN)")
let stmt = con.newStatement("INSERT INTO people VALUES (?, ?, ?)")
con.executeMaterialized(stmt, (int64(1), "Alice", true))
con.executeMaterialized(stmt, (int64(2), "Bob", false))
echo con.execute("SELECT * FROM people ORDER BY id")
```

DML statements (`INSERT`, `UPDATE`, `DELETE`) don't produce streaming results.
Use `executeMaterialized` for these.

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

### Transactions

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

UDFs run Nim code inside DuckDB over its own columnar buffers. Useful when
per-row work is better expressed in Nim than SQL, without pulling every row
into Nim.

### Scalar (`registerScalar`)

```nim
proc multiply(a, b: int64): int64 = a * b

con.registerScalar(multiply)
let r = con.execute("SELECT multiply(3::BIGINT, 7::BIGINT)")
for chunk in r:
  echo chunk.vector(0).bindAs DuckType.BigInt  # 21
```

NULL propagation is automatic. Supported types: `bool`, `int8`–`int64`,
`uint8`–`uint64`, `float32`, `float64`, `string`, `seq[byte]`, `DateTime`,
`Time`, `TimeInterval`, `Int128`, `UInt128`, `Uuid`, `ZonedTime`.

### Table function (`registerTableFunction`)

```nim
iterator countToN(count: int): int {.closure.} =
  for i in 0 ..< count:
    yield i

con.registerTableFunction(countToN)
echo con.execute("SELECT * FROM countToN(5)")
```

Multi-column: yield named tuples. NULL: use `Option[T]` parameters/returns.

```nim
# Multi-column
iterator namedCols(n: int): tuple[idx: int, label: string] {.closure.} =
  for i in 0 ..< n:
    yield (idx: i, label: "row " & $i)

# NULL handling
iterator withNulls(n: int): Option[int] {.closure.} =
  for i in 0 ..< n:
    if i == 0: yield none(int)
    else: yield some(i)
```

Advanced options:

```nim
con.registerTableFunction(myIter, cardinality = 1000, exact = true)
con.registerTableFunction(myIter, named = true)      # named params (a := 1)
con.registerTableFunction(myIter, localInit = myInit) # per-thread init
```

### Aggregate (`registerAggregate`)

```nim
proc init(): int64 = 0
proc update(state, val: int64): int64 = state + val
proc finalize(state: int64): int64 = state

con.registerAggregate("sum_custom", init, update, finalize)
echo con.execute("SELECT sum_custom(i) FROM generate_series(1, 100) AS t(i)")
```

Auto-detects per-row (Tier A) vs vectorized (Tier B) from the update proc's
first parameter signature.

---

## Complex types

Complex columns (List, Array, Map, Struct, Union) are exposed via two
complementary layers:

### Typed container views — Nim-native, zero-copy construction

Pass the expected Nim container type to `bindAs` and get a typed view that
caches the bound child vector(s) once and dispatches row reads at compile
time. No per-call `mapEntriesChild` / `structChild(0)` / `structChild(1)`
chain.

```nim
let r = con.execute("""
  SELECT [1, 2, 3] AS xs,
         MAP(['a','b'], [10, 20]) AS mp,
         ARRAY[1, 2, 3]::INT[3] AS arr,
         {'a': 100, 'b': 'hello'} AS s,
         union_value(num := 42) AS u
""")

for chunk in r:
  # List
  let lv = chunk.vector(0).bindAs seq[int32]
  echo lv[0]                  # @[1, 2, 3]
  let slice = lv.borrowList(0)  # zero-copy SliceView, no seq allocation
  for x in slice: echo x

  # Map
  let mv = chunk.vector(1).bindAs OrderedTable[string, int32]
  echo mv[0]                  # {"a": 10, "b": 20}
  let row = mv.borrowMap(0)     # zero-copy MapRowView, no OrderedTable alloc
  echo row["a"]               # 10
  echo row.getOrDefault("z", -1)
  for k, v in row.pairs: echo k, " -> ", v

  # Array
  let av = chunk.vector(2).bindAsArray(DuckType.Integer)
  echo av[0]                  # @[1, 2, 3]
  for x in av.borrowArray(0): echo x

  # Struct — cached static-kind child overload (heterogeneous fields):
  let sv = chunk.vector(3).bindAs DuckType.Struct
  let a = sv.structChild(0, DuckType.Integer)
  let b = sv.structChild(1, DuckType.Varchar)
  echo a[0], " ", b[0]        # 100 hello

  # Struct element access via NimValue pairs:
  let pairs = sv[0]           # seq[(string, NimValue)]

  # Union
  let uv = chunk.vector(4).bindAs DuckType.Union
  echo uv[0]                  # ("num", NimValue(kind: nvInt, intVal: 42))
```

View types: `MapView[ktKey, ktVal]`, `MapRowView[ktKey, ktVal]`,
`ListView[kt]`, `ArrayView[kt]`, `SliceView[kt]`. Construction is zero-copy
(buffer pointers + chunk back-ref); `mv[i]` / `lv[i]` / `av[i]` allocate a
Nim container per row; the `borrow*` row views stay allocation-free by
reading straight out of the DuckDB buffer. NULL rows yield an empty
container.

### Zero-copy descent procs — low-level, type-erased

The lower-level descent procs (`listChild`, `arrayChild`, `structChild`,
`unionMemberChild`, `mapEntriesChild`, `mapKeyType`, `mapValueType`, …)
remain exported for type-erased introspection (e.g. via `complex.toNimValue`)
and are what the typed container views build on.

### Recursive materialisation via `NimValue`

```nim
let nv = r.scalar  # NimValue(kind: nvList, ...) — recursive, allocates per row
```

---

## Arrow export

Requires `features.nimdrake.arrow` and `narrow >= 0.0.1`:

```nim
let stmt = con.newStatement("SELECT * FROM generate_series(1, 100) AS t(i)")
let r = con.execute(stmt)
for batch in r.toArrowStream():
  echo batch.schema
  echo batch[0, int64].toSeq
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
| `List` | `bindAs(seq[T])` → `ListView`; `lv[i]` returns `seq[T]` |
| `Array` | `bindAsArray(kt)` → `ArrayView`; `av[i]` returns `seq[T]` |
| `Map` | `bindAs(Table[K,V])` / `bindAs(OrderedTable[K,V])` → `MapView`; `mv[i]` returns `OrderedTable[K,V]` |
| `Struct` | `structChild(j, kt)` / `structChild(name, kt)` → `Vector[kt]`; `sv[i]` returns `seq[(string, NimValue)]` |
| `Union` | `unionMemberChild(j, kt)` → `Vector[kt]`; `uv[i]` returns `(string, NimValue)` |

---

## Dependencies

**Production:**

```
nim >= 2.0.0
nint128
decimal >= 0.0.2
terminaltables >= 0.1.1
uuid4 >= 0.9.3
fusion >= 1.2
threading >= 0.2.1
```

**Dev:**

```
unittest2 >= 0.2.3
criterion >= 0.3.1
```

**Optional** (Arrow export):

```
narrow >= 0.0.1    # via feature "arrow"
```

**Native:** DuckDB C library v1.5.4 (vendored or system-installed).

---

## Development

Uses [just](https://github.com/casey/just) for build orchestration.

```bash
just test                     # all tests, debug + ASan
just test cores=8             # parallel
just test features="arrow"    # include Arrow tests
just cookbook                 # run cookbook snippets; fail if any break
just docs                     # render cookbook markdown to HTML
just fetch-lib                # vendor libduckdb.so + duckdb.h into src/include/
just generate                 # regenerate FFI from duckdb.h via Futhark
just clean                    # remove build artifacts
```

See [WORKBOARD.md](WORKBOARD.md) for project status and TODO list.

---

## Acknowledgements

- [DuckDB Julia](https://duckdb.org/docs/api/julia.html) — partial inspiration
- [Futhark](https://github.com/arnetheduck/nim-futhark) — FFI generation
- [nint128](https://github.com/cheatfate/nim-nint128), [decimal](https://github.com/ba0f3/decimal) — 128-bit and decimal types
- [terminaltables](https://github.com/ThomasTJdev/nim-terminaltables) — pretty-printing
- [uuid4](https://github.com/krux02/uuid4) — UUID support
