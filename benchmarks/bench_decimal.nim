import criterion
import ../src/nimdrake
import ./[config, tools]

const Rows = 2_000

proc materializeDecimals() =
  let conn = newDatabase().connect()
  let resultSet = conn.execute(
    "SELECT (i - 1000)::DECIMAL(18, 3) FROM range(" & $Rows & ") t(i)")
  var values: seq[NimValue] = @[]
  for chunk in resultSet:
    values.add chunk.vector(0).toNimValues
  doAssert values.len == Rows

proc readDecimalValues() =
  let conn = newDatabase().connect()
  let resultSet = conn.execute(
    "SELECT (i - 1000)::DECIMAL(18, 3) FROM range(" & $Rows & ") t(i)")
  var total = 0
  for chunk in resultSet:
    let values = chunk.bindAs(0, DuckType.Decimal)
    for i in 0 ..< values.len:
      total += ($values[i]).len
  doAssert total > Rows

proc runProfile(options: ProfileOptions) =
  case options.caseName
  of "materialize": repeatProfile(options, materializeDecimals)
  of "read_format": repeatProfile(options, readDecimalValues)
  else: raise newException(ValueError, "unknown decimal profile case: " & options.caseName)

let options = profileOptions()
if profilingRequested(options):
  runProfile(options)
else:
  let cfg = benchmarkConfig()
  benchmark cfg:
    proc benchmarkDecimalMaterialization() {.measure.} = materializeDecimals()
    proc benchmarkDecimalReadFormat() {.measure.} = readDecimalValues()
