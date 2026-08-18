import criterion
import ../src/nimdrake
import ./[config, tools]

const
  Rows = 2_048
  Rebinds = 1_000
  ExpectedSum = (Rows.int64 * (Rows.int64 - 1)) div 2

let
  integerValues = block:
    var values = newSeq[int64](Rows)
    for i in 0 ..< Rows:
      values[i] = i.int64
    values
  integerChunk = newChunk(("value", integerValues))
  integerColumn = integerChunk.vector(0)
  integerVector = integerChunk.bindAs(0, DuckType.BigInt)

  stringValues = block:
    var values = newSeq[string](Rows)
    for i in 0 ..< Rows:
      values[i] = "value_" & $i
    values
  stringChunk = newChunk(("value", stringValues))
  stringVector = stringChunk.bindAs(0, DuckType.Varchar)

proc consumeSum(sum: int64, expected: int64) {.inline.} =
  doAssert sum == expected

proc columnViewCreation() =
  var kind = DuckType.Invalid
  var length = 0
  for _ in 0 ..< Rebinds:
    let view = integerChunk.vector(0)
    kind = view.kind
    length = view.length
  doAssert kind == DuckType.BigInt and length == Rows

proc bindTypedVector() =
  var sum = 0'i64
  for _ in 0 ..< Rebinds:
    let values = integerColumn.bindAs(DuckType.BigInt)
    sum += values[Rows - 1]
  consumeSum(sum, Rebinds.int64 * (Rows - 1).int64)

proc bindFromChunkAndRead() =
  var sum = 0'i64
  for _ in 0 ..< Rebinds:
    let values = integerChunk.bindAs(0, DuckType.BigInt)
    sum += values[Rows - 1]
  consumeSum(sum, Rebinds.int64 * (Rows - 1).int64)

proc indexedRead() =
  var sum = 0'i64
  for i in 0 ..< integerVector.len:
    sum += integerVector[i]
  consumeSum(sum, ExpectedSum)

proc iteratorRead() =
  var sum = 0'i64
  for value in integerVector.items:
    sum += value
  consumeSum(sum, ExpectedSum)

proc bulkRead() =
  let values = integerVector.toSeq
  var sum = 0'i64
  for value in values:
    sum += value
  consumeSum(sum, ExpectedSum)

proc stringRead() =
  var total = 0
  for i in 0 ..< stringVector.len:
    total += stringVector[i].len
  doAssert total > Rows

proc stringBorrow() =
  var total = 0
  for value in stringVector.borrowItems:
    total += value.len
  doAssert total > Rows

proc runProfile(options: ProfileOptions) =
  case options.caseName
  of "column_view": repeatProfile(options, columnViewCreation)
  of "bind_typed": repeatProfile(options, bindTypedVector)
  of "bind_from_chunk": repeatProfile(options, bindFromChunkAndRead)
  of "indexed_read": repeatProfile(options, indexedRead)
  of "iterator_read": repeatProfile(options, iteratorRead)
  of "bulk_read": repeatProfile(options, bulkRead)
  of "string_read": repeatProfile(options, stringRead)
  of "string_borrow": repeatProfile(options, stringBorrow)
  else: raise newException(ValueError, "unknown vector profile case: " & options.caseName)

let options = profileOptions()
if profilingRequested(options):
  runProfile(options)
else:
  let cfg = benchmarkConfig()
  benchmark cfg:
    proc benchmarkColumnViewCreation() {.measure.} = columnViewCreation()
    proc benchmarkBindTypedVector() {.measure.} = bindTypedVector()
    proc benchmarkBindFromChunkAndRead() {.measure.} = bindFromChunkAndRead()
    proc benchmarkIndexedRead() {.measure.} = indexedRead()
    proc benchmarkIteratorRead() {.measure.} = iteratorRead()
    proc benchmarkBulkRead() {.measure.} = bulkRead()
    proc benchmarkStringRead() {.measure.} = stringRead()
    proc benchmarkStringBorrow() {.measure.} = stringBorrow()
