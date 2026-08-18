import criterion
import ../src/nimdrake
import ./[config, tools]

const Rows = 5_000
const ExpectedSum = (Rows.int64 * (Rows.int64 - 1)) div 2

proc doubleValue(value: int64): int64 = value * 2

let udfDatabase = newDatabase()
let udfConnection = udfDatabase.connect()
udfConnection.registerScalar(doubleValue)

proc scalarUdfScan() =
  let resultSet = udfConnection.execute(
    "SELECT doubleValue(i::BIGINT) FROM range(" & $Rows & ") t(i)")
  var sum = 0'i64
  for chunk in resultSet:
    let values = chunk.bindAs(0, DuckType.BigInt)
    for i in 0 ..< values.len:
      sum += values[i]
  doAssert sum == ExpectedSum * 2

proc appenderPath() =
  let conn = newDatabase().connect()
  conn.execute("DROP TABLE IF EXISTS type_path_input")
  conn.execute("CREATE TABLE type_path_input (value BIGINT)")
  var rows = newSeq[seq[int64]](Rows)
  for i in 0 ..< Rows:
    rows[i] = @[i.int64]
  conn.appendRows("type_path_input", rows)
  let resultSet = conn.execute("SELECT sum(value)::BIGINT FROM type_path_input")
  doAssert resultSet.scalar(DuckType.BigInt) == ExpectedSum

proc runProfile(options: ProfileOptions) =
  case options.caseName
  of "scalar_udf": repeatProfile(options, scalarUdfScan)
  of "appender": repeatProfile(options, appenderPath)
  else: raise newException(ValueError, "unknown type-path profile case: " & options.caseName)

let options = profileOptions()
if profilingRequested(options):
  runProfile(options)
else:
  let cfg = benchmarkConfig()
  benchmark cfg:
    proc benchmarkScalarUdf() {.measure.} = scalarUdfScan()
    proc benchmarkAppender() {.measure.} = appenderPath()
