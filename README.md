<div align="center">
  <picture>
    <source media="(prefers-color-scheme: light)" srcset="drake-svg-light-theme.svg">
    <source media="(prefers-color-scheme: dark)" srcset="drake-svg-dark-theme.svg">
    <img alt="NimDrake logo" src="drake-svg-light-theme.svg" height="200">
  </picture>
  <br>
  <a href="https://github.com/BontaVlad/NimDrake/actions/workflows/tests.yml">
    <img src="https://github.com/BontaVlad/NimDrake/actions/workflows/tests.yml/badge.svg" alt="Tests">
  </a>
  <img src="https://img.shields.io/badge/status-pre--alpha-blue" alt="Status: pre-alpha">
</div>

# NimDrake

NimDrake is a [Nim](https://nim-lang.org/) binding for
[DuckDB](https://duckdb.org/), an in-process analytical SQL database.

It provides high-level SQL execution and low-level typed access to DuckDB
result chunks. Primitive columns can be read through zero-copy views over
DuckDB's columnar buffers.

- **Target versions:** DuckDB v1.5.4 and Nim `>= 2.0.0`
- **License:** MIT
- **Status:** pre-alpha; APIs and behavior can change

**Documentation:** [API reference](https://bontavlad.github.io/NimDrake/theindex.html) | [Cookbook](https://bontavlad.github.io/NimDrake/cookbook/cookbook.html) | [Docs home](https://bontavlad.github.io/NimDrake/)

## Features

- **High-level SQL API** for database connections, query execution, prepared
  statements, transactions, and bulk inserts.
- **Streaming results** that consume one DuckDB data chunk at a time.
- **Typed column views** through `Vector[kt]`, with zero-copy reads for
  primitive columns.
- **Nested type support** for List, Array, Map, Struct, Union, Decimal, UUID,
  and 128-bit integers.
- **User-defined functions** that register Nim procs, closure iterators, and
  aggregate callbacks with DuckDB.
- **Compile-time query DSL** for generating prepared SQL from Nim syntax.
- **Optional Arrow and Arraymancer integrations** for exporting results and
  scanning Nim tensors as DuckDB views.

## Installation

Install the package with Nimble:

```bash
nimble install nimdrake
```

Install the development dependencies when you need to run tests or build the
cookbook:

```bash
nimble install nimdrake --parser:declarative --features:dev
```

### DuckDB native library

NimDrake needs the DuckDB native library and C header. The package installation
task downloads the matching DuckDB release archive and verifies its SHA-256
checksum for supported platforms:

- Linux amd64 and arm64
- macOS universal builds
- Windows amd64 and arm64

When building from source, NimDrake first uses the library under
`src/include/`. If it is not present, it searches for a system installation
through `pkg-config` and platform-specific library paths.

To vendor the library manually, run:

```bash
just fetch-lib
```

### Optional Arrow support

Install the Arrow feature with:

```bash
nimble install nimdrake --parser:declarative --features:arrow
```

Arrow support uses [`narrow`](https://github.com/BontaVlad/narrow). Install the
Arrow GLib development libraries before compiling a project with this feature:

- `arrow-glib`
- `arrow-dataset-glib`
- `parquet-glib`

The libraries must be discoverable through `pkg-config`.

### Optional Arraymancer support

The `tensor` feature adds `registerTensor`, which exposes an Arraymancer tensor
as a scanable DuckDB view:

```bash
nimble install nimdrake --parser:declarative --features:tensor
```

This feature requires the `arraymancer` package.

## Quick start

```nim
import nimdrake

let db = newDatabase()       # in-memory database
let con = db.connect()

let result = con.execute("""
  SELECT i, i * i AS square
  FROM generate_series(1, 5) AS t(i)
""")

echo result
```

The result can also be read as typed column views:

```nim
for chunk in result:
  let square = chunk.vector(1).bindAs DuckType.BigInt
  echo square[0]
```

## Core usage

### Database and configuration

```nim
# In-memory database
let memoryDb = newDatabase()

# Persistent database file
let fileDb = newDatabase("mydb.duckdb")

# Database configuration
let cfg = newConfig({"threads": "4", "memory_limit": "2GB"}.toTable)
let configuredDb = newDatabase(cfg)
let con = configuredDb.connect()
```

### Streaming results

Use streaming execution for large result sets. DuckDB produces one chunk at a
time instead of materializing the complete result in Nim.

```nim
let stmt = con.newStatement(
  "SELECT i FROM generate_series(1, 1_000_000) AS t(i)")

var count = 0
for chunk in con.executeStreaming(stmt):
  let values = chunk.vector(0).bindAs DuckType.BigInt
  count += values.len

echo count
```

### Prepared statements

Bind Nim tuples to prepared statement parameters:

```nim
con.execute("CREATE TABLE people (id BIGINT, name VARCHAR, active BOOLEAN)")
let stmt = con.newStatement("INSERT INTO people VALUES (?, ?, ?)")

con.executeMaterialized(stmt, (int64(1), "Alice", true))
con.executeMaterialized(stmt, (int64(2), "Bob", false))

echo con.execute("SELECT * FROM people ORDER BY id")
```

Use `executeMaterialized` for `INSERT`, `UPDATE`, and `DELETE` statements.
DuckDB does not return streaming results for these statements.

### Bulk inserts

Use an appender when inserting many rows:

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

The `transaction` template commits when the block finishes. If the block raises
an exception, the transaction rolls back.

```nim
con.transaction:
  con.execute("INSERT INTO people VALUES (999, 'inside', true)")
```

### Cross-chunk access

`Table` combines a materialized result into one random-access view. Global row
lookups search the result's chunk offsets with binary search.

```nim
let result = con.execute(
  "SELECT i FROM generate_series(1, 5000) AS t(i)")
let table = initTable(result)
let values = table.bindAs(0, DuckType.BigInt)

echo values[4999]
```

## User-defined functions

Register an ordinary Nim proc as a DuckDB scalar function:

```nim
proc multiply(a, b: int64): int64 = a * b

con.registerScalar(multiply)
echo con.execute("SELECT multiply(3::BIGINT, 7::BIGINT)")
```

Register a closure iterator as a table function:

```nim
iterator countToN(count: int): int {.closure.} =
  for i in 0 ..< count:
    yield i

con.registerTableFunction(countToN)
echo con.execute("SELECT * FROM countToN(5)")
```

Use named tuples for table functions with multiple output columns. Use
`Option[T]` parameters or return values for nullable values. See the
[user-defined functions cookbook](https://bontavlad.github.io/NimDrake/cookbook/user_defined_functions.html)
for more examples.

## Query DSL

The `nimdrake/dsl/queries` module provides a `query(con):` macro that generates
prepared SQL from a Nim-looking block:

```nim
import nimdrake/dsl/queries

con.execute("CREATE TABLE customer (id INTEGER, name VARCHAR)")
con.execute("CREATE TABLE orders (id INTEGER, customer_id INTEGER, amount DOUBLE)")

let result = query(con):
  select customer(name, t2.amount)
  join orders() on t1.id == t2.customer_id
  where t1.id == ?(1)
```

The [query execution cookbook](https://bontavlad.github.io/NimDrake/cookbook/query_execution.html)
documents inserts, updates, deletes, grouping, joins, parameters, and raw SQL
splices.

## Complex types and type support

`DuckType` mirrors DuckDB's type enum. NimDrake provides direct mappings for
common scalar types, including booleans, signed and unsigned integers, floats,
strings, blobs, timestamps, intervals, UUIDs, decimals, and 128-bit integers.

Nested values use typed views:

```nim
let result = con.execute("SELECT [1, 2, 3] AS values")

for chunk in result:
  let values = chunk.vector(0).bindAs seq[int32]
  echo values[0]

  let borrowed = values.borrowList(0)
  for value in borrowed:
    echo value
```

`bindAs(seq[T])`, `bindAs(Table[K, V])`, and `bindAsArray(kt)` create typed
views for List, Map, and Array columns. Struct and Union columns expose child
vectors through `structChild` and `unionMemberChild`.

The views keep access to DuckDB's result buffers. Reading a complete row into a
Nim container allocates that container; `borrowList`, `borrowMap`, and
`borrowArray` provide allocation-free row views.

See the [complex types cookbook](https://bontavlad.github.io/NimDrake/cookbook/complex_types.html)
and the [API reference](https://bontavlad.github.io/NimDrake/theindex.html) for
the complete type and operation mapping.

## Arrow export

With the `arrow` feature enabled, stream results as Arrow record batches:

```nim
let stmt = con.newStatement(
  "SELECT * FROM generate_series(1, 100) AS t(i)")
let result = con.executeStreaming(stmt)

for batch in result.toArrowStream():
  echo batch.schema
```

See [Optional Arrow support](#optional-arrow-support) for installation
requirements.

## Documentation

- [Docs home](https://bontavlad.github.io/NimDrake/) — overview and short examples
- [Cookbook](https://bontavlad.github.io/NimDrake/cookbook/cookbook.html) — task-oriented recipes
- [API reference](https://bontavlad.github.io/NimDrake/theindex.html) — generated documentation for exported symbols

## Development

NimDrake uses [just](https://github.com/casey/just) for build commands.

```bash
just test                         # debug tests with sanitizers where supported
just test 8                       # run tests in parallel
just test --features=arrow        # include Arrow tests
just test --durations=10          # show the slowest tests
just cookbook                     # build and execute every cookbook snippet
just checkdocs                    # check exported doc-comment coverage
just fetch-lib                    # vendor DuckDB into src/include/
just generate                     # regenerate FFI bindings with Futhark
just clean                        # remove build artifacts
```

`just generate` requires Futhark. Install it with:

```bash
nimble install -y futhark
```

The cookbook requires Nimibook and, on Linux, PCRE1. Install the cookbook
dependency with `nimble install -y nimibook`. On Ubuntu, install PCRE1 with:

```bash
sudo apt install libpcre3
```

Every cookbook snippet is compiled and executed while the book is built. A
broken recipe therefore fails `just cookbook`.

## License

NimDrake is released under the [MIT License](LICENSE).

## Acknowledgements

- [DuckDB Julia](https://duckdb.org/docs/api/julia.html) — partial inspiration
- [Futhark](https://github.com/arnetheduck/nim-futhark) — FFI generation
- [nint128](https://github.com/cheatfate/nim-nint128) and
  [decimal](https://github.com/ba0f3/decimal) — integer and decimal types
- [terminaltables](https://github.com/ThomasTJdev/nim-terminaltables) — table display
- [uuid4](https://github.com/krux02/uuid4) — UUID support
