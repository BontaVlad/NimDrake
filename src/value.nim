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

proc newValue*(kind: DuckType, isValid: bool, val: bool): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.Boolean:
    result.valueBoolean = val
  else:
    raise newException(ValueError, "Expected DuckType.Boolean for boolean value")

proc newValue*(kind: DuckType, isValid: bool, val: int8): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.TinyInt:
    result.valueTinyint = val
  else:
    raise newException(ValueError, "Expected DuckType.TinyInt for int8 value")

proc newValue*(kind: DuckType, isValid: bool, val: int16): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.SmallInt:
    result.valueSmallint = val
  else:
    raise newException(ValueError, "Expected DuckType.SmallInt for int16 value")

proc newValue*(kind: DuckType, isValid: bool, val: int32): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.Integer:
    result.valueInteger = val
  else:
    raise newException(ValueError, "Expected DuckType.Integer for int32 value")

proc newValue*(kind: DuckType, isValid: bool, val: int64): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.BigInt:
    result.valueBigint = val
  else:
    raise newException(ValueError, "Expected DuckType.BigInt for int64 value")

proc newValue*(kind: DuckType, isValid: bool, val: Int128): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.HugeInt:
    result.valueHugeint = val
  else:
    raise newException(ValueError, "Expected DuckType.HugeInt for int64 value")

proc newValue*(kind: DuckType, isValid: bool, val: uint8): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.UTinyInt:
    result.valueUTinyint = val
  else:
    raise newException(ValueError, "Expected DuckType.UTinyInt for uint8 value")

proc newValue*(kind: DuckType, isValid: bool, val: uint16): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.USmallInt:
    result.valueUSmallint = val
  else:
    raise newException(ValueError, "Expected DuckType.USmallInt for uint16 value")

proc newValue*(kind: DuckType, isValid: bool, val: uint32): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.UInteger:
    result.valueUInteger = val
  else:
    raise newException(ValueError, "Expected DuckType.UInteger for uint32 value")

proc newValue*(kind: DuckType, isValid: bool, val: uint64): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.UBigInt:
    result.valueUBigint = val
  else:
    raise newException(ValueError, "Expected DuckType.UBigInt for uint64 value")

proc newValue*(kind: DuckType, isValid: bool, val: float32): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.Float:
    result.valueFloat = val
  else:
    raise newException(ValueError, "Expected DuckType.Float for float32 value")

proc newValue*(kind: DuckType, isValid: bool, val: float64): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.Double:
    result.valueDouble = val
  else:
    raise newException(ValueError, "Expected DuckType.Double for float64 value")

proc newValue*(kind: DuckType, isValid: bool, val: DateTime): Value =
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

proc newValue*(kind: DuckType, isValid: bool, val: Time): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.Time:
    result.valueTime = val
  else:
    raise newException(ValueError, "Expected DuckType.Time for Time value")

proc newValue*(kind: DuckType, isValid: bool, val: ZonedTime): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.TimeTz:
    result.valueTimeTz = val
  else:
    raise newException(ValueError, "Expected DuckType.Time for Time value")

proc newValue*(kind: DuckType, isValid: bool, val: TimeInterval): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.Interval:
    result.valueInterval = val
  else:
    raise newException(ValueError, "Expected DuckType.Interval for TimeInterval value")

proc newValue*(kind: DuckType, isValid: bool, val: string): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.Varchar:
    result.valueVarchar = val
  elif kind == DuckType.Bit:
    result.valueBit = val
  else:
    raise newException(ValueError, "Expected DuckType.Varchar or Bit for string value")

proc newValue*(kind: DuckType, isValid: bool, val: seq[byte]): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.Blob:
    result.valueBlob = val
  else:
    raise newException(ValueError, "Expected DuckType.Blob for seq[byte] value")

proc newValue*(kind: DuckType, isValid: bool, val: DecimalType): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.Decimal:
    result.valueDecimal = val
  else:
    raise newException(ValueError, "Expected DuckType.Decimal for DecimalType value")

proc newValue*(kind: DuckType, isValid: bool, val: uint): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.Enum:
    result.valueEnum = val
  else:
    raise newException(ValueError, "Expected DuckType.Enum for uint value")

proc newValue*(kind: DuckType, isValid: bool, val: seq[Value]): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.List:
    result.valueList = val
  else:
    raise newException(ValueError, "Expected DuckType.List for seq[Value] value")

proc newValue*(kind: DuckType, isValid: bool, val: Table[string, Value]): Value =
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

proc newValue*(kind: DuckType, isValid: bool, val: Uuid): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.UUID:
    result.valueUuid = val
  else:
    raise newException(ValueError, "Expected DuckType.Enum for uint value")

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
