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
## Errors and Troubleshooting

Identify whether an error comes from DuckDB, NimDrake validation, or native
library loading. Preserve the original message because DuckDB includes SQL
locations and binder details.

## Error types

| Error | Typical cause | First action |
| --- | --- | --- |
| `OperationError` | DuckDB rejected an operation | Read the complete message |
| `ValueError` | A Nim type or result shape does not match | Inspect result metadata |
| `KeyError` | A named result column does not exist | Inspect `result.columns` |
| Linker error | `libduckdb` was not found at build time | Inspect library paths |
| Loader error | The native library was not found at run time | Inspect the executable rpath |

Catch an error only where the application can add context, retry, or select a
different action. Do not replace the native message with a generic message.
"""

nbText: """
## Preserve DuckDB error details

`OperationError` covers SQL parser, binder, catalog, conversion, transaction,
and appender failures.
"""

nbCode:
  block:
    let con = newDatabase().connect()
    try:
      discard con.execute("SELECT missing_column FROM missing_table")
    except OperationError as error:
      echo "query failed: ", error.msg

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
Add operation context before you propagate the error. Do not include bound
secrets or complete user records in logs.

Parser errors usually identify invalid SQL syntax. Binder errors usually
identify missing names or incompatible types. Catalog errors identify missing
database objects.
"""

nbText: """
## Diagnose a vector type mismatch

`bindAs` checks the requested `DuckType` against result metadata. It does not
convert the column.
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let result = con.execute("SELECT 42::INTEGER AS answer")

    echo "actual kind: ", result.columnKind(0)
    for chunk in result:
      try:
        discard chunk.bindAs(0, DuckType.BigInt)
      except ValueError as error:
        echo error.msg

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
Change the SQL cast or change the static kind in `bindAs`. Do not cast the
returned pointer to a different Nim integer type.

Use explicit SQL casts at stable application boundaries. DuckDB can otherwise
infer a wider type after an expression or aggregate changes.
"""

nbText: """
## Diagnose object mapping failures

Object mapping matches column names without regard to letter case. A required
field must exist and must contain a compatible non-NULL value.

Use `Option[T]` when a column can be NULL or absent. Do not use an optional
field to hide a spelling error in a required query column.

Print `result.columns` before decoding when a generated query changes its
projection.
"""

nbText: """
## Diagnose native library errors

A build-time message such as `cannot find -lduckdb` means that the linker did
not find the native library. Run `just fetch-lib` in a source checkout, or
install DuckDB in a path that `pkg-config` reports.

A run-time message about a missing shared library means that linking finished,
but the operating-system loader cannot open the library. Inspect the binary's
rpath and the package `src/include` directory.

An `undefined symbol` message usually means that the library is older than the
checked-in bindings. Replace the header and library as one matched pair.
"""

nbText: """
## Diagnose an active streaming query

A streaming result keeps query execution active until iteration finishes or
the result is destroyed. Do not start an unrelated operation on the same
connection during that interval.

Use one of these corrections:

* Finish the stream before the next operation.
* Materialize the result with `execute`.
* Open another connection from the same `Database`.

A streaming result supports one sequential pass. Materialize it when the
application needs repeated iteration.
"""

nbText: """
## Diagnose appender row errors

An appender validates a row when `endRow` runs. Too few or too many appended
columns therefore fail at the row boundary.

Keep every row append in one small procedure. Append fields in table-column
order. Use `newTableDescription` when an adapter must inspect an external
table before loading.

Always call `close` after successful input. Closing flushes pending appender
state and reports native errors that did not surface earlier.
"""

nbText: """
## Use a bounded diagnostic sequence

When a query fails, use this sequence:

1. Save the complete exception type and message.
2. Run the smallest SQL statement that still fails.
3. Print result or table metadata.
4. Replace inferred SQL types with explicit casts.
5. Reproduce the operation on one connection.
6. Add streaming, threads, or custom callbacks one at a time.

This sequence separates SQL behavior from wrapper ownership and concurrency
behavior.
"""

nbSave
