import std/[locks, sequtils, tables, strformat, math, times]
import /[api, database, dataframe, query, table_functions, types]

# 2048 is duckdb_vector_size(), but we can't do this at compile time
const
  VECTOR_SIZE = 2048
  ROW_GROUP_SIZE = VECTOR_SIZE * 100

type
  NotImplementedException = object of CatchableError
  ExtraData* = ref object of RootObj
    data*: Table[string, DataFrame]

  GlobalData = ref object
    pos: int
    lock: Lock

  BindData = ref object
    df: DataFrame

  LocalData = ref object
    columns: seq[Column]
    currentPos: int
    endPos: int
    rowCount: int

const
  # RoundingEpochToUnixEpochDays = 719163 # Same constant as in Julia
  RoundingEpochToUnixEpochMs = 62135596800000 # Milliseconds version

proc destroyBind(p: pointer) {.cdecl.} =
  `=destroy`(cast[BindData](p))

proc destroyGlobalData(p: pointer) {.cdecl.} =
  `=destroy`(cast[GlobalData](p))

proc destroyLocalData(p: pointer) {.cdecl.} =
  `=destroy`(cast[LocalData](p))

# Helper functions for date/time conversions
# proc dateToEpochDays(d: DateTime): int32 =
#   (d - initDateTime(1, mJan, 1970, 0, 0, 0, utc())).inDays.int32

proc timeToMicroseconds(t: Time): int64 =
  t.toUnix * 1_000_000 + t.nanosecond.int64 div 1_000

proc dateTimeToEpochMs(dt: DateTime): int64 =
  (dt - initDateTime(1, mJan, 1970, 0, 0, 0, utc())).inMilliseconds

# Value conversion functions
proc valueToDuckDB*(val: DateTime): int64 =
  (dateTimeToEpochMs(val) - RoundingEpochToUnixEpochMs) * 1000

proc valueToDuckDB*(val: Time): int64 =
  timeToMicroseconds(val) div 1000

proc valueToDuckDB*(val: string): auto =
  raise newException(
    NotImplementedException,
    "Cannot use valueToDuckDB to convert string values - use DuckDB.assign_string_element on a vector instead",
  )

proc valueToDuckDB*[T](val: T): T =
  val

# TODO  this needs work
proc scanColumn(
    kind: DuckType,
    values: Vector,
    rowOffset, scanCount, resultIdx: int,
    chunk: duckdb_data_chunk,
) =
  let vec = duckdb_data_chunk_get_vector(chunk, resultIdx.idx_t)

  duckdb_vector_ensure_validity_writable(vec)
  let
    raw = duckdb_vector_get_data(vec)
    validity = duckdb_vector_get_validity(vec)

  case kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    raise newException(ValueError, fmt"got invalid enum type: {kind}")
  of DuckType.Boolean:
    var resultArray = cast[ptr UncheckedArray[uint8]](raw)
    for i, e in values.valueBoolean[rowOffset ..< scanCount]:
      resultArray[i] = e.uint8
  of DuckType.TinyInt:
    var resultArray = cast[ptr UncheckedArray[int8]](raw)
    for i, e in values.valueTinyint[rowOffset ..< scanCount]:
      resultArray[i] = e
  of DuckType.SmallInt:
    var resultArray = cast[ptr UncheckedArray[int16]](raw)
    for i, e in values.valueSmallint[rowOffset ..< scanCount]:
      resultArray[i] = e
  of DuckType.Integer:
    var resultArray = cast[ptr UncheckedArray[int32]](raw)
    for i, e in values.valueInteger[rowOffset ..< scanCount]:
      resultArray[i] = e
  of DuckType.BigInt:
    var resultArray = cast[ptr UncheckedArray[int64]](raw)
    for i, e in values.valueBigint[rowOffset ..< scanCount]:
      duckdb_validity_set_row_valid(validity, i.idx_t)
      resultArray[i] = e
  of DuckType.UTinyInt:
    var resultArray = cast[ptr UncheckedArray[uint8]](raw)
    for i, e in values.valueUTinyint[rowOffset ..< scanCount]:
      resultArray[i] = e
  of DuckType.USmallInt:
    var resultArray = cast[ptr UncheckedArray[uint16]](raw)
    for i, e in values.valueUSmallint[rowOffset ..< scanCount]:
      resultArray[i] = e
  of DuckType.UInteger:
    var resultArray = cast[ptr UncheckedArray[uint32]](raw)
    for i, e in values.valueUInteger[rowOffset ..< scanCount]:
      resultArray[i] = e
  of DuckType.UBigInt:
    var resultArray = cast[ptr UncheckedArray[uint64]](raw)
    for i, e in values.valueUBigint[rowOffset ..< scanCount]:
      resultArray[i] = e
  of DuckType.Float:
    var resultArray = cast[ptr UncheckedArray[float32]](raw)
    for i, e in values.valueFloat[rowOffset ..< scanCount]:
      resultArray[i] = e
  of DuckType.Double:
    var resultArray = cast[ptr UncheckedArray[float64]](raw)
    for i, e in values.valueDouble[rowOffset ..< scanCount]:
      resultArray[i] = e
  of DuckType.Timestamp:
    discard
    # result.valueTimestamp = newSeq[DateTime]()
  of DuckType.Date:
    discard
    # result.valueDate = newSeq[DateTime]()
  of DuckType.Time:
    discard
    # result.valueTime = newSeq[Time]()
  of DuckType.Interval:
    discard
    # result.valueInterval = newSeq[TimeInterval]()
  of DuckType.HugeInt:
    discard
    # result.valueHugeint = newSeq[Int128]()
  of DuckType.Varchar:
    for i, e in values.valueVarChar[rowOffset ..< scanCount]:
      duckdb_vector_assign_string_element(vec, i.idx_t, e.cstring)
      duckdb_validity_set_row_valid(validity, i.idx_t)
    # result.valueVarchar = newSeq[string]()
  of DuckType.Blob:
    discard
    # result.valueBlob = newSeq[seq[byte]]()
  of DuckType.Decimal:
    discard
    # result.valueDecimal = newSeq[DecimalType]()
  of DuckType.TimestampS:
    discard
    # result.valueTimestampS = newSeq[DateTime]()
  of DuckType.TimestampMs:
    discard
    # result.valueTimestampMs = newSeq[DateTime]()
  of DuckType.TimestampNs:
    discard
    # result.valueTimestampNs = newSeq[DateTime]()
  of DuckType.Enum:
    discard
    # result.valueEnum = newSeq[uint]()
  of DuckType.List:
    discard
    # result.valueList = newSeq[seq[Value]]()
  of DuckType.Struct, DuckType.Map:
    discard
    # result.valueStruct = newSeq[Table[string, Value]]()
  of DuckType.UUID:
    discard
    # result.valueUuid = newSeq[Uuid]()
  of DuckType.Union:
    discard
    # result.valueUnion = newSeq[Table[string, Value]]()
  of DuckType.Bit:
    discard
    # result.valueBit = newSeq[string]()
  of DuckType.TimeTz:
    discard

proc bindFunction(info: BindInfo) =
  let
    parameter = info.parameters.toSeq
    name = parameter[0].valueVarchar
    df = cast[ExtraData](info.mainFunction.extraData).data[name]
    data = BindData(df: df)

  duckdb_bind_set_cardinality(info.handle, len(df).uint64, true)
  for column in df.columns:
    info.add_result_column(column.name, column.kind)
  GC_ref(data)
  duckdb_bind_set_bind_data(info.handle, cast[ptr BindData](data), destroyBind)

proc initFunction(info: InitInfo) =
  let
    bindInfo = cast[BindData](duckdb_init_get_bind_data(info.handle))
    maxThreads = ceil(len(bindInfo.df) / ROW_GROUP_SIZE)
  var rowLock: Lock
  initLock rowLock
  let data = GlobalData(pos: 0, lock: rowLock)
  duckdb_init_set_max_threads(info.handle, max_threads.idx_t)
  GC_ref(data)
  duckdb_init_set_init_data(info.handle, cast[ptr GlobalData](data), destroyGlobalData)

proc initLocalFunction(info: InitInfo) =
  let
    bindInfo = cast[BindData](duckdb_init_get_bind_data(info.handle))
    data = LocalData(currentPos: 0, endPos: 0, rowCount: bindInfo.df.len)
    columnCount = duckdb_init_get_column_count(info.handle)

  let columns = bindInfo.df.columns.toSeq
  for i in 0 ..< columnCount:
    let colIdx = duckdb_init_get_column_index(info.handle, i)
    data.columns.add(columns[colIdx])

  GC_ref(data)
  duckdb_init_set_init_data(info.handle, cast[ptr LocalData](data), destroyLocalData)

proc mainFunction(info: FunctionInfo, chunk: duckdb_data_chunk) =
  let bindInfo = cast[BindData](duckdb_function_get_bind_data(info))
  var
    globalData = cast[GlobalData](duckdb_function_get_init_data(info))
    localData = cast[LocalData](duckdb_function_get_local_init_data(info))

  # Set the boundries for another chunk
  if localData.currentPos >= localData.endPos:
    if tryAcquire(globalData.lock):
      let rowCount = localData.rowCount
      localData.currentPos = globalData.pos
      var totalScanAmount = ROW_GROUP_SIZE
      if localData.currentPos + totalScanAmount >= rowCount:
        totalScanAmount = rowCount - localData.currentPos
      localData.endPos = localData.currentPos + totalScanAmount
      globalData.pos += totalScanAmount
  var
    scanCount = VECTOR_SIZE
    currentRow = localData.currentPos

  if currentRow + scanCount >= localData.endPos:
    scanCount = localData.endPos - currentRow

  if scanCount == 0:
    return

  localData.currentPos += scanCount

  # set result array
  var resultIdx = 0
  for col in localData.columns:
    scanColumn(
      col.kind, bindInfo.df.values[col.idx], currentRow, scanCount, resultIdx, chunk
    )
    resultIdx += 1

  # GC_ref(chunk)
  duckdb_data_chunk_set_size(chunk, scanCount.idx_t)

proc newExtraData(): ExtraData =
  result = ExtraData(data: initTable[string, DataFrame]())

proc register*(con: Connection, name: string, df: DataFrame) =
  var extraData = newExtraData()
  extraData.data[name] = df

  let tf = newTableFunction(
    name = "nim_tbl_scan",
    parameters = @[newLogicalType(DuckType.VARCHAR)],
    bindFunc = bindFunction,
    initFunc = initFunction,
    initLocalFunc = initLocalFunction,
    mainFunc = mainFunction,
    extraData = extradata,
    projectionPushdown = true,
  )
  con.register(tf)
  con.execute(
    fmt"""CREATE OR REPLACE VIEW "{name}" AS SELECT * FROM nim_tbl_scan('{name}');"""
  )
