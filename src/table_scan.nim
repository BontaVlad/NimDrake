import std/[locks, sequtils, tables, strformat, math]
import /[api, database, dataframe, datachunk, query, table_functions, types, vector, value]

type
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

proc destroyBind(p: pointer) {.cdecl.} =
  `=destroy`(cast[BindData](p))

proc destroyGlobalData(p: pointer) {.cdecl.} =
  `=destroy`(cast[GlobalData](p))

proc destroyLocalData(p: pointer) {.cdecl.} =
  `=destroy`(cast[LocalData](p))

# TODO  this needs work
proc scanColumn(
    values: Vector,
    rowOffset: int,
    scanCount: int,
    resultIdx: int,
    chunk: duckdbDataChunk,
) =
  let vec = duckdb_data_chunk_get_vector(chunk, resultIdx.idx_t)

  duckdb_vector_ensure_validity_writable(vec)
  let
    raw = duckdb_vector_get_data(vec)
    validity = duckdb_vector_get_validity(vec)

  case values.kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    raise newException(ValueError, fmt"got invalid enum type: {values.kind}")
  of DuckType.Boolean:
    var resultArray = cast[ptr UncheckedArray[uint8]](raw)
    for i, e in values.valueBoolean[rowOffset ..< scanCount]:
      resultArray[i] = e.uint8
      if isValid(values, i):
        duckdb_validity_set_row_valid(validity, i.idx_t)
  of DuckType.TinyInt:
    var resultArray = cast[ptr UncheckedArray[int8]](raw)
    for i, e in values.valueTinyint[rowOffset ..< scanCount]:
      resultArray[i] = e
      if isValid(values, i):
        duckdb_validity_set_row_valid(validity, i.idx_t)
  of DuckType.SmallInt:
    var resultArray = cast[ptr UncheckedArray[int16]](raw)
    for i, e in values.valueSmallint[rowOffset ..< scanCount]:
      resultArray[i] = e
      if isValid(values, i):
        duckdb_validity_set_row_valid(validity, i.idx_t)
  of DuckType.Integer:
    var resultArray = cast[ptr UncheckedArray[int32]](raw)
    for i, e in values.valueInteger[rowOffset ..< scanCount]:
      resultArray[i] = e
      if isValid(values, i):
        duckdb_validity_set_row_valid(validity, i.idx_t)
  of DuckType.BigInt:
    var resultArray = cast[ptr UncheckedArray[int64]](raw)
    for i, e in values.valueBigint[rowOffset ..< scanCount]:
      duckdb_validity_set_row_valid(validity, i.idx_t)
      resultArray[i] = e
      if isValid(values, i):
        duckdb_validity_set_row_valid(validity, i.idx_t)
  of DuckType.UTinyInt:
    var resultArray = cast[ptr UncheckedArray[uint8]](raw)
    for i, e in values.valueUTinyint[rowOffset ..< scanCount]:
      resultArray[i] = e
      if isValid(values, i):
        duckdb_validity_set_row_valid(validity, i.idx_t)
  of DuckType.USmallInt:
    var resultArray = cast[ptr UncheckedArray[uint16]](raw)
    for i, e in values.valueUSmallint[rowOffset ..< scanCount]:
      resultArray[i] = e
      if isValid(values, i):
        duckdb_validity_set_row_valid(validity, i.idx_t)
  of DuckType.UInteger:
    var resultArray = cast[ptr UncheckedArray[uint32]](raw)
    for i, e in values.valueUInteger[rowOffset ..< scanCount]:
      resultArray[i] = e
      if isValid(values, i):
        duckdb_validity_set_row_valid(validity, i.idx_t)
  of DuckType.UBigInt:
    var resultArray = cast[ptr UncheckedArray[uint64]](raw)
    for i, e in values.valueUBigint[rowOffset ..< scanCount]:
      resultArray[i] = e
      if isValid(values, i):
        duckdb_validity_set_row_valid(validity, i.idx_t)
  of DuckType.Float:
    var resultArray = cast[ptr UncheckedArray[float32]](raw)
    for i, e in values.valueFloat[rowOffset ..< scanCount]:
      resultArray[i] = e
      if isValid(values, i):
        duckdb_validity_set_row_valid(validity, i.idx_t)
  of DuckType.Double:
    var resultArray = cast[ptr UncheckedArray[float64]](raw)
    for i, e in values.valueDouble[rowOffset ..< scanCount]:
      resultArray[i] = e
      if isValid(values, i):
        duckdb_validity_set_row_valid(validity, i.idx_t)
  of DuckType.Timestamp:
    var resultArray = cast[ptr UncheckedArray[int64]](raw)
    for i, e in values.valueTimestamp[rowOffset ..< scanCount]:
      resultArray[i] = e.toTimestamp.micros
      if isValid(values, i):
        duckdb_validity_set_row_valid(validity, i.idx_t)
  of DuckType.Date:
    var resultArray = cast[ptr UncheckedArray[int32]](raw)
    for i, e in values.valueDate[rowOffset ..< scanCount]:
      resultArray[i] = e.toDatetime.days
      if isValid(values, i):
        duckdb_validity_set_row_valid(validity, i.idx_t)
  of DuckType.Time:
    var resultArray = cast[ptr UncheckedArray[int64]](raw)
    for i, e in values.valueTime[rowOffset ..< scanCount]:
      resultArray[i] = e.toTime.micros
      if isValid(values, i):
        duckdb_validity_set_row_valid(validity, i.idx_t)
  of DuckType.Interval:
    var resultArray = cast[ptr UncheckedArray[duckdbInterval]](raw)
    for i, e in values.valueInterval[rowOffset ..< scanCount]:
      resultArray[i] = e.toInterval
      if isValid(values, i):
        duckdb_validity_set_row_valid(validity, i.idx_t)
  of DuckType.HugeInt:
    var resultArray = cast[ptr UncheckedArray[duckdbHugeInt]](raw)
    for i, e in values.valueHugeInt[rowOffset ..< scanCount]:
      resultArray[i] = e.toHugeInt
      if isValid(values, i):
        duckdb_validity_set_row_valid(validity, i.idx_t)
  of DuckType.Varchar:
    for i, e in values.valueVarChar[rowOffset ..< scanCount]:
      duckdb_vector_assign_string_element(vec, i.idx_t, e.cstring)
      if isValid(values, i):
        duckdb_validity_set_row_valid(validity, i.idx_t)
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
  of DuckType.List, DuckType.Array:
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
  of DuckType.TimestampTz:
    discard
  of DuckType.UHugeInt:
    discard

proc bindFunction(info: BindInfo) =
  let
    parameter = info.parameters.toSeq
    name = parameter[0].valueVarchar
    df = cast[ExtraData](info.mainFunction.extraData).data[name]
    data = BindData(df: df)

  duckdbBindSetCardinality(info.handle, len(df).uint64, true)
  for column in df.columns:
    info.addResultColumn(column.name, column.kind)
  GC_ref(data)
  duckdbBindSetBindData(info.handle, cast[ptr BindData](data), destroyBind)

proc initFunction(info: InitInfo) =
  let
    bindInfo = cast[BindData](duckdbInitGetBindData(info.handle))
    maxThreads = ceil(len(bindInfo.df) / ROW_GROUP_SIZE)
  var rowLock: Lock
  initLock rowLock
  let data = GlobalData(pos: 0, lock: rowLock)
  duckdbInitSetMaxThreads(info.handle, maxThreads.idx_t)
  GC_ref(data)
  duckdbInitSetInitData(info.handle, cast[ptr GlobalData](data), destroyGlobalData)

proc initLocalFunction(info: InitInfo) =
  let
    bindInfo = cast[BindData](duckdbInitGetBindData(info.handle))
    data = LocalData(currentPos: 0, endPos: 0, rowCount: bindInfo.df.len)

  GC_ref(data)
  duckdbInitSetInitData(info.handle, cast[ptr LocalData](data), destroyLocalData)

proc mainFunction(info: FunctionInfo, duckdbChunk: duckdbDataChunk) =
  let bindInfo = cast[BindData](duckdbFunctionGetBindData(info))
  var
    globalData = cast[GlobalData](duckdbFunctionGetInitData(info))
    localData = cast[LocalData](duckdbFunctionGetLocalInitData(info))
    chunk = newDataChunk(duckdbChunk, shouldDestroy=false)

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
  for colIdx in 0 ..< chunk.columnCount:
    scanColumn(
      bindInfo.df.values[colIdx], currentRow, scanCount, resultIdx, chunk.handle
    )
    resultIdx += 1

  chunk.setLen(scanCount)

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
