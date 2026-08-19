import nimib, nimibook
import std/strutils

when defined(features.nimdrake.arrow):
  import nimdrake
  import narrow

nbInit(theme = useNimibook)

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
## Arrow Results

Move query results between NimDrake and the Apache Arrow ecosystem.

NimDrake's Arrow integration is optional. It uses the Arrow C Data Interface
and the [`narrow`](https://github.com/BontaVlad/narrow) Nim package.

Install the feature and the Arrow GLib development libraries before compiling:

```bash
nimble install nimdrake --parser:declarative --features:arrow
```

Then import both packages:

```nim
import nimdrake
import narrow
```

Use `toArrowStream` when the consumer can process record batches as they arrive.
Use `toArrowTable` when the consumer needs one in-memory Arrow table.
The stream path preserves chunk boundaries. The table path consumes all rows.
"""

nbText: """
## Stream record batches

Keep the query streaming while exporting each DuckDB chunk as an Arrow
`RecordBatch`. The example also shows Arrow schema names and null handling.
"""

nbText: """
```nim
let con = newDatabase().connect()
let stmt = con.newStatement(
  "SELECT seq::BIGINT AS id, " &
  "CASE WHEN seq % 2 = 0 THEN seq::BIGINT ELSE NULL END AS maybe_id " &
  "FROM generate_series(1, 6000) AS t(seq)")

var rows = 0'i64
var batches = 0
var nulls = 0
for batch in con.executeStreaming(stmt).toArrowStream():
  inc batches
  rows += batch.nRows
  let ids = batch[0, int64]
  let maybeIds = batch[1, int64]
  for i in 0 ..< maybeIds.len:
    if maybeIds.isNull(i):
      inc nulls
  echo batch.getColumnName(0), " first=", ids[0]

echo "batches: ", batches, " rows: ", rows, " nulls: ", nulls
```
"""

when defined(features.nimdrake.arrow):
  nbCode:
    block:
      let con = newDatabase().connect()
      let stmt = con.newStatement("""
        SELECT
          seq::BIGINT AS id,
          CASE WHEN seq % 2 = 0 THEN seq::BIGINT ELSE NULL END AS maybe_id
        FROM generate_series(1, 6000) AS t(seq)
      """)

      var rows = 0'i64
      var batches = 0
      var nulls = 0
      for batch in con.executeStreaming(stmt).toArrowStream():
        inc batches
        rows += batch.nRows
        let ids = batch[0, int64]
        let maybeIds = batch[1, int64]
        for i in 0 ..< maybeIds.len:
          if maybeIds.isNull(i):
            inc nulls
        echo batch.getColumnName(0), " first=", ids[0]

      echo "batches: ", batches, " rows: ", rows, " nulls: ", nulls

  nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
## Materialize an Arrow table and query it again

Use `toArrowTable` for a result that must be passed to another Arrow API or
held for later work. The table owns all of its record batches.

NimDrake can also scan that table again. Register the table as a view with
`newMaterialized`, then use ordinary SQL for filtering and projection.
"""

nbText: """
```nim
let con = newDatabase().connect()
let stmt = con.newStatement(
  "SELECT seq::BIGINT AS id, ('item_' || seq::VARCHAR) AS label " &
  "FROM generate_series(1, 3) AS t(seq)")

let arrowTable = con.executeStreaming(stmt).toArrowTable()
echo "Arrow rows: ", arrowTable.nRows

con.register(newMaterialized(arrowTable, con), name = "arrow_input")
echo con.execute(
  "SELECT id, upper(label) AS label FROM arrow_input ORDER BY id")
```
"""

when defined(features.nimdrake.arrow):
  nbCode:
    block:
      let con = newDatabase().connect()
      let stmt = con.newStatement("""
        SELECT seq::BIGINT AS id, ('item_' || seq::VARCHAR) AS label
        FROM generate_series(1, 3) AS t(seq)
      """)

      let arrowTable = con.executeStreaming(stmt).toArrowTable()
      echo "Arrow rows: ", arrowTable.nRows

      con.register(newMaterialized(arrowTable, con), name = "arrow_input")
      echo con.execute("""
        SELECT id, upper(label) AS label
        FROM arrow_input
        ORDER BY id
      """)

  nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)

nbText: """
## Choose the Arrow representation

Use a `RecordBatch` iterator for bounded memory and incremental processing.
Use an `ArrowTable` for APIs that require a complete table or random access.
Use NimDrake's typed vectors instead when no Arrow consumer is involved.

Arrow conversion does not make a small query faster by itself. Choose it when
the next library already speaks Arrow, or when its batch model fits the work.
"""

nbSave
