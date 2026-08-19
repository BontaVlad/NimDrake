import criterion
from std/options import Option, get, isSome, none, some
import ../src/nimdrake
import ./[config, tools]

const
  Rows = 262_144
  Groups = 4_096
  ExpectedSum = (Rows.int64 * (Rows.int64 - 1)) div 2

proc owningLength(value: string): int64 = value.len.int64
proc borrowedLength(value: DuckStringRef): int64 = value.len.int64

type WeightedSum = object
  total: int64
  count: uint64

proc initWeighted(state: var WeightedSum) =
  state.total = 0
  state.count = 0

proc updateWeighted(state: var WeightedSum, value, weight: int64) =
  state.total += value * weight
  inc state.count

proc combineWeighted(destination: var WeightedSum, source: WeightedSum) =
  destination.total += source.total
  destination.count += source.count

proc finishWeighted(state: WeightedSum): Option[int64] =
  if state.count == 0: none(int64)
  else: some(state.total)

proc updateWeightedVector(
    states: States[WeightedSum], values, weights: Vector[DuckType.BigInt]) =
  for i in 0 ..< states.len:
    if values.valid(i) and weights.valid(i):
      states[i].total += values[i] * weights[i]
      inc states[i].count

proc combineWeightedVector(
    destination, source: States[WeightedSum]) =
  for i in 0 ..< destination.len:
    destination[i].total += source[i].total
    destination[i].count += source[i].count

proc finishWeightedVector(
    source: States[WeightedSum], output: var Vector[DuckType.BigInt],
    count, offset: int) =
  for i in 0 ..< count:
    if source[i].count == 0:
      output.setNull(offset + i)
    else:
      output[offset + i] = source[i].total

iterator callbackRows(n: int): tuple[
    c0, c1, c2, c3, c4, c5, c6, c7: int] {.closure.} =
  for i in 0 ..< n:
    yield (i, i + 1, i + 2, i + 3, i + 4, i + 5, i + 6, i + 7)

let callbackConnection = newDatabase().connect()
callbackConnection.registerScalar(owningLength)
callbackConnection.registerScalar(borrowedLength)
callbackConnection.registerAggregate(
  "weightedSum", initWeighted, updateWeighted, combineWeighted, finishWeighted)
registerAggregate(
  callbackConnection, "weightedSumVector", initWeighted,
  updateWeightedVector, combineWeightedVector, finishWeightedVector)
callbackConnection.registerTableFunction(callbackRows)

proc scalarOwning() =
  let resultSet = callbackConnection.execute(
    "SELECT sum(owningLength(value))::BIGINT FROM (" &
    "SELECT CASE WHEN i % 8 = 0 THEN NULL " &
    "ELSE repeat('x', 32) END AS value FROM range(" & $Rows & ") t(i))")
  doAssert resultSet.scalar(DuckType.BigInt) == ((Rows - Rows div 8) * 32).int64

proc scalarBorrowed() =
  let resultSet = callbackConnection.execute(
    "SELECT sum(borrowedLength(value))::BIGINT FROM (" &
    "SELECT CASE WHEN i % 8 = 0 THEN NULL " &
    "ELSE repeat('x', 32) END AS value FROM range(" & $Rows & ") t(i))")
  doAssert resultSet.scalar(DuckType.BigInt) == ((Rows - Rows div 8) * 32).int64

proc aggregateBuiltIn() =
  let resultSet = callbackConnection.execute(
    "SELECT (i % " & $Groups & ")::INTEGER AS g, " &
    "sum(i * 3)::BIGINT AS value FROM range(" & $Rows & ") t(i) GROUP BY g")
  var total = 0'i64
  for chunk in resultSet:
    for value in chunk.bindAs(1, DuckType.BigInt):
      total += value
  doAssert total == ExpectedSum * 3

proc aggregateRowCallback() =
  let resultSet = callbackConnection.execute(
    "SELECT (i % " & $Groups & ")::INTEGER AS g, " &
    "weightedSum(i::BIGINT, 3::BIGINT) AS value " &
    "FROM range(" & $Rows & ") t(i) GROUP BY g")
  var total = 0'i64
  for chunk in resultSet:
    for value in chunk.bindAs(1, DuckType.BigInt):
      total += value
  doAssert total == ExpectedSum * 3

proc aggregateVectorCallback() =
  let resultSet = callbackConnection.execute(
    "SELECT (i % " & $Groups & ")::INTEGER AS g, " &
    "weightedSumVector(i::BIGINT, 3::BIGINT) AS value " &
    "FROM range(" & $Rows & ") t(i) GROUP BY g")
  var total = 0'i64
  for chunk in resultSet:
    for value in chunk.bindAs(1, DuckType.BigInt):
      total += value
  doAssert total == ExpectedSum * 3

proc tableAllColumns() =
  let resultSet = callbackConnection.execute(
    "SELECT sum(c0+c1+c2+c3+c4+c5+c6+c7)::BIGINT " &
    "FROM callbackRows(" & $Rows & ")")
  doAssert resultSet.scalar(DuckType.BigInt) == ExpectedSum * 8 + Rows.int64 * 28

proc tableProjectedColumn() =
  let resultSet = callbackConnection.execute(
    "SELECT sum(c7)::BIGINT FROM callbackRows(" & $Rows & ")")
  doAssert resultSet.scalar(DuckType.BigInt) == ExpectedSum + Rows.int64 * 7

proc runProfile(options: ProfileOptions) =
  case options.caseName
  of "scalar_owning": repeatProfile(options, scalarOwning)
  of "scalar_borrowed": repeatProfile(options, scalarBorrowed)
  of "aggregate_builtin": repeatProfile(options, aggregateBuiltIn)
  of "aggregate_row": repeatProfile(options, aggregateRowCallback)
  of "aggregate_vector": repeatProfile(options, aggregateVectorCallback)
  of "table_all_columns": repeatProfile(options, tableAllColumns)
  of "table_projected": repeatProfile(options, tableProjectedColumn)
  else:
    raise newException(ValueError,
      "unknown callback profile case: " & options.caseName)

let profile = profileOptions()
if profilingRequested(profile):
  runProfile(profile)
else:
  let cfg = benchmarkConfig()
  benchmark cfg:
    proc benchmarkScalarOwning() {.measure.} = scalarOwning()
    proc benchmarkScalarBorrowed() {.measure.} = scalarBorrowed()
    proc benchmarkAggregateBuiltIn() {.measure.} = aggregateBuiltIn()
    proc benchmarkAggregateRowCallback() {.measure.} = aggregateRowCallback()
    proc benchmarkAggregateVectorCallback() {.measure.} = aggregateVectorCallback()
    proc benchmarkTableAllColumns() {.measure.} = tableAllColumns()
    proc benchmarkTableProjectedColumn() {.measure.} = tableProjectedColumn()
