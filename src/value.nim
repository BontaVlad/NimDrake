import std/[tables, times, math]
import nint128
import uuid4

import /[types, api]
import /compatibility/decimal_compat

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

proc toHugeInt*(val: Int128): duckdbHugeInt {.inline.} =
  return duckdbHugeInt(lower: val.lo.uint64, upper: val.hi.int64)

proc fromHugeInt*(val: duckdbHugeInt): Int128 {.inline.} =
  return Int128(hi: val.upper.int64, lo: val.lower.uint64)

proc toUHugeInt*(val: UInt128): duckdbUHugeInt {.inline.} =
  return duckdbUHugeInt(lower: val.lo.uint64, upper: val.hi.uint64)

proc fromUHugeInt*(val: duckdbUHugeInt): UInt128 {.inline.} =
  return UInt128(hi: val.upper.uint64, lo: val.lower.uint64)

proc fromTimestamp*(val: int64): Timestamp {.inline.} =
  let
    (seconds, microseconds) = divMod(val, 1_000_000)
    res = utc(fromUnix(seconds)) + initDuration(microseconds = microseconds)
  return Timestamp(res)

proc fromTimestamp*(val: duckdbTimestamp): Timestamp {.inline.} =
  return fromTimestamp(val.micros)

proc toTimestamp*(val: Timestamp): duckdbTimestamp {.inline.} =
  let ms = convert(Seconds, Microseconds, val.toTime.toUnix)
  return duckdb_timestamp(micros: ms)

proc toDatetime*(val: Datetime): duckdbDate {.inline.} =
  let
    timeInfo = val.toTime.inZone(utc())
    unixSeconds = timeInfo.toTime.toUnix
    days = convert(Seconds, Days, unixSeconds)
  return duckdb_date(days: days.int32)

proc fromDatetime*(val: int32): Datetime {.inline.} =
  let seconds = convert(Days, Seconds, val)
  let time = fromUnix(seconds)
  return time.inZone(utc())

proc fromDatetime*(val: duckdbDate): Datetime {.inline.} =
  return fromDatetime(val.days)

proc toTime*(val: Time): duckdbTime {.inline.} =
  let micros = convert(Seconds, Microseconds, val.toUnix)
  return duckdb_time(micros: micros)

proc fromTime*(val: int64): Time {.inline.} =
  return initTime(convert(Microseconds, Seconds, val), 0)

proc fromTime*(val: duckdbTime): Time {.inline.} =
  return fromTime(val.micros)

proc toInterval*(val: TimeInterval): duckdbInterval {.inline.} =
  let micros =
    convert(Hours, Microseconds, val.hours) + convert(
      Minutes, Microseconds, val.minutes
    ) + convert(Seconds, Microseconds, val.seconds) + val.microseconds

  return duckdbInterval(
    months: val.months.int32 + int32(val.years * 12),
    days: val.days.int32,
    micros: micros,
  )

proc fromInterval*(val: duckdbInterval): TimeInterval {.inline.} =
  let
    years = val.months div 12
    months = val.months mod 12
    hours = convert(Microseconds, Hours, val.micros)
    minutes =
      convert(Microseconds, Minutes, val.micros mod convert(Hours, Microseconds, 1))
    seconds =
      convert(Microseconds, Seconds, val.micros mod convert(Minutes, Microseconds, 1))

  return initTimeInterval(
    years = years,
    months = months,
    days = val.days,
    hours = hours,
    minutes = minutes,
    seconds = seconds,
  )

proc `$`*(v: Value): string =
  if not v.isValid:
    return ""
  case v.kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    raise newException(ValueError, "got invalid type")
  of DuckType.Boolean:
    return $v.valueBoolean
  of DuckType.TinyInt:
    return $v.valueTinyint
  of DuckType.SmallInt:
    return $v.valueSmallint
  of DuckType.Integer:
    return $v.valueInteger
  of DuckType.BigInt:
    return $v.valueBigint
  of DuckType.UTinyInt:
    return $v.valueUTinyint
  of DuckType.USmallInt:
    return $v.valueUSmallint
  of DuckType.UInteger:
    return $v.valueUInteger
  of DuckType.UBigInt:
    return $v.valueUBigint
  of DuckType.Float:
    return $v.valueFloat
  of DuckType.Double:
    return $v.valueDouble
  of DuckType.Timestamp:
    return $v.valueTimestamp
  of DuckType.TimestampS:
    return $v.valueTimestampS
  of DuckType.TimestampMs:
    return $v.valueTimestampMs
  of DuckType.TimestampNs:
    return $v.valueTimestampNs
  of DuckType.Date:
    return $v.valueDate
  of DuckType.Time:
    return $v.valueTime
  of DuckType.Interval:
    return $v.valueInterval
  of DuckType.HugeInt:
    return $v.valueHugeint
  of DuckType.Varchar:
    return v.valueVarchar
  of DuckType.Blob:
    return $v.valueBlob
  of DuckType.Decimal:
    return $v.valueDecimal
  of DuckType.Enum:
    return $v.valueEnum
  of DuckType.List, DuckType.Array:
    return $v.valueList
  of DuckType.Struct:
    return $v.valueStruct
  of DuckType.Map:
    return $v.valueMap
  of DuckType.UUID:
    return $v.valueUuid
  of DuckType.Union:
    return $v.valueUnion
  of DuckType.Bit:
    return $v.valueBit
  of DuckType.TimeTz:
    return $v.valueTimeTz
  of DuckType.TimestampTz:
    return $v.valueTimestampTz
  of DuckType.UHugeInt:
    return $v.valueUHugeint

proc newValue*(val: bool, isValid = true): Value =
  return Value(kind: DuckType.Boolean, isValid: isValid, valueBoolean: val)

proc newValue*(val: int8, isValid = true): Value =
  return Value(kind: DuckType.TinyInt, isValid: isValid, valueTinyint: val)

proc newValue*(val: int16, isValid = true): Value =
  return Value(kind: DuckType.SmallInt, isValid: isValid, valueSmallint: val)

proc newValue*(val: int32, isValid = true): Value =
  return Value(kind: DuckType.Integer, isValid: isValid, valueInteger: val)

proc newValue*(val: int64, isValid = true): Value =
  return Value(kind: DuckType.BigInt, isValid: isValid, valueBigint: val)

proc newValue*(val: Int128, isValid = true): Value =
  return Value(kind: DuckType.HugeInt, isValid: isValid, valueHugeInt: val)

proc newValue*(val: UInt128, isValid = true): Value =
  return Value(kind: DuckType.UHugeInt, isValid: isValid, valueUHugeInt: val)

proc newValue*(val: uint8, isValid = true): Value =
  return Value(kind: DuckType.UTinyInt, isValid: isValid, valueUTinyint: val)

proc newValue*(val: uint16, isValid = true): Value =
  return Value(kind: DuckType.USmallInt, isValid: isValid, valueUSmallint: val)

proc newValue*(val: uint32, isValid = true): Value =
  return Value(kind: DuckType.UInteger, isValid: isValid, valueUInteger: val)

proc newValue*(val: uint64, isValid = true): Value =
  return Value(kind: DuckType.UBigInt, isValid: isValid, valueUBigint: val)

proc newValue*(val: float32, isValid = true): Value =
  return Value(kind: DuckType.Float, isValid: isValid, valueFloat: val)

proc newValue*(val: float64, isValid = true): Value =
  return Value(kind: DuckType.Double, isValid: isValid, valueDouble: val)

proc newValue*(val: Timestamp, kind: DuckType, isValid = true): Value =
  return Value(kind: DuckType.Timestamp, isValid: isValid, valueTimestamp: val)

# TODO: this should be refactored
proc newValue*(val: DateTime, kind: DuckType, isValid = true): Value =
  result = Value(kind: kind, isValid: isValid)
  case kind
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

proc newValue*(val: Time, isValid = true): Value =
  return Value(kind: DuckType.Time, isValid: isValid, valueTime: val)

proc newValue*(val: ZonedTime, isValid = true): Value =
  return Value(kind: DuckType.TimeTz, isValid: isValid, valueTimeTz: val)

proc newValue*(val: TimeInterval, isValid = true): Value =
  return Value(kind: DuckType.Interval, isValid: isValid, valueInterval: val)

proc newValue*(val: string, isValid = true): Value =
  return Value(kind: DuckType.Varchar, isValid: isValid, valueVarchar: val)

proc newValue*(val: string, kind: DuckType, isValid = true): Value =
  result = Value(kind: kind, isValid: isValid)
  if kind == DuckType.Bit:
    result.valueBit = val
  else:
    raise newException(
      ValueError, "Expected DuckType.Bit for string value with kind specified"
    )

proc newValue*(val: seq[byte], isValid = true): Value =
  return Value(kind: DuckType.Blob, isValid: isValid, valueBlob: val)

proc newValue*(val: DecimalType, isValid = true): Value =
  return Value(kind: DuckType.Decimal, isValid: isValid, valueDecimal: val)

proc newValue*(val: uint, kind: DuckType, isValid = true): Value =
  return Value(kind: DuckType.Enum, isValid: isValid, valueEnum: val)

proc newValue*(val: seq[Value], isValid = true): Value =
  return Value(kind: DuckType.List, isValid: isValid, valueList: val)

proc newValue*(val: Table[string, Value], kind: DuckType, isValid = true): Value =
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

proc newValue*(val: Uuid, isValid = true): Value =
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
    kind = toEnum[DuckType](logicalId.int)

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
    let dkTimestamp = cast[duckdb_timestamp](duckdb_get_timestamp(val.handle))
    result.valueTimestamp = fromTimestamp(dkTimestamp)
  of DuckType.TimestampS:
    raise newException(ValueError, "TimestampS not implemented")
  of DuckType.TimestampMs:
    raise newException(ValueError, "TimestampMS not implemented")
  of DuckType.TimestampNs:
    raise newException(ValueError, "TimestampNS not implemented")
  of DuckType.Date:
    let dkDate = cast[duckdb_date](duckdb_get_date(val.handle))
    result.valueDate = fromDatetime(dkDate)
  of DuckType.Time:
    let dkTime = cast[duckdb_time](duckdb_get_time(val.handle))
    result.valueTime = fromTime(dkTime)
  of DuckType.Interval:
    let dkInterval = cast[duckdb_interval](duckdb_get_interval(val.handle))
    result.valueInterval = dkInterval.fromInterval
  of DuckType.HugeInt:
    let dkHugeInt = cast[duckdb_hugeint](duckdb_get_hugeint(val.handle))
    result.valueHugeint = fromHugeInt(dkHugeInt)
  of DuckType.Varchar:
    result.valueVarchar = $newDuckString(duckdbGetVarchar(val.handle))
  of DuckType.Blob:
    result.valueBlob = cast[seq[byte]](val.handle)
  of DuckType.Decimal:
    let
      logicalType = duckdb_get_value_type(val.handle)
      scale = duckdb_decimal_scale(logicalType).int
      width = duckdb_decimal_width(logicalType).int
    if width <= 18:
      let value = duckdb_get_double(val.handle) / pow(10.float, scale.float)
      result.valueDecimal = newDecimal($value)
    else:
      raise newException(ValueError, "I don't like implementing this atm")
    # result.valueDecimal = duckdb_get_double(val.handle)
  of DuckType.Enum:
    discard
    # result.valueEnum = parseEnum[EnumType](v)
  of DuckType.List, DuckType.Array:
    discard
    # result.valueList = parseJson(v).to(seq[Value])
  of DuckType.Struct:
    discard
    # result.valueStruct = parseJson(v).to(StructType)
  of DuckType.Map:
    result.valueMap = initTable[string, Value]()
    let mapSize = duckdb_get_map_size(val.handle)
    for i in 0 .. mapSize:
      let
        key = newValue(newDuckValue(duckdb_get_map_key(val.handle, i.idx_t)))
        value = newValue(newDuckValue(duckdb_get_map_value(val.handle, i.idx_t)))
      result.valueMap[key.valueVarchar] = value

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
  of DuckType.TimestampTz:
    discard
    # result.valueTimeTz = parseTimeTz(v)
  of DuckType.UHugeInt:
    discard
    # result.valueTimeTz = parseTimeTz(v)

proc toNativeValue*(val: Value): DuckValue =
  result = DuckValue()
  case val.kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    raise newException(ValueError, "got invalid type")
  of DuckType.Boolean:
    return newDuckValue(duckdb_create_bool(val.valueBoolean))
  of DuckType.TinyInt:
    return newDuckValue(duckdb_create_int8(val.valueTinyint))
  of DuckType.SmallInt:
    return newDuckValue(duckdb_create_int16(val.valueSmallInt))
  of DuckType.Integer:
    return newDuckValue(duckdb_create_int32(val.valueInteger))
  of DuckType.BigInt:
    return newDuckValue(duckdb_create_int64(val.valueBigint))
  of DuckType.UTinyInt:
    return newDuckValue(duckdb_create_uint8(val.valueUTinyint))
  of DuckType.USmallInt:
    return newDuckValue(duckdb_create_uint16(val.valueUSmallint))
  of DuckType.UInteger:
    return newDuckValue(duckdb_create_uint32(val.valueUInteger.cuint))
  of DuckType.UBigInt:
    return newDuckValue(duckdb_create_uint64(val.valueUBigint))
  of DuckType.Float:
    return newDuckValue(duckdb_create_float(val.valueFloat))
  of DuckType.Double:
    return newDuckValue(duckdb_create_double(val.valueDouble))
  of DuckType.Timestamp:
    return newDuckValue(duckdb_create_timestamp(toTimestamp(val.valueTimestamp)))
  of DuckType.TimestampS:
    discard
  #   # result.valueTimestampS = fromUnix(v.parseInt)
  of DuckType.TimestampMs:
    discard
  #   # result.valueTimestampMs = fromUnixMilli(v.parseInt)
  of DuckType.TimestampNs:
    discard
  #   # result.valueTimestampNs = fromUnixNano(v.parseInt)
  of DuckType.Date:
    return newDuckValue(duckdb_create_date(val.valueDate.toDatetime))
  of DuckType.Time:
    return newDuckValue(duckdb_create_time(val.valueTime.toTime))
  of DuckType.Interval:
    return newDuckValue(duckdb_create_interval(val.valueInterval.toInterval))
  else:
    discard
  # of DuckType.HugeInt:
  #   discard
  #   # result.valueHugeint = parseHugeInt(v)
  # of DuckType.Varchar:
  #   result.valueVarchar = $newDuckString(duckdbGetVarchar(val.handle))
  # of DuckType.Blob:
  #   result.valueBlob = cast[seq[byte]](val.handle)
  # of DuckType.Decimal:
  #   discard
  #   # result.valueDecimal = parseDecimal(v)
  # of DuckType.Enum:
  #   discard
  #   # result.valueEnum = parseEnum[EnumType](v)
  # of DuckType.List:
  #   discard
  #   # result.valueList = parseJson(v).to(seq[Value])
  # of DuckType.Struct:
  #   discard
  #   # result.valueStruct = parseJson(v).to(StructType)
  # of DuckType.Map:
  #   discard
  #   # result.valueMap = parseJson(v).to(Table[string, Value])
  # of DuckType.UUID:
  #   discard
  #   # result.valueUuid = parseUUID(v)
  # of DuckType.Union:
  #   discard
  #   # result.valueUnion = parseJson(v).to(UnionType)
  # of DuckType.Bit:
  #   discard
  #   # result.valueBit = v.parseBinaryInt.uint8
  # of DuckType.TimeTz:
  #   discard
  #   # result.valueTimeTz = parseTimeTz(v)
