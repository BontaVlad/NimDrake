import criterion
from std/options import get, isSome
import ../src/nimdrake
import ./[config, tools]

const
  StreamingRows = 1_048_577
  DataRows = 131_073
  TableRows = 262_145
  RandomReads = 500_000
  StreamingSum = (StreamingRows.int64 * (StreamingRows.int64 - 1)) div 2
  EvenSum = block:
    let n = (DataRows + 1).int64 div 2
    n * (n - 1)
  NestedSum = 8'i64 * (DataRows.int64 * (DataRows.int64 - 1) div 2) +
    DataRows.int64 * 28

let dataConnection = newDatabase().connect()
let streamingStatement = dataConnection.newStatement(
  "SELECT i::BIGINT FROM range(" & $StreamingRows & ") t(i)")
let nullableResult = dataConnection.execute(
  "SELECT CASE WHEN i % 2 = 0 THEN i::BIGINT ELSE NULL END " &
  "FROM range(" & $DataRows & ") t(i)")
let nestedResult = dataConnection.execute(
  "SELECT [i, i+1, i+2, i+3, i+4, i+5, i+6, i+7]::BIGINT[] " &
  "FROM range(" & $DataRows & ") t(i)")
let randomTable = initTable(dataConnection.execute(
  "SELECT i::BIGINT FROM range(" & $TableRows & ") t(i)"))
let randomVector = randomTable.bindAs(0, DuckType.BigInt)

proc streamingScan() =
  let resultSet = dataConnection.executeStreaming(streamingStatement)
  var total = 0'i64
  var rows = 0
  for chunk in resultSet:
    let values = chunk.bindAs(0, DuckType.BigInt)
    rows += values.len
    for value in values:
      total += value
  doAssert rows == StreamingRows and total == StreamingSum

proc nullableItems() =
  var count = 0
  var total = 0'i64
  for chunk in nullableResult:
    let values = chunk.bindAs(0, DuckType.BigInt)
    for value in values.itemsOpt:
      if value.isSome:
        inc count
        total += value.get
  doAssert count == (DataRows + 1) div 2 and total == EvenSum

proc nullableBulk() =
  var count = 0
  var total = 0'i64
  for chunk in nullableResult:
    for value in chunk.bindAs(0, DuckType.BigInt).toSeqOpt:
      if value.isSome:
        inc count
        total += value.get
  doAssert count == (DataRows + 1) div 2 and total == EvenSum

proc nestedBorrowed() =
  var rows = 0
  var total = 0'i64
  for chunk in nestedResult:
    let lists = chunk.bindAs(0, seq[int64])
    rows += lists.len
    for i in 0 ..< lists.len:
      for value in lists.borrowList(i):
        total += value
  doAssert rows == DataRows and total == NestedSum

proc nestedOwning() =
  var rows = 0
  var total = 0'i64
  for chunk in nestedResult:
    let lists = chunk.bindAs(0, seq[int64])
    rows += lists.len
    for values in lists:
      for value in values:
        total += value
  doAssert rows == DataRows and total == NestedSum

proc tableRandomAccess() =
  var state = 0x9e3779b97f4a7c15'u64
  var total = 0'i64
  for _ in 0 ..< RandomReads:
    state = state * 6364136223846793005'u64 + 1442695040888963407'u64
    total += randomVector[int(state mod TableRows.uint64)]
  doAssert total > 0

proc runProfile(options: ProfileOptions) =
  case options.caseName
  of "streaming_scan": repeatProfile(options, streamingScan)
  of "nullable_items": repeatProfile(options, nullableItems)
  of "nullable_bulk": repeatProfile(options, nullableBulk)
  of "nested_borrowed": repeatProfile(options, nestedBorrowed)
  of "nested_owning": repeatProfile(options, nestedOwning)
  of "table_random_access": repeatProfile(options, tableRandomAccess)
  else:
    raise newException(ValueError,
      "unknown data-path profile case: " & options.caseName)

let profile = profileOptions()
if profilingRequested(profile):
  runProfile(profile)
else:
  let cfg = benchmarkConfig()
  benchmark cfg:
    proc benchmarkStreamingScan() {.measure.} = streamingScan()
    proc benchmarkNullableItems() {.measure.} = nullableItems()
    proc benchmarkNullableBulk() {.measure.} = nullableBulk()
    proc benchmarkNestedBorrowed() {.measure.} = nestedBorrowed()
    proc benchmarkNestedOwning() {.measure.} = nestedOwning()
    proc benchmarkTableRandomAccess() {.measure.} = tableRandomAccess()
