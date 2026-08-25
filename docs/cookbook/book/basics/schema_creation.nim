import nimib, nimibook
import ../cookbook_theme
import nimdrake
import std/[options, strutils]

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
## Schema Creation and Inspection

Create DuckDB tables and named types from Nim types. Inspect existing tables
before you read or update them.

```nim
import nimdrake
import std/options
```

NimDrake can generate simple DDL from Nim objects. This is useful for local
schemas and small applications. Use explicit SQL migrations when schema
changes need versioning, data conversion, or coordinated deployment.
"""

nbText: """
## Create a table from an object

`createTable` creates one column for each object field. The field order in the
object becomes the table column order.

Use fixed-width Nim integers when the SQL width is part of the schema. For
example, `int32` maps to `INTEGER`, and `int64` maps to `BIGINT`.

`Option[T]` uses the same SQL type as `T`. It changes row decoding and value
binding, but it does not add a `NOT NULL` constraint.
"""

nbCode:
  block:
    type Account = object
      id: int64
      email: string
      quota: Option[int32]

    let con = newDatabase().connect()
    con.createTable("account", Account)
    con.execute("""
      INSERT INTO account VALUES
        (1, 'ada@example.test', 10),
        (2, 'linus@example.test', NULL)
    """)

    for account in con.execute(
        "SELECT id, email, quota FROM account ORDER BY id").rows(Account):
      echo account.id, " ", account.email,
        " quota_present=", account.quota.isSome

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
`createTable` does not add keys, indexes, checks, or generated columns. Write
the DDL directly when the table needs these rules.

CAUTION: Use `orReplace = true` only when data loss is acceptable. DuckDB
replaces the existing table and its data.
"""

nbText: """
## Inspect the generated SQL type

Use `sqlTypeFor(T)` when generated DDL needs the mapped SQL type. Objects and
tuples become `STRUCT` types. Sequences become `LIST` types.

Use `logicalTypeFor(T)` when an extension callback needs a DuckDB
`LogicalType` handle instead of SQL text.
"""

nbCode:
  block:
    type Point = object
      x: float64
      y: float64

    echo sqlTypeFor(int32)       # INTEGER
    echo sqlTypeFor(seq[int64])  # BIGINT[]
    echo sqlTypeFor(Point)       # STRUCT("x" DOUBLE, "y" DOUBLE)

    let pointType = logicalTypeFor(Point)
    echo pointType.toDuckType

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
## Create a named enum

A Nim enum can define a persistent DuckDB enum. NimDrake uses the text from
`$value` as each SQL label.

Create the named type before you use it in table DDL. Decode the SQL enum into
the same Nim enum to keep labels and ordinals aligned.
"""

nbCode:
  block:
    type JobState = enum
      queued
      running
      complete

    type Job = object
      id: int64
      state: JobState

    let con = newDatabase().connect()
    discard con.createType(JobState, "job_state")
    con.execute("CREATE TABLE job (id BIGINT, state job_state)")
    con.execute("INSERT INTO job VALUES (1, 'queued'), (2, 'complete')")

    let jobs = con.execute(
      "SELECT id, state FROM job ORDER BY id").toSeq(Job)
    echo jobs[0].state
    echo jobs[1].state

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
The declaration order controls the enum ordinal. Reordering a Nim enum can
change decoded values when the database keeps the old label order.

Treat a persistent enum as a migration-managed type. Add and rename labels
with explicit migration SQL. Keep the application enum synchronized with the
database type.
"""

nbText: """
## Create aliases and unions

Use `createAliasType` for a named alias of a SQL type. Use `createUnionType`
for a DuckDB union.

Both helpers accept SQL type fragments. They do not parse or quote these
fragments. Pass only constants that the application controls.

`union_tag` returns a DuckDB `ENUM`. Cast the tag to `VARCHAR` when the table
preview must show the member name.
"""

nbCode:
  block:
    let con = newDatabase().connect()
    discard con.createAliasType("order_id", "UBIGINT")
    discard con.createUnionType(
      "measurement", "integer_value INTEGER, text_value VARCHAR")

    con.execute("CREATE TABLE sample (id order_id, value measurement)")
    con.execute("""
      INSERT INTO sample VALUES
        (1, union_value(integer_value := 42)),
        (2, union_value(text_value := 'unknown'))
    """)

    echo con.execute("""
      SELECT id, union_tag(value)::VARCHAR AS value_kind
      FROM sample
      ORDER BY id
    """)

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
## Inspect a table before use

`newTableDescription` reads column metadata without an `information_schema`
query. It is suitable for adapters that must reject an incompatible table
before data processing starts.

Column positions use zero-based indexes. `columnType(i)` returns a logical
type, and `toDuckType` returns its top-level kind.
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("""
      CREATE TABLE event (
        id BIGINT,
        payload VARCHAR,
        created_at TIMESTAMP DEFAULT current_timestamp
      )
    """)

    let description = newTableDescription(con, "event")
    for i in 0 ..< description.columnCount:
      echo description.columnName(i), " -> ",
        description.columnType(i).toDuckType,
        " has_default=", description.columnHasDefault(i)

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
Pass `schema` and `catalog` when the table is outside the default namespace.
A missing table raises `OperationError`.

The table description owns a native handle. Keep it local to the inspection
operation. Do not cache it as a substitute for a migration version.
"""

nbText: """
## Quote dynamic identifiers

Bound parameters represent values, not table or column names. Use
`quoteIdent` when trusted application logic selects an identifier at run
time.
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let tableName = "daily report"
    con.execute("CREATE TABLE " & quoteIdent(tableName) & " (value INTEGER)")
    con.execute("INSERT INTO " & quoteIdent(tableName) & " VALUES (7)")
    echo con.execute("SELECT value FROM " & quoteIdent(tableName))

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
`quoteIdent` prevents identifier syntax from changing the statement. It does
not decide whether the caller has permission to select that identifier.

Use prepared-statement parameters for values. Use an allowlist plus
`quoteIdent` for identifiers.
"""

nbText: """
## Make related DDL atomic

DuckDB supports transactional DDL. Group related type and table changes in a
`transaction` block. An exception rolls back the complete group.
"""

nbCode:
  block:
    type Priority = enum
      low
      high

    let con = newDatabase().connect()
    con.transaction:
      discard con.createType(Priority, "priority")
      con.execute("""
        CREATE TABLE task (
          id BIGINT PRIMARY KEY,
          priority priority NOT NULL
        )
      """)

    echo newTableDescription(con, "task").columnCount

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbSave
