import criterion
import ../src/nimdrake
import ./[config, tools]

const Rows = 10_000
const WideSelect = "SELECT " &
  "i::BIGINT AS c0, i::BIGINT AS c1, i::BIGINT AS c2, i::BIGINT AS c3, " &
  "i::BIGINT AS c4, i::BIGINT AS c5, i::BIGINT AS c6, i::BIGINT AS c7, " &
  "i::BIGINT AS c8, i::BIGINT AS c9, i::BIGINT AS c10, i::BIGINT AS c11, " &
  "i::BIGINT AS c12, i::BIGINT AS c13, i::BIGINT AS c14, i::BIGINT AS c15 " &
  "FROM range(" & $Rows & ") t(i)"

let projectionDatabase = newDatabase()
let projectionConnection = projectionDatabase.connect()
let projectionSource = projectionConnection.execute(WideSelect)
projectionConnection.register(projectionSource, name = "wide_registered")

proc scanOneColumn() =
  let conn = newDatabase().connect()
  let resultSet = conn.execute("SELECT c0 FROM (" & WideSelect & ")")
  var sum = 0'i64
  for chunk in resultSet:
    let values = chunk.bindAs(0, DuckType.BigInt)
    for i in 0 ..< values.len:
      sum += values[i]
  doAssert sum == (Rows.int64 * (Rows.int64 - 1)) div 2

proc scanReorderedColumns() =
  let conn = newDatabase().connect()
  let resultSet = conn.execute("SELECT c15, c3, c0 FROM (" & WideSelect & ")")
  var sum = 0'i64
  for chunk in resultSet:
    let values = chunk.bindAs(0, DuckType.BigInt)
    for i in 0 ..< values.len:
      sum += values[i]
  doAssert sum == (Rows.int64 * (Rows.int64 - 1)) div 2

proc scanAllColumns() =
  let conn = newDatabase().connect()
  let resultSet = conn.execute(WideSelect)
  var sum = 0'i64
  for chunk in resultSet:
    for column in 0 ..< chunk.columnCount:
      let values = chunk.bindAs(column, DuckType.BigInt)
      sum += values[0]
  doAssert sum >= 0

proc scanRegisteredOneColumn() =
  let resultSet = projectionConnection.execute(
    "SELECT c0 FROM wide_registered")
  var sum = 0'i64
  for chunk in resultSet:
    let values = chunk.bindAs(0, DuckType.BigInt)
    for i in 0 ..< values.len:
      sum += values[i]
  doAssert sum == (Rows.int64 * (Rows.int64 - 1)) div 2

proc runProfile(options: ProfileOptions) =
  case options.caseName
  of "one_column": repeatProfile(options, scanOneColumn)
  of "reordered": repeatProfile(options, scanReorderedColumns)
  of "all_columns": repeatProfile(options, scanAllColumns)
  of "registered_one_column": repeatProfile(options, scanRegisteredOneColumn)
  else: raise newException(ValueError, "unknown projection profile case: " & options.caseName)

let options = profileOptions()
if profilingRequested(options):
  runProfile(options)
else:
  let cfg = benchmarkConfig()
  benchmark cfg:
    proc benchmarkOneColumn() {.measure.} = scanOneColumn()
    proc benchmarkReorderedColumns() {.measure.} = scanReorderedColumns()
    proc benchmarkAllColumns() {.measure.} = scanAllColumns()
    proc benchmarkRegisteredOneColumn() {.measure.} = scanRegisteredOneColumn()
