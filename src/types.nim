import std/[macros, tables, times, typetraits, strformat]

import nint128
import uuid4

import /[ffi]
import /compatibility/decimal_compat

const
  BITS_PER_VALUE* = 64
  STRING_INLINE_LENGTH* = 12
  SECONDS_PER_DAY* = 86400

type
  Timestamp* {.borrow: `.`.} = distinct DateTime
  ValidityMask* = object
    handle*: ptr UncheckedArray[uint64]
    size*: int

  Statement* = distinct ptr duckdbPreparedStatement
  PendingQueryResult* = distinct ptr duckdbPendingResult
  QueryResult* = object of duckdbResult

  DuckType* {.pure.} = enum
    Invalid = enum_DUCKDB_TYPE.DUCKDB_TYPE_INVALID
    Boolean = enum_DUCKDB_TYPE.DUCKDB_TYPE_BOOLEAN
    TinyInt = enum_DUCKDB_TYPE.DUCKDB_TYPE_TINYINT
    SmallInt = enum_DUCKDB_TYPE.DUCKDB_TYPE_SMALLINT
    Integer = enum_DUCKDB_TYPE.DUCKDB_TYPE_INTEGER
    BigInt = enum_DUCKDB_TYPE.DUCKDB_TYPE_BIGINT
    UTinyInt = enum_DUCKDB_TYPE.DUCKDB_TYPE_UTINYINT
    USmallInt = enum_DUCKDB_TYPE.DUCKDB_TYPE_USMALLINT
    UInteger = enum_DUCKDB_TYPE.DUCKDB_TYPE_UINTEGER
    UBigInt = enum_DUCKDB_TYPE.DUCKDB_TYPE_UBIGINT
    Float = enum_DUCKDB_TYPE.DUCKDB_TYPE_FLOAT
    Double = enum_DUCKDB_TYPE.DUCKDB_TYPE_DOUBLE
    Timestamp = enum_DUCKDB_TYPE.DUCKDB_TYPE_TIMESTAMP
    Date = enum_DUCKDB_TYPE.DUCKDB_TYPE_DATE
    Time = enum_DUCKDB_TYPE.DUCKDB_TYPE_TIME
    Interval = enum_DUCKDB_TYPE.DUCKDB_TYPE_INTERVAL
    HugeInt = enum_DUCKDB_TYPE.DUCKDB_TYPE_HUGEINT
    Varchar = enum_DUCKDB_TYPE.DUCKDB_TYPE_VARCHAR
    Blob = enum_DUCKDB_TYPE.DUCKDB_TYPE_BLOB
    Decimal = enum_DUCKDB_TYPE.DUCKDB_TYPE_DECIMAL
    TimestampS = enum_DUCKDB_TYPE.DUCKDB_TYPE_TIMESTAMP_S
    TimestampMs = enum_DUCKDB_TYPE.DUCKDB_TYPE_TIMESTAMP_MS
    TimestampNs = enum_DUCKDB_TYPE.DUCKDB_TYPE_TIMESTAMP_NS
    Enum = enum_DUCKDB_TYPE.DUCKDB_TYPE_ENUM
    List = enum_DUCKDB_TYPE.DUCKDB_TYPE_LIST
    Struct = enum_DUCKDB_TYPE.DUCKDB_TYPE_STRUCT
    Map = enum_DUCKDB_TYPE.DUCKDB_TYPE_MAP
    UUID = enum_DUCKDB_TYPE.DUCKDB_TYPE_UUID
    Union = enum_DUCKDB_TYPE.DUCKDB_TYPE_UNION
    Bit = enum_DUCKDB_TYPE.DUCKDB_TYPE_BIT
    TimeTz = enum_DUCKDB_TYPE.DUCKDB_TYPE_TIME_TZ
    TimestampTz = enum_DUCKDB_TYPE.DUCKDB_TYPE_TIMESTAMP_TZ # Added
    UHugeInt = enum_DUCKDB_TYPE.DUCKDB_TYPE_UHUGEINT # Added
    Array = enum_DUCKDB_TYPE.DUCKDB_TYPE_ARRAY # Added
    Any = enum_DUCKDB_TYPE.DUCKDB_TYPE_ANY
    SqlNull = enum_DUCKDB_TYPE.DUCKDB_TYPE_SQLNULL

  ValueBase = object of RootObj
    isValid*: bool
    case kind*: DuckType
    of DuckType.Invalid, DuckType.Any, DuckType.SqlNull:
      valueInvalid*: uint8
    of DuckType.Boolean: valueBoolean*: bool
    of DuckType.TinyInt: valueTinyint*: int8
    of DuckType.SmallInt: valueSmallint*: int16
    of DuckType.Integer: valueInteger*: int32
    of DuckType.BigInt: valueBigint*: int64
    of DuckType.UTinyInt: valueUTinyint*: uint8
    of DuckType.USmallInt: valueUSmallint*: uint16
    of DuckType.UInteger: valueUInteger*: uint32
    of DuckType.UBigInt: valueUBigint*: uint64
    of DuckType.Float: valueFloat*: float32
    of DuckType.Double: valueDouble*: float64
    of DuckType.Timestamp: valueTimestamp*: Timestamp
    of DuckType.Date: valueDate*: DateTime
    of DuckType.Time: valueTime*: Time
    of DuckType.Interval: valueInterval*: TimeInterval
    of DuckType.HugeInt: valueHugeint*: Int128
    of DuckType.Varchar: valueVarchar*: string
    of DuckType.Blob: valueBlob*: seq[byte]
    of DuckType.Decimal: valueDecimal*: DecimalType
    of DuckType.TimestampS: valueTimestampS*: DateTime
    of DuckType.TimestampMs: valueTimestampMs*: DateTime
    of DuckType.TimestampNs: valueTimestampNs*: DateTime
    of DuckType.Enum: valueEnum*: uint
    of DuckType.List, DuckType.Array: valueList*: seq[Value]
    of DuckType.Struct: valueStruct*: Table[string, Value]
    of DuckType.Map: valueMap*: Table[string, Value]
    of DuckType.UUID: valueUUID*: Uuid
    of DuckType.Union: valueUnion*: Table[string, Value]
    of DuckType.Bit: valueBit*: string
    of DuckType.TimeTz: valueTimeTz*: ZonedTime
    of DuckType.TimestampTz: valueTimestampTz*: ZonedTime
    of DuckType.UHugeInt: valueUHugeint*: UInt128

  Value* = ref object of ValueBase

  Vector* = ref object
    mask*: seq[uint64] = newSeq[uint64]()
    case kind*: DuckType
    of DuckType.Invalid, DuckType.Any, DuckType.SqlNull:
      valueInvalid*: uint8
    of DuckType.Boolean: valueBoolean*: seq[bool]
    of DuckType.TinyInt: valueTinyint*: seq[int8]
    of DuckType.SmallInt: valueSmallint*: seq[int16]
    of DuckType.Integer: valueInteger*: seq[int32]
    of DuckType.BigInt: valueBigint*: seq[int64]
    of DuckType.UTinyInt: valueUTinyint*: seq[uint8]
    of DuckType.USmallInt: valueUSmallint*: seq[uint16]
    of DuckType.UInteger: valueUInteger*: seq[uint32]
    of DuckType.UBigInt: valueUBigint*: seq[uint64]
    of DuckType.Float: valueFloat*: seq[float32]
    of DuckType.Double: valueDouble*: seq[float64]
    of DuckType.Timestamp: valueTimestamp*: seq[Timestamp]
    of DuckType.Date: valueDate*: seq[DateTime]
    of DuckType.Time: valueTime*: seq[Time]
    of DuckType.Interval: valueInterval*: seq[TimeInterval]
    of DuckType.HugeInt: valueHugeint*: seq[Int128]
    of DuckType.Varchar: valueVarchar*: seq[string]
    of DuckType.Blob: valueBlob*: seq[seq[byte]]
    of DuckType.Decimal: valueDecimal*: seq[DecimalType]
    of DuckType.TimestampS: valueTimestampS*: seq[DateTime]
    of DuckType.TimestampMs: valueTimestampMs*: seq[DateTime]
    of DuckType.TimestampNs: valueTimestampNs*: seq[DateTime]
    of DuckType.Enum: valueEnum*: seq[uint]
    of DuckType.List, DuckType.Array: valueList*: seq[seq[Value]]
    of DuckType.Struct: valueStruct*: seq[Table[string, Value]]
    of DuckType.Map: valueMap*: seq[Table[string, Value]]
    of DuckType.UUID: valueUUID*: seq[Uuid]
    of DuckType.Union: valueUnion*: seq[Table[string, Value]]
    of DuckType.Bit: valueBit*: seq[string]
    of DuckType.TimeTz: valueTimeTz*: seq[ZonedTime]
    of DuckType.TimestampTz: valueTimestampTz*: seq[ZonedTime]
    of DuckType.UHugeInt: valueUHugeint*: seq[UInt128]

  LogicalTypeBase* = object of RootObj
    handle*: duckdbLogicalType

  LogicalType* = ref object of LogicalTypeBase

  Column* = ref object
    idx*: int
    name*: string
    kind*: DuckType

proc `=destroy`*(statement: Statement) =
  ## Destroys a prepared statement instance if it exists
  if cast[ptr duckdbPreparedStatement](statement) != nil:
    duckdbDestroyPrepare(cast[ptr duckdbPreparedStatement](statement.addr))

proc `=copy`*(dest: var Statement, source: Statement) {.error.}
proc `=dup`*(statement: Statement): Statement {.error.}

proc `=wasMoved`*(statement: var Statement) =
  statement = Statement(nil)

proc `=destroy`*(ltp: LogicalTypeBase) =
  if ltp.handle != nil:
    duckdbDestroyLogicalType(ltp.handle.addr)

proc `=wasMoved`*(ltp: var LogicalTypeBase) =
  ltp.handle = nil

proc `=destroy`*(qresult: QueryResult) =
  if qresult.internal_data != nil:
    duckdbDestroyResult(qresult.addr)

proc `=wasMoved`*(qresult: var QueryResult) =
  qresult.internal_data = nil

proc `=copy`*(dest: var QueryResult, source: QueryResult) {.error.}
proc `=dup`*(qresult: QueryResult): QueryResult {.error.}

proc `=destroy`*(pqresult: PendingQueryResult) =
  if cast[ptr duckdbPendingResult](pqresult) != nil:
    duckdbDestroyPending(cast[ptr duckdbPendingResult](pqresult.addr))

proc `=copy`*(dest: var PendingQueryResult, source: PendingQueryResult) {.error.}
proc `=dup`*(pqresult: PendingQueryResult): PendingQueryResult {.error.}

proc `=wasMoved`*(pqresult: var PendingQueryResult) =
  pqresult = PendingQueryResult(nil)

converter toBase*(s: ptr Statement): ptr duckdbPreparedStatement =
  cast[ptr duckdbPreparedStatement](s)

converter toBase*(s: Statement): duckdbPreparedStatement =
  cast[duckdbPreparedStatement](s)

converter toBase*(p: ptr PendingQueryResult): ptr duckdbPendingResult =
  cast[ptr duckdbPendingResult](p)

converter toBase*(p: PendingQueryResult): duckdbPendingResult =
  cast[duckdbPendingResult](p)

proc `$`*(x: Timestamp): string =
  $DateTime(x)

proc toTime*(x: Timestamp): Time {.borrow.}
proc `==`*(x, y: Timestamp): bool {.borrow.}
proc format*(dt: Timestamp, f: string): string =
  return DateTime(dt).format(f)

proc newValidityMask*(): ValidityMask =
  return ValidityMask(size: 0, handle: nil)

proc newValidityMask*(
    vec: duckdb_vector, size: int, isWritable: bool = false
): ValidityMask =
  let numEntries = (size + BITS_PER_VALUE - 1) div BITS_PER_VALUE

  if isWritable:
    duckdbVectorEnsureValidityWritable(vec)

  let raw = cast[ptr UncheckedArray[uint64]](duckdb_vector_get_validity(vec))
  return ValidityMask(handle: raw, size: numEntries)

template toEnum*[T](x: int): T =
  if x in T.low.int .. T.high.int:
    cast[T](x)
  else:
    raise newException(ValueError, "Value not convertible to enum")

proc isValid*(validity: ValidityMask, idx: int): bool {.inline.} =
  if isNil(validity.handle):
    return true

  let
    entryIdx = idx div BITS_PER_VALUE
    indexInEntry = idx mod BITS_PER_VALUE

  if entryIdx >= validity.size:
    raise newException(ValueError, fmt"Idx {idx} not in 0 .. {validity.size}")

  return (validity.handle[entryIdx] and (1'u64 shl indexInEntry)) != 0

proc setValidity*(validity: ValidityMask, rowIdx: int, isValid: bool) =
  duckdb_validity_set_row_validity(validity.handle[0].addr, rowIdx.idx_t, isValid)

proc newDuckType*(i: duckdb_logical_type): DuckType =
  let id = duckdbGetTypeId(i)
  return toEnum[DuckType](id.int)

proc newDuckType*(i: LogicalType): DuckType =
  return newDuckType(i.handle)

proc newDuckType*(i: enum_DUCKDB_TYPE): DuckType =
  result = toEnum[DuckType](i.int)

proc newDuckType*[T](t: typedesc[T]): DuckType =
  when T is bool:
    DuckType.Boolean
  elif T is int8:
    DuckType.TinyInt
  elif T is int16:
    DuckType.SmallInt
  elif T is int32 | int:
    DuckType.Integer
  elif T is int64:
    DuckType.BigInt
  elif T is uint8:
    DuckType.UTinyInt
  elif T is uint16:
    DuckType.USmallInt
  elif T is uint32:
    DuckType.UInteger
  elif T is uint64:
    DuckType.UBigInt
  elif T is float32:
    DuckType.Float
  elif T is float64:
    DuckType.Double
  elif T is string:
    DuckType.Varchar
  elif T is seq[byte]:
    DuckType.Blob
  elif T is Time:
    DuckType.Time
  elif T is DateTime:
    DuckType.Timestamp
  elif T is tuple:
    DuckType.Struct
  elif T is seq:
    DuckType.List
  elif T is void:
    DuckType.SqlNull
  else:
    DuckType.Invalid

proc newDuckType*(node: NimNode): DuckType =
  let kind = node.strVal
  case kind
  of "bool":
    result = newDuckType(bool)
  of "int8":
    result = newDuckType(int8)
  of "int16":
    result = newDuckType(int16)
  of "int32", "int":
    result = newDuckType(int32)
  of "int64":
    result = newDuckType(int64)
  of "uint8":
    result = newDuckType(uint8)
  of "uint16":
    result = newDuckType(uint16)
  of "uint32":
    result = newDuckType(uint32)
  of "uint64":
    result = newDuckType(uint64)
  of "float32":
    result = newDuckType(float32)
  of "float64", "float":
    result = newDuckType(float64)
  of "string":
    result = newDuckType(string)
  of "seq[byte]":
    result = newDuckType(seq[byte])
  of "Time":
    result = newDuckType(Time)
  of "DateTime":
    result = newDuckType(DateTime)
  of "tuple":
    result = newDuckType(tuple)
  of "seq":
    result = newDuckType(seq)
  of "void":
    result = newDuckType(void)
  else:
    raise newException(ValueError, fmt"invalid type {kind}")

proc newLogicalType*(i: duckdb_logical_type): LogicalType =
  result = LogicalType(handle: i)

proc newLogicalType*(pt: DuckType): LogicalType =
  # Returns an invalid logical type, if type is complex
  # TODO: why do I need to cast it to duckdb_type, maybe from distinct
  let tp = cast[duckdb_type](pt)
  let handle = duckdb_create_logical_type(tp)
  result = newLogicalType(handle)

proc `$`*(ltp: LogicalType): string =
  # returns nil for complext tipes
  result = $newDuckType(ltp)
