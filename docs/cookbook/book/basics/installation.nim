import nimib, nimibook
import ../cookbook_theme
import nimdrake
import std/strutils

nbInit(theme = useCookbook)

proc stripBlockCode(code: string): string =
  let lines = code.splitLines()
  if lines.len == 0 or lines[0].strip != "block:":
    return code
  var outLines: seq[string]
  for i in 1 ..< lines.len:
    var line = lines[i]
    if line.startsWith("  "):
      line = line[2 .. ^1]
    outLines.add line
  outLines.join("\n")

nbText: """
## Installation and First Query

Install NimDrake, make the native DuckDB library available, and run a small
query. NimDrake requires Nim 2.0 or later.

## Install the package

Install the default feature set with Nimble:

```bash
nimble install nimdrake
```

The install task downloads the supported DuckDB release for the current
platform. It checks the archive with a fixed SHA-256 digest before extraction.

The automatic download supports these targets:

* Linux on amd64 or arm64
* macOS universal
* Windows on amd64 or arm64

NimDrake stores the library and `duckdb.h` below its `src/include` directory.
The FFI module adds this directory to the linker and runtime search paths.
"""

nbText: """
## Use a system DuckDB library

You can use a system installation instead of the downloaded library. The
build searches `pkg-config` and standard platform library locations.

The C header and native library must come from compatible DuckDB releases.
An old library can link successfully but lack a symbol that the wrapper uses.

When you work from a NimDrake source checkout, run this command to download
the pinned library:

```bash
just fetch-lib
```

Do not copy an unrelated `libduckdb` into `src/include`. The checked-in C
bindings match the DuckDB version declared in `nimdrake.nimble`.
"""

nbText: """
## Run a smoke query

Keep the `Database` in a variable when the application will create more than
one connection. A connection also keeps its database alive.
"""

nbCode:
  block:
    let db = newDatabase()
    let con = db.connect()

    let result = con.execute("""
      SELECT i, i * i AS square
      FROM range(1, 6) AS t(i)
      ORDER BY i
    """)

    echo result

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
Compile the application with its normal Nim command:

```bash
nim c -r app.nim
```

The first successful query confirms these parts:

1. Nim can find the `nimdrake` package.
2. The linker can find the DuckDB library.
3. The runtime loader can open that library.
4. The wrapper and library can execute a query.
"""

nbText: """
## Install optional features

Use Nimble's declarative parser when you select a feature:

```bash
nimble install nimdrake --parser:declarative --features:arrow
nimble install nimdrake --parser:declarative --features:tensor
```

The Arrow feature also requires `arrow-glib`, `arrow-dataset-glib`, and
`parquet-glib`. `pkg-config` must find all three libraries.

The tensor feature installs Arraymancer and adds `registerTensor`. Do not
enable optional features that the application does not use. Each feature adds
compile-time and native dependency requirements.
"""

nbText: """
## Build the cookbook and tests

Install the development feature when you work on NimDrake itself:

```bash
nimble install nimdrake --parser:declarative --features:dev
just test
just cookbook
```

The cookbook build compiles and runs each executable example. A successful
HTML render alone is not sufficient because code output is part of the book.
"""

nbSave
