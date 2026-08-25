import nimib, nimibook
import ../cookbook_theme
import nimdrake
import std/strutils

type PeopleSource = ref object
  ids: seq[int64]
  names: seq[string]

proc columns(source: PeopleSource): seq[Column] =
  @[
    newColumn("id", newLogicalType(DuckType.BigInt), idx = 0),
    newColumn("name", newLogicalType(DuckType.Varchar), idx = 1),
  ]

proc cardinality(source: PeopleSource): Cardinality =
  knownCardinality(source.ids.len)

proc newFiller(source: PeopleSource): FillFn =
  doAssert source.ids.len == source.names.len
  var cursor = 0

  result = proc(chunk: duckdb_data_chunk): int {.closure, gcsafe.} =
    if cursor >= source.ids.len:
      return 0

    let rowCount = min(source.ids.len - cursor, VECTOR_SIZE)
    var idOutput = initVector[DuckType.BigInt](
      duckdb_data_chunk_get_vector(chunk, 0), rowCount)
    var nameOutput = initVector[DuckType.Varchar](
      duckdb_data_chunk_get_vector(chunk, 1), rowCount)

    for row in 0 ..< rowCount:
      idOutput[row] = source.ids[cursor + row]
      nameOutput[row] = source.names[cursor + row]

    cursor += rowCount
    rowCount

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
## Query In-Memory Nim Data

Expose a NimDrake result or a custom Nim data source as a DuckDB view. DuckDB
can then filter, join, aggregate, and project that data with SQL.

```nim
import nimdrake
```

This path is useful when data already exists in the process. It avoids a
temporary table and a separate insert step.

Registration creates a view in the current database. The view delegates each
scan to NimDrake's `nim_tbl_scan` table function.
"""

nbText: """
## Register a materialized result

Call `register` with a materialized `QResult`. Give the view an explicit name,
or let the macro use a simple variable name.
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let source = con.execute("""
      SELECT * FROM (VALUES
        (1::BIGINT, 'north', 20.5::DOUBLE),
        (2::BIGINT, 'south', 18.0::DOUBLE),
        (3::BIGINT, 'north', 22.0::DOUBLE)
      ) AS t(id, region, reading)
    """)

    con.register(source, name = "sensor_reading")

    echo con.execute("""
      SELECT region, avg(reading) AS mean_reading
      FROM sensor_reading
      GROUP BY region
      ORDER BY region
    """)

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
`register` takes ownership of the source. Treat the source variable as moved
after this call. Query the registered view instead of reading the old result.

The registered result is a snapshot. Later changes to the original tables do
not change the view contents.
"""

nbText: """
## Understand snapshot behavior

Registration stores the result chunks, not the SQL statement that produced
them. Re-running the view replays those chunks.
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE source_event (id BIGINT)")
    con.execute("INSERT INTO source_event VALUES (1), (2)")

    let firstRead = con.execute("SELECT id FROM source_event ORDER BY id")
    con.register(firstRead, name = "event_snapshot")

    con.execute("INSERT INTO source_event VALUES (3)")

    echo "table rows: ", con.execute(
      "SELECT count(*)::BIGINT FROM source_event").scalar(DuckType.BigInt)
    echo "snapshot rows: ", con.execute(
      "SELECT count(*)::BIGINT FROM event_snapshot").scalar(DuckType.BigInt)

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
Register the new query result again when the view needs a new snapshot. A
second registration with the same name replaces the view source.

Use a normal SQL view when the data must stay live inside DuckDB. Use a custom
`TableSource` when DuckDB must read live data owned by Nim.
"""

nbText: """
## Register a streaming result

`register` accepts a streaming result, but it consumes and materializes the
complete stream during registration. The registered view is therefore a
reusable snapshot.

Use a separate connection for the source query and the registration flow.
This arrangement avoids another operation on a connection with an active
stream.
"""

nbCode:
  block:
    let db = newDatabase()
    let sourceCon = db.connect()
    let queryCon = db.connect()

    let statement = sourceCon.newStatement("""
      SELECT i, i * i AS square
      FROM range(5) AS t(i)
    """)
    var stream = sourceCon.executeStreaming(statement)

    queryCon.register(move(stream), name = "square_snapshot")
    echo queryCon.execute("SELECT * FROM square_snapshot ORDER BY i")

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
This operation does not preserve streaming memory behavior. Materialize the
result explicitly when the application needs a visible allocation boundary.

Do not register an unbounded stream. The registration cannot finish until the
source stream finishes.
"""

nbText: """
## Know the supported column types

Registered scans support scalar, temporal, decimal, enum, UUID, bit, blob,
and large-integer columns. Nested `LIST`, `MAP`, `STRUCT`, `ARRAY`, and `UNION`
columns are not supported by this scan path.

Project nested values into supported columns before registration. For
example, select the required struct fields as separate columns.
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let flattened = con.execute("""
      SELECT item.id AS id, item.label AS label
      FROM (SELECT {'id': 7::BIGINT, 'label': 'ready'} AS item)
    """)
    con.register(flattened, name = "flat_item")
    echo con.execute("SELECT id, label FROM flat_item")

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
The failure occurs while DuckDB binds the registered view. Inspect
`TableScanSupportedKinds` when a generic adapter must reject unsupported
schemas before registration.
"""

nbText: """
## Implement a custom TableSource

A custom source must provide three procedures:

* `columns(source)` returns the result schema.
* `cardinality(source)` returns a row-count estimate.
* `newFiller(source)` returns a fresh chunk-filling closure.

The following source keeps data in two Nim sequences. Each query gets an
independent cursor because `newFiller` creates a new closure.

```nim
type PeopleSource = ref object
  ids: seq[int64]
  names: seq[string]

proc columns(source: PeopleSource): seq[Column] =
  @[
    newColumn("id", newLogicalType(DuckType.BigInt), idx = 0),
    newColumn("name", newLogicalType(DuckType.Varchar), idx = 1),
  ]

proc cardinality(source: PeopleSource): Cardinality =
  knownCardinality(source.ids.len)

proc newFiller(source: PeopleSource): FillFn =
  doAssert source.ids.len == source.names.len
  var cursor = 0

  result = proc(chunk: duckdb_data_chunk): int {.closure, gcsafe.} =
    if cursor >= source.ids.len:
      return 0

    let rowCount = min(source.ids.len - cursor, VECTOR_SIZE)
    var idOutput = initVector[DuckType.BigInt](
      duckdb_data_chunk_get_vector(chunk, 0), rowCount)
    var nameOutput = initVector[DuckType.Varchar](
      duckdb_data_chunk_get_vector(chunk, 1), rowCount)

    for row in 0 ..< rowCount:
      idOutput[row] = source.ids[cursor + row]
      nameOutput[row] = source.names[cursor + row]

    cursor += rowCount
    rowCount
```

Define these procedures at module scope. The `TableSource` generic resolves
them when `register` is instantiated.
"""

nbCode:
  block:

    let people = PeopleSource(
      ids: @[1'i64, 2'i64, 3'i64],
      names: @["Ada", "Linus", "Grace"],
    )

    let con = newDatabase().connect()
    con.register(people, name = "nim_people")
    echo con.execute("""
      SELECT id, upper(name) AS name
      FROM nim_people
      WHERE id >= 2
      ORDER BY id
    """)

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
The filler must write no more than `VECTOR_SIZE` rows. Return zero when the
scan is complete. Return the number of rows written for every other call.

Create a new cursor inside `newFiller`. A cursor stored on the source object
breaks repeated scans and concurrent queries.

The filler runs on a DuckDB worker thread. Its captured state must be safe for
that thread. Do not access thread-local application state from the closure.
"""

nbText: """
## Keep schema and data stable

DuckDB reads the schema and cardinality during registration. It calls
`newFiller` for each later scan.

This timing can expose stale metadata when mutable source data changes. Treat
the source as immutable after registration, or register it again after each
schema or row-count change.

The generic `TableSource` adapter fills the complete source schema when a
query selects fewer columns. For wide sources, implement a table function
directly when projection pushdown is required.
"""

nbText: """
## Choose between the in-memory paths

| Requirement | Use |
| --- | --- |
| Reuse a finite query result | Register a materialized `QResult` |
| Convert a finite stream into a reusable view | Register a streaming `QResult` |
| Read live Nim-owned data | Implement `TableSource` |
| Accept SQL arguments | Register a table function |
| Persist data after process exit | Insert into a DuckDB table |

A registered source exists only while its database exists. It does not make
the Nim data persistent, even when the database itself uses a file.
"""

nbSave
