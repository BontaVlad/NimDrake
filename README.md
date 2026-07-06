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

## NimDrake

NimDrake is a [Nim](https://nim-lang.org/) language package designed to integrate with [DuckDB](https://duckdb.org/), an in-process SQL OLAP database management system. It simplifies database interactions while maintaining flexibility for advanced use cases. NimDrake is built with two ideas in mind, the high-level interface offers quick and easy database operations, ideal for rapid development and simplicity,
and a lower-level interface that directly interacts with DuckDB's core functionalities, enabling complex or high-performance implementations when necessary.
This dual-layer approach ensures that NimDrake caters to both beginners and advanced users.

**Please note:** NimDrake is currently in a pre-alpha stage and is considered experimental. It contains bugs and lacks some intended features. Use with caution and report any issues you encounter.

---

## Installation

NimDrake is a [nimble](https://github.com/nim-lang/nimble) package. It uses
nimble's **feature sets** to keep dev-only dependencies (`futhark`,
`criterion`, `unittest2`) out of the default install. Those deps are grouped
under the built-in `dev` feature and are pulled in only when you opt in.

### From the package registry (production)

```bash
nimble install nimdrake
```

This installs only the production dependencies (`nint128`, `decimal`,
`terminaltables`, `uuid4`, `fusion`).

### With development dependencies

Tests, benchmarks, and wrapper regeneration (via `-d:useFuthark`) need the
extra dev dependencies. Activate them with the declarative parser and the
`dev` feature set:

```bash
nimble install nimdrake --parser:declarative --features:dev
```

> **Note:** The `dev:` block is ignored by nimble's default `nimvm` parser, so
> the `--parser:declarative` flag is required for `--features:dev` to take
> effect. With the declarative parser active, source files can also gate on
> `when defined(features.nimdrake.dev)`.

### From source (manual)

1. Clone the repository:
   ```bash
   git clone https://github.com/BontaVlad/NimDrake
   cd NimDrake
   ```

2. Install with nimble (add `--parser:declarative --features:dev` for dev deps):
   ```bash
   nimble install
   ```


### DuckDB dependency

NimDrake requires DuckDB v1.5.4. The build resolves the library in three
tiers, tried in order:

1. **Vendored** under `src/include/` (`libduckdb.so` on Linux, `libduckdb.dylib`
   on macOS, `duckdb.dll` on Windows). Populate it with:
   ```bash
   just fetch-lib        # linux amd64; other platforms: see justfile
   ```
2. **System-installed** libduckdb, discovered via `pkg-config --exists duckdb`
   or `ldconfig -p`. Install via your distro's package manager or Homebrew.
3. **Error** — if neither is present, `nim c` fails with a message listing both
   options above.

The vendored path is preferred for reproducible builds; the system path is the
fallback for users who already have DuckDB installed. Futhark binding
regeneration (`-d:useFuthark`) searches `src/include/duckdb.h` first, then
`/usr/local/include` and `/usr/include`.

## Full Documentation
For a full documentation and API index go [here](http://bontavlad.com/NimDrake/)

## Code Examples

Here are a few simple examples of how to use this repository:

### Example 1: Simple query
```nim
import nimdrake

let duck = newDatabase().connect()

echo duck.execute("SELECT * FROM range(100) AS example;")

# Environment Variables for Controlling Dataframe Display Options
# - **display_show_index** (True/False): Determines whether to show or hide row index columns. Set `True` to display indexes, `False` to hide them.  
# - **display_max_rows**: Specifies the maximum number of rows displayed in a dataframe output.
# - **display_max_columns** (Default 100): Restricts the maximum number of columns to be shown at once to prevent overwhelming displays; set to `100` as default.
# - **display_clip_column_name**: Limits the length of column names displayed, which can help in keeping outputs clean when dealing with long-named columns. Set it to `20`.

# output:
# ┌───────┬───────────────┐
# │  #    │     range     │
# ├───────┼───────────────┤
# │  0    │     0         │
# │  1    │     1         │
# │  2    │     2         │
# │  3    │     3         │
# │  4    │     4         │
# │  ...  │     ...       │
# │  95   │     95        │
# │  96   │     96        │
# │  97   │     97        │
# │  98   │     98        │
# │  99   │     99        │
# └───────┴───────────────┘

```

### Example 2: Access query results using the Vector Interface.
```nim
let duck = newDatabase().connect()

let outcome = duck.execute(""" SELECT seq AS int_col, 'Value_' || seq::VARCHAR AS varchar_col FROM generate_series(1,3) AS t(seq) """).fetchAll()
echo outcome[0].valueBigint # -> @[1, 2, 3]
echo outcome[1].valueVarchar # -> @["Value_1", "Value_2", "Value_3"]

# we can also access by column name

let outcome = duck.execute(""" SELECT seq AS int_col, 'Value_' || seq::VARCHAR AS varchar_col FROM generate_series(1,3) AS t(seq) """).fetchAllNamed()
echo outcome["int_col"].valueBigint # -> @[1, 2, 3]
echo outcome["varchar_col"].valueVarchar # -> @["Value_1", "Value_2", "Value_3"]

```

### Example 3: Using the row iterator interface
```nim
let duck = newDatabase().connect()

let task = duck.execute(""" SELECT seq AS int_col, 'Value_' || seq::VARCHAR AS varchar_col FROM generate_series(1,3) AS t(seq) """)
for i, row in enumerate(task.rows):
  echo fmt"row {i}: ({row[0]}, {row[1]})"
  
#output:
# row 0: (1, Value_1)
# row 1: (2, Value_2)
# row 2: (3, Value_3)
```

### Example 4: Using the dataframe
```nim
let 
  # we can also start a session with custom config flags
  config = newConfig({"threads": "3"}.toTable)
  duck = newDatabase().connect(config)

let df = newDataFrame(
  {
    "foo": newVector(@[10, 30, 20]),
    "bar": newVector(@["a", "b", "c"])
  }.toTable)
duck.register("df", df)
echo duck.execute("SELECT * FROM df ORDER BY foo;")
  
#output:
# ┌─────┬─────────────┬─────────────┐
# │  #  │     bar     │     foo     │
# ├─────┼─────────────┼─────────────┤
# │  0  │     a       │     10      │
# │  1  │     c       │     20      │
# │  2  │     b       │     30      │
# └─────┴─────────────┴─────────────┘
```

### Example 5: Insert with prepared statement

```nim
let duck = newDatabase().connect()
duck.execute(
    """
    CREATE TABLE prepared_table (
        bool_val BOOLEAN,
        int32_val INTEGER,
        float64_val DOUBLE,
        string_val VARCHAR,
    );
    """
)

let prepared = duck.newStatement("INSERT INTO prepared_table VALUES (?, ?, ?, ?);")
duck.execute(prepared, (true, -2147483648'i32, 3.14159265359'f64, "hello"))
echo duck.execute("SELECT * FROM prepared_table;")

# output:
# ┌─────┬──────────────────┬────────────────────┬─────────────────────┬───────────────────────┐
# │  #  │     bool_val     │     string_val     │     int32_val       │     float64_val       │
# ├─────┼──────────────────┼────────────────────┼─────────────────────┼───────────────────────┤
# │  0  │     true         │     hello          │     -2147483648     │     3.14159265359     │
# └─────┴──────────────────┴────────────────────┴─────────────────────┴───────────────────────┘

```

### Example 6: Using UDF(user defined functions)

```nim
let duck = newDatabase().connect()

template powerTo(val, bar: int64): int64 {.scalar.} =
  result = val * bar

duck.register(powerTo)

duck.execute("CREATE TABLE test_table AS SELECT i FROM range(3, 9) t(i);")
echo duck.execute("SELECT i, powerTo(i, i) as powerTo FROM test_table")

# output:
# ┌─────┬─────────────────┬───────────┐
# │  #  │     powerTo     │     i     │
# ├─────┼─────────────────┼───────────┤
# │  0  │     9           │     3     │
# │  1  │     16          │     4     │
# │  2  │     25          │     5     │
# │  3  │     36          │     6     │
# │  4  │     49          │     7     │
# │  5  │     64          │     8     │
# └─────┴─────────────────┴───────────┘
```

### Example 7: Using UDF as table generators

```nim

let duck = newDatabase().connect()

iterator countToN(count: int): int {.producer, closure.} =
    for i in 0 ..< count:
      yield i

iterator progress(count: int, sigil: string): string {.producer, closure.} =
    var output = ""
    for _ in 0 ..< count:
      output &= sigil
      yield output

iterator floatCounter(): float {.producer, closure.} =
    var counter = 0.0
    while true:
      yield counter
      counter += 1.0

duck.register(floatCounter)

duck.register(progress)

duck.register(countToN)

echo duck.execute("SELECT * FROM countToN(3)")
echo duck.execute("SELECT * FROM progress(5, '#')")
echo duck.execute("SELECT * FROM floatCounter() LIMIT 5;")

# output:
# ┌─────┬──────────────────┐
# │  #  │     countToN     │
# ├─────┼──────────────────┤
# │  0  │     0            │
# │  1  │     1            │
# │  2  │     2            │
# └─────┴──────────────────┘
# 
# ┌─────┬──────────────────┐
# │  #  │     progress     │
# ├─────┼──────────────────┤
# │  0  │     #            │
# │  1  │     ##           │
# │  2  │     ###          │
# │  3  │     ####         │
# │  4  │     #####        │
# └─────┴──────────────────┘
# 
# ┌─────┬──────────────────────┐
# │  #  │     floatCounter     │
# ├─────┼──────────────────────┤
# │  0  │     0.0              │
# │  1  │     1.0              │
# │  2  │     2.0              │
# │  3  │     3.0              │
# │  4  │     4.0              │
# └─────┴──────────────────────┘
```
## DuckDB to Nim Type Mapping

| **DuckType**         | **Nim Equivalent**           |
|-----------------------|------------------------------|
| `Invalid`            | `uint8`                     |
| `ANY`                | `uint8`                     |
| `VARINT`             | `uint8`                     |
| `SQLNULL`            | `uint8`                     |
| `Boolean`            | `bool`                      |
| `TinyInt`            | `int8`                      |
| `SmallInt`           | `int16`                     |
| `Integer`            | `int32`                     |
| `BigInt`             | `int64`                     |
| `UTinyInt`           | `uint8`                     |
| `USmallInt`          | `uint16`                    |
| `UInteger`           | `uint32`                    |
| `UBigInt`            | `uint64`                    |
| `Float`              | `float32`                   |
| `Double`             | `float64`                   |
| `Timestamp`          | `DateTime`                  |
| `Date`               | `DateTime`                  |
| `Time`               | `Time`                      |
| `Interval`           | `TimeInterval`              |
| `HugeInt`            | `Int128`                    |
| `Varchar`            | `string`                    |
| `Blob`               | `seq[byte]`                 |
| `Decimal`            | `DecimalType`               |
| `TimestampS`         | `DateTime`                  |
| `TimestampMs`        | `DateTime`                  |
| `TimestampNs`        | `DateTime`                  |
| `Enum`               | `uint`                      |
| `List`               | `seq[Value]`                |
| `Struct`             | `Table[string, Value]`      |
| `Map`                | `Table[string, Value]`      |
| `UUID`               | `Uuid`                      |
| `Union`              | `Table[string, Value]`      |
| `Bit`                | `string`                    |
| `TimeTz`             | `ZonedTime`                 |

---

## Contribution

NimDrake uses [just](https://github.com/casey/just) for build orchestration.
Key commands:

- `just test` — compile and run all tests with AddressSanitizer (sequential)
- `just test isParallel=true cores=4` — run tests in parallel
- `just test-arrow` — run Arrow/narrow tests (requires `-d:features.nimdrake.arrow`)
- `just coverage` — generate lcov coverage report
- `just benchmark` — run performance benchmarks
- `just format src` — format all Nim files in `src/` with `nph`
- `just generate` — regenerate FFI bindings from `duckdb.h` using futhark
- `just debug nim_file="tests/test_query.nim"` — compile with full debug info
- `just valgrind nim_file="..."` — run under Valgrind

The project uses `config.nims` for compiler switches (linker flags, sanitizer
options, Int128 support detection). Tests use `unittest2` and run with
`--mm:orc -d:useMalloc -fsanitize=address`.

See [WORKBOARD.md](WORKBOARD.md) for the current project status and TODO list.

---

## Acknowledgments

# Acknowledgements

This project relies on several Nim packages:

- [Nim](https://nim-lang.org/) (version 2.0.0 or higher)
- [futhark](https://github.com/arnetheduck/nim-futhark)
- [nint128](https://github.com/cheatfate/nim-nint128)
- [decimal](https://github.com/ba0f3/decimal) (version 0.0.2 or higher)
- [terminaltables](https://github.com/ThomasTJdev/nim-terminaltables) (version 0.1.1 or higher)
- [uuid4](https://github.com/krux02/uuid4) (version 0.9.3 or higher)

A special thanks to:

- A lot of code ported from [Duckdb Julia](https://duckdb.org/docs/api/julia.html)
- Futhark was a life saver

Feel free to fork, contribute, and share this repository. 

---
