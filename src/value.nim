import std/[tables, times, math]
import nint128
import decimal
import uuid4

import /[types, api]

type
  DuckValueBase = object of RootObj
    handle*: duckdb_value

  DuckValue* = ref object of DuckValueBase
  DuckStringBase* = object of RootObj
    internal: cstring

  DuckString* = ref object of DuckStringBase

proc `=destroy`(v: DuckValueBase) =
  if not isNil(v.addr) and not isNil(v.handle):
    duckdb_destroy_value(v.handle.addr)

proc newDuckValue*(handle: duckdb_value): DuckValue =
  result = DuckValue(handle: handle)

proc `=destroy`(dstr: DuckStringBase) =
  if not isNil(dstr.addr):
    duckdbFree(dstr.internal)

proc `$`*(dstr: DuckString): string =
  if isNil(dstr.internal):
    # TODO: maybe "" instead of Nill?
    return "Nill"
  result = $dstr.internal

proc newDuckString*(str: cstring): DuckString =
  result = DuckString(internal: str)

proc `$`*(v: Value): string =
  if not v.isValid:
    return ""
  case v.kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    raise newException(ValueError, "got invalid type")
  of DuckType.Boolean:
    result = $v.valueBoolean
  of DuckType.TinyInt:
    result = $v.valueTinyint
  of DuckType.SmallInt:
    result = $v.valueSmallint
  of DuckType.Integer:
    result = $v.valueInteger
  of DuckType.BigInt:
    result = $v.valueBigint
  of DuckType.UTinyInt:
    result = $v.valueUTinyint
  of DuckType.USmallInt:
    result = $v.valueUSmallint
  of DuckType.UInteger:
    result = $v.valueUInteger
  of DuckType.UBigInt:
    result = $v.valueUBigint
  of DuckType.Float:
    result = $v.valueFloat
  of DuckType.Double:
    result = $v.valueDouble
  of DuckType.Timestamp:
    result = $v.valueTimestamp
  of DuckType.TimestampS:
    result = $v.valueTimestampS
  of DuckType.TimestampMs:
    result = $v.valueTimestampMs
  of DuckType.TimestampNs:
    result = $v.valueTimestampNs
  of DuckType.Date:
    result = $v.valueDate
  of DuckType.Time:
    result = $v.valueTime
  of DuckType.Interval:
    result = $v.valueInterval
  of DuckType.HugeInt:
    result = $v.valueHugeint
  of DuckType.Varchar:
    result = v.valueVarchar
  of DuckType.Blob:
    result = $v.valueBlob
  of DuckType.Decimal:
    result = $v.valueDecimal
  of DuckType.Enum:
    result = $v.valueEnum
  of DuckType.List:
    result = $v.valueList
  of DuckType.Struct:
    result = $v.valueStruct
  of DuckType.Map:
    result = $v.valueMap
  of DuckType.UUID:
    result = $v.valueUuid
  of DuckType.Union:
    result = $v.valueUnion
  of DuckType.Bit:
    result = $v.valueBit
  of DuckType.TimeTz:
    result = $v.valueTimeTz

proc newValue*(val: bool, isValid=true): Value =
  result = Value(kind: DuckType.Boolean, isValid: isValid, valueBoolean: val)

proc newValue*(val: int8, isValid=true): Value =
  result = Value(kind: DuckType.TinyInt, isValid: isValid, valueTinyint: val)

proc newValue*(val: int16, isValid=true): Value =
  result = Value(kind: DuckType.SmallInt, isValid: isValid, valueSmallint: val)

proc newValue*(val: int32, isValid=true): Value =
  result = Value(kind: DuckType.Integer, isValid: isValid, valueInteger: val)

proc newValue*(val: int64, isValid=true): Value =
  result = Value(kind: DuckType.BigInt, isValid: isValid, valueBigint: val)

proc newValue*(val: Int128, isValid=true): Value =
  result = Value(kind: DuckType.HugeInt, isValid: isValid, valueHugeInt: val)

proc newValue*(val: uint8, isValid=true): Value =
  result = Value(kind: DuckType.UTinyInt, isValid: isValid, valueUTinyint: val)

proc newValue*(val: uint16, isValid=true): Value =
  result = Value(kind: DuckType.USmallInt, isValid: isValid, valueUSmallint: val)

proc newValue*(val: uint32, isValid=true): Value =
  result = Value(kind: DuckType.UInteger, isValid: isValid, valueUInteger: val)

proc newValue*(val: uint64, isValid=true): Value =
  result = Value(kind: DuckType.UBigInt, isValid: isValid, valueUBigint: val)

proc newValue*(val: float32, isValid=true): Value =
  result = Value(kind: DuckType.Float, isValid: isValid, valueFloat: val)

proc newValue*(val: float64, isValid=true): Value =
  result = Value(kind: DuckType.Double, isValid: isValid, valueDouble: val)

proc newValue*(val: DateTime, kind: DuckType, isValid=true): Value =
  result = Value(kind: kind, isValid: isValid)
  case kind
  of DuckType.Timestamp:
    result.valueTimestamp = val
  of DuckType.TimestampS:
    result.valueTimestampS = val
  of DuckType.TimestampMs:
    result.valueTimestampMs = val
  of DuckType.TimestampNs:
    result.valueTimestampNs = val
  of DuckType.Date:
    result.valueDate = val
  else:
    raise newException(
      ValueError, "Expected DuckType.Timestamp, Date, or Timestamp variants"
    )

proc newValue*(val: Time, isValid=true): Value =
  result = Value(kind: DuckType.Time, isValid: isValid, valueTime: val)

proc newValue*(val: ZonedTime, isValid=true): Value =
  result = Value(kind: DuckType.TimeTz, isValid: isValid, valueTimeTz: val)

proc newValue*(val: TimeInterval, isValid=true): Value =
  result = Value(kind: DuckType.Interval, isValid: isValid, valueInterval: val)

proc newValue*(val: string, isValid=true): Value =
  result = Value(kind: DuckType.Varchar, isValid: isValid, valueVarchar: val)

proc newValue*(val: string, kind: DuckType, isValid=true): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.Bit:
    result.valueBit = val
  else:
    raise newException(ValueError, "Expected DuckType.Bit for string value with kind specified")

proc newValue*(val: seq[byte], isValid=true): Value =
  result = Value(kind: DuckType.Blob, isValid: isValid, valueBlob: val)

proc newValue*(val: DecimalType, isValid=true): Value =
  result = Value(kind: DuckType.Decimal, isValid: isValid, valueDecimal: val)

proc newValue*(val: uint, kind: DuckType, isValid=true): Value =
  result = Value(kind: DuckType.Enum, isValid: isValid, valueEnum: val)

proc newValue*(val: seq[Value], isValid=true): Value =
  result = Value(kind: DuckType.List, isValid: isValid, valueList: val)

proc newValue*(val: Table[string, Value], kind: DuckType, isValid=true): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.Struct:
    result.valueStruct = val
  elif kind == DuckType.Map:
    result.valueMap = val
  elif kind == DuckType.Union:
    result.valueUnion = val
  else:
    raise newException(
      ValueError,
      "Expected DuckType.Struct or Map or Union for Table[string, Value] value",
    )

proc newValue*(val: Uuid, isValid=true): Value =
  result = Value(kind: DuckType.UUID, isValid: isValid, valueUuid: val)

# Default constructor for Invalid type
proc newValue*(kind: DuckType, isValid: bool): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.Invalid:
    result.valueInvalid = 0
  else:
    raise newException(ValueError, "Expected DuckType.Invalid for default value")

proc newValue*(val: DuckValue): Value =
  # we avoid creating a LogicalType because this
  # one should not be garbadge collected
  let
    logicalTp = duckdb_get_value_type(val.handle)
    logicalId = duckdb_get_type_id(logicalTp)
    kind = DuckType(ord(logicalId))

  # TODO: get the actual isValid value
  result = Value(kind: kind, isValid: true)
  case result.kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    raise newException(ValueError, "got invalid type")
  of DuckType.Boolean:
    result.valueBoolean = duckdb_get_bool(val.handle).bool
  of DuckType.TinyInt:
    result.valueTinyint = duckdb_get_int8(val.handle).int8
  of DuckType.SmallInt:
    result.valueSmallint = duckdb_get_int16(val.handle).int16
  of DuckType.Integer:
    result.valueInteger = duckdb_get_int32(val.handle).int32
  of DuckType.BigInt:
    result.valueBigint = duckdb_get_int64(val.handle)
  of DuckType.UTinyInt:
    result.valueUTinyint = duckdb_get_uint8(val.handle).uint8
  of DuckType.USmallInt:
    result.valueUSmallint = duckdb_get_uint16(val.handle).uint16
  of DuckType.UInteger:
    result.valueUInteger = duckdb_get_uint32(val.handle).uint32
  of DuckType.UBigInt:
    result.valueUBigint = duckdb_get_uint64(val.handle).uint64
  of DuckType.Float:
    result.valueFloat = duckdb_get_float(val.handle).float32
  of DuckType.Double:
    result.valueDouble = duckdb_get_double(val.handle).float64
  of DuckType.Timestamp:
    discard
    # result.valueTimestamp = parse(v, "yyyy-MM-dd HH:mm:ss")
  of DuckType.TimestampS:
    discard
    # result.valueTimestampS = fromUnix(v.parseInt)
  of DuckType.TimestampMs:
    discard
    # result.valueTimestampMs = fromUnixMilli(v.parseInt)
  of DuckType.TimestampNs:
    discard
    # result.valueTimestampNs = fromUnixNano(v.parseInt)
  of DuckType.Date:
    discard
    # result.valueDate = parse(v, "yyyy-MM-dd").toDate
  of DuckType.Time:
    discard
    # result.valueTime = parse(v, "HH:mm:ss").toTime
  of DuckType.Interval:
    discard
    # result.valueInterval = parseDuration(v)
  of DuckType.HugeInt:
    discard
    # result.valueHugeint = parseHugeInt(v)
  of DuckType.Varchar:
    result.valueVarchar = $newDuckString(duckdbGetVarchar(val.handle))
  of DuckType.Blob:
    result.valueBlob = cast[seq[byte]](val.handle)
  of DuckType.Decimal:
    discard
    # result.valueDecimal = parseDecimal(v)
  of DuckType.Enum:
    discard
    # result.valueEnum = parseEnum[EnumType](v)
  of DuckType.List:
    discard
    # result.valueList = parseJson(v).to(seq[Value])
  of DuckType.Struct:
    discard
    # result.valueStruct = parseJson(v).to(StructType)
  of DuckType.Map:
    discard
    # result.valueMap = parseJson(v).to(Table[string, Value])
  of DuckType.UUID:
    discard
    # result.valueUuid = parseUUID(v)
  of DuckType.Union:
    discard
    # result.valueUnion = parseJson(v).to(UnionType)
  of DuckType.Bit:
    discard
    # result.valueBit = v.parseBinaryInt.uint8
  of DuckType.TimeTz:
    discard
    # result.valueTimeTz = parseTimeTz(v)
