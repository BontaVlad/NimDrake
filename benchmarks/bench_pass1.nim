import criterion
import ../src/nimdrake
import ./[config, tools]

const Rows = 20_000
const ExpectedSum = (Rows.int64 * (Rows.int64 - 1)) div 2

proc scanIntegers() =
  discard checkedIntSum("SELECT i::BIGINT FROM range(" & $Rows & ") t(i)", ExpectedSum)

proc scanStrings() =
  let conn = newDatabase().connect()
  let resultSet = conn.execute(
    "SELECT 'value_' || i::VARCHAR FROM range(" & $Rows & ") t(i)")
  var total = 0
  for chunk in resultSet:
    let values = chunk.bindAs(0, DuckType.Varchar)
    for i in 0 ..< values.len:
      total += values[i].len
  doAssert total > Rows

proc buildChunk() =
  let values = newSeq[int32](Rows)
  var data = values
  for i in 0 ..< data.len:
    data[i] = i.int32
  let chunk = newChunk(("value", data))
  doAssert chunk.len == Rows
  doAssert chunk.bindAs(0, DuckType.Integer)[Rows - 1] == (Rows - 1).int32

proc runProfile(options: ProfileOptions) =
  case options.caseName
  of "integer_scan": repeatProfile(options, scanIntegers)
  of "string_scan": repeatProfile(options, scanStrings)
  of "chunk_build": repeatProfile(options, buildChunk)
  else: raise newException(ValueError, "unknown pass1 profile case: " & options.caseName)

let options = profileOptions()
if profilingRequested(options):
  runProfile(options)
else:
  let cfg = benchmarkConfig()
  benchmark cfg:
    proc benchmarkIntegerScan() {.measure.} = scanIntegers()
    proc benchmarkStringScan() {.measure.} = scanStrings()
    proc benchmarkChunkBuild() {.measure.} = buildChunk()
