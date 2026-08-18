import criterion
import ../src/nimdrake
import ./[config, tools]

const Rows = 2_000

let ingestionDatabase = newDatabase()
let ingestionConnection = ingestionDatabase.connect()
discard ingestionConnection.execute(
  "CREATE TABLE ingestion_tuple_rows (id BIGINT, name VARCHAR)")

proc buildColumns() =
  var ids = newSeq[int64](Rows)
  var names = newSeq[string](Rows)
  for i in 0 ..< Rows:
    ids[i] = i.int64
    names[i] = "name_" & $i
  let chunk = newChunk(("id", ids), ("name", names))
  doAssert chunk.len == Rows

proc buildWithBuilder() =
  var builder = newChunkBuilder(@[
    newColumn("id", newLogicalType(DuckType.BigInt)),
    newColumn("name", newLogicalType(DuckType.Varchar))])
  for i in 0 ..< Rows:
    append[DuckType.BigInt](builder, 0, i.int64)
    append[DuckType.Varchar](builder, 1, "name_" & $i)
  let chunk = builder.finish()
  doAssert chunk.len == Rows

proc appendTupleRows() =
  discard ingestionConnection.execute("DELETE FROM ingestion_tuple_rows")
  var rows: array[Rows, (int64, string)]
  for i in 0 ..< Rows:
    rows[i] = (i.int64, "name_" & $i)
  ingestionConnection.appendRows("ingestion_tuple_rows", rows)
  for chunk in ingestionConnection.execute(
      "SELECT count(*)::BIGINT FROM ingestion_tuple_rows"):
    doAssert chunk.bindAs(0, DuckType.BigInt)[0] == Rows.int64

proc runProfile(options: ProfileOptions) =
  case options.caseName
  of "column_build": repeatProfile(options, buildColumns)
  of "builder": repeatProfile(options, buildWithBuilder)
  of "tuple_rows": repeatProfile(options, appendTupleRows)
  else: raise newException(ValueError, "unknown ingestion profile case: " & options.caseName)

let options = profileOptions()
if profilingRequested(options):
  runProfile(options)
else:
  let cfg = benchmarkConfig()
  benchmark cfg:
    proc benchmarkColumnBuild() {.measure.} = buildColumns()
    proc benchmarkChunkBuilder() {.measure.} = buildWithBuilder()
    proc benchmarkTupleRows() {.measure.} = appendTupleRows()
