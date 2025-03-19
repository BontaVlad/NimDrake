# {.experimental: "codeReordering".}
import std/[tables, times, math, strformat, sequtils, sugar, typetraits]

import nint128
import decimal
import uuid4

import /[api, value, types]

proc `$`*(vector: Vector): string =
  case vector.kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    result = $vector.valueInvalid
  of DuckType.Boolean:
    result = $vector.valueBoolean
  of DuckType.TinyInt:
    result = $vector.valueTinyint
  of DuckType.SmallInt:
    result = $vector.valueSmallint
  of DuckType.Integer:
    result = $vector.valueInteger
  of DuckType.BigInt:
    result = $vector.valueBigint
  of DuckType.UTinyInt:
    result = $vector.valueUtinyint
  of DuckType.USmallInt:
    result = $vector.valueUsmallint
  of DuckType.UInteger:
    result = $vector.valueUinteger
  of DuckType.UBigInt:
    result = $vector.valueUbigint
  of DuckType.Float:
    result = $vector.valueFloat
  of DuckType.Double:
    result = $vector.valueDouble
  of DuckType.Timestamp:
    result = $vector.valueTimestamp
  of DuckType.Date:
    result = $vector.valueDate
  of DuckType.Time:
    result = $vector.valueTime
  of DuckType.Interval:
    result = $vector.valueInterval
  of DuckType.HugeInt:
    result = $vector.valueHugeInt
  of DuckType.VarChar:
    result = $vector.valueVarchar
  of DuckType.Blob:
    result = $vector.valueBlob
  of DuckType.Decimal:
    result = $vector.valueDecimal
  of DuckType.TimestampS:
    result = $vector.valueTimestampS
  of DuckType.TimestampMs:
    result = $vector.valueTimestampMs
  of DuckType.TimestampNs:
    result = $vector.valueTimestampNs
  of DuckType.Enum:
    result = $vector.valueEnum
  of DuckType.List, DuckType.Array:
    result = $vector.valueList
  of DuckType.Struct:
    result = $vector.valueStruct
  of DuckType.Map:
    result = $vector.valueMap
  of DuckType.Uuid:
    result = $vector.valueUuid
  of DuckType.Union:
    result = $vector.valueUnion
  of DuckType.Bit:
    result = $vector.valueBit
  of DuckType.TimeTz:
    result = $vector.valueTimeTz
  of DuckType.TimestampTz:
    result = $vector.valueTimestampTz
  of DuckType.UHugeInt:
    result = $vector.valueUHugeInt

proc len*(vec: Vector): int =
  case vec.kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    result = 0
  of DuckType.Boolean:
    result = vec.valueBoolean.len
  of DuckType.TinyInt:
    result = vec.valueTinyint.len
  of DuckType.SmallInt:
    result = vec.valueSmallint.len
  of DuckType.Integer:
    result = vec.valueInteger.len
  of DuckType.BigInt:
    result = vec.valueBigint.len
  of DuckType.UTinyInt:
    result = vec.valueUTinyint.len
  of DuckType.USmallInt:
    result = vec.valueUSmallint.len
  of DuckType.UInteger:
    result = vec.valueUInteger.len
  of DuckType.UBigInt:
    result = vec.valueUBigint.len
  of DuckType.Float:
    result = vec.valueFloat.len
  of DuckType.Double:
    result = vec.valueDouble.len
  of DuckType.Timestamp:
    result = vec.valueTimestamp.len
  of DuckType.TimestampS:
    result = vec.valueTimestampS.len
  of DuckType.TimestampMs:
    result = vec.valueTimestampMs.len
  of DuckType.TimestampNs:
    result = vec.valueTimestampNs.len
  of DuckType.Date:
    result = vec.valueDate.len
  of DuckType.Time:
    result = vec.valueTime.len
  of DuckType.Interval:
    result = vec.valueInterval.len
  of DuckType.HugeInt:
    result = vec.valueHugeint.len
  of DuckType.Varchar:
    result = vec.valueVarchar.len
  of DuckType.Blob:
    result = vec.valueBlob.len
  of DuckType.Decimal:
    result = vec.valueDecimal.len
  of DuckType.Enum:
    result = vec.valueEnum.len
  of DuckType.List, DuckType.Array:
    result = vec.valueList.len
  of DuckType.Struct:
    result = vec.valueStruct.len
  of DuckType.Map:
    result = vec.valueMap.len
  of DuckType.UUID:
    result = vec.valueUuid.len
  of DuckType.Union:
    result = vec.valueUnion.len
  of DuckType.Bit:
    result = vec.valueBit.len
  of DuckType.TimeTz:
    result = vec.valueTimeTz.len
  of DuckType.TimestampTz:
    result = vec.valueTimestampTz.len
  of DuckType.UHugeInt:
    result = vec.valueUHugeint.len

# has a bug when more chunks are present
proc isValid*(vec: Vector, idx: int): bool {.inline.} =
  let
    entryIdx = idx div BITS_PER_VALUE
    indexInEntry = idx mod BITS_PER_VALUE

  if entryIdx >= vec.mask.len:
    return true

  return (vec.mask[entryIdx] and (1'u64 shl indexInEntry)) != 0

template collectValid[T, U](
    handle: pointer, vec: Vector, offset, size: int, transform: untyped
): seq[U] =
  let raw = cast[ptr UncheckedArray[T]](handle)
  collect:
    for i in offset ..< size:
      transform(raw[i])

template collectValidString[T](
    handle: pointer,
    vec: Vector,
    offset, size: int,
    resultField: var auto,
    transform: untyped,
): untyped =
  resultField = collect:
    for i in offset ..< size:
      if vec.isValid(i):
        let
          basePtr = cast[pointer](cast[uint](handle) + (i * sizeof(duckdbstringt)).uint)
          strLength = cast[ptr int32](basePtr)[]
        var rawStr: cstring

        if strLength <= STRING_INLINE_LENGTH:
          rawStr = cast[cstring](cast[uint](basePtr) + sizeof(int32).uint)
        else:
          rawStr = cast[ptr cstring](cast[uint](basePtr) + sizeof(int32).uint * 2)[]
        transform(rawStr)
      else:
        when T is string:
          "" # TODO: not sure about this
        else:
          newSeq[byte](0) # Empty byte array for blobs

template parseHandle(
    handle: pointer,
    vec: Vector,
    rawType: untyped,
    resultField: untyped,
    castType: untyped,
): untyped =
  let raw = cast[ptr UncheckedArray[rawType]](handle)
  resultField = collectValid[rawType, type(resultField[0])](raw, vec, offset, size) do(
    val: rawType
  ) -> auto:
    castType(val)

template parseHandle(
    handle: pointer, vec: Vector, rawType: untyped, resultField: untyped
): untyped =
  parseHandle(handle, vec, rawType, resultField, rawType)

template parseDecimalBigInt(handle, scale, size: untyped) =

  var data = newSeq[DecimalType](size)
  let
    raw = cast[ptr UncheckedArray[int64]](handle)
    validityMask = newValidityMask(duckVector, size)

  for i in offset ..< size:
    let value = raw[i].float / pow(10.0, scale.float)
    data[i] = newDecimal($value)

  return Vector(kind: kind, mask: validityMask, valueDecimal: data)

template parseDecimalHugeInt(handle, scale, size: untyped) =
  var data = newSeq[DecimalType](size)
  let
    raw = cast[ptr UncheckedArray[duckdbHugeInt]](handle)
    validityMask = newValidityMask(duckVector, size)

  for i in offset ..< size:
    let
      value = fromHugeInt(raw[i])
      fractional = cast[float](value) / pow(10.0, scale.float)
    data[i] = newDecimal($fractional)

  return Vector(kind: kind, mask: validityMask, valueDecimal: data)

proc vecToValue*(vec: Vector, idx: int): Value =
  let isValid = vec.isValid(idx)
  case vec.kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    raise newException(ValueError, fmt"got invalid enum type: {vec.kind}")
  of DuckType.Boolean:
    return newValue(vec.valueBoolean[idx], isValid)
  of DuckType.TinyInt:
    return newValue(vec.valueTinyint[idx], isValid)
  of DuckType.SmallInt:
    return newValue(vec.valueSmallint[idx], isValid)
  of DuckType.Integer:
    return newValue(vec.valueInteger[idx], isValid)
  of DuckType.BigInt:
    return newValue(vec.valueBigint[idx], isValid)
  of DuckType.UTinyInt:
    return newValue(vec.valueUTinyint[idx], isValid)
  of DuckType.USmallInt:
    return newValue(vec.valueUSmallint[idx], isValid)
  of DuckType.UInteger:
    return newValue(vec.valueUInteger[idx], isValid)
  of DuckType.UBigInt:
    return newValue(vec.valueUBigint[idx], isValid)
  of DuckType.Float:
    return newValue(vec.valueFloat[idx], isValid)
  of DuckType.Double:
    return newValue(vec.valueDouble[idx], isValid)
  of DuckType.Timestamp:
    return newValue(vec.valueTimestamp[idx], vec.kind, isValid)
  of DuckType.TimestampS:
    return newValue(vec.valueTimestampS[idx], vec.kind, isValid)
  of DuckType.TimestampMs:
    return newValue(vec.valueTimestampMs[idx], vec.kind, isValid)
  of DuckType.TimestampNs:
    return newValue(vec.valueTimestampNs[idx], vec.kind, isValid)
  of DuckType.Date:
    return newValue(vec.valueDate[idx], vec.kind, isValid)
  of DuckType.Time:
    return newValue(vec.valueTime[idx], isValid)
  of DuckType.Interval:
    return newValue(vec.valueInterval[idx], isValid)
  of DuckType.HugeInt:
    return newValue(vec.valueHugeint[idx], isValid)
  of DuckType.Varchar:
    return newValue(vec.valueVarchar[idx], isValid)
  of DuckType.Blob:
    return newValue(vec.valueBlob[idx], isValid)
  of DuckType.Decimal:
    return newValue(vec.valueDecimal[idx], isValid)
  of DuckType.Enum:
    return newValue(vec.valueEnum[idx], isValid)
  of DuckType.List, DuckType.Array:
    return newValue(vec.valueList[idx], isValid)
  of DuckType.Struct:
    return newValue(vec.valueStruct[idx], vec.kind, isValid)
  of DuckType.Map:
    return newValue(vec.valueMap[idx], vec.kind, isValid)
  of DuckType.UUID:
    return newValue(vec.valueUuid[idx], isValid)
  of DuckType.Union:
    return newValue(vec.valueUnion[idx], vec.kind, isValid)
  of DuckType.Bit:
    return newValue(vec.valueBit[idx], vec.kind, isValid)
  of DuckType.TimeTz:
    return newValue(vec.valueTimeTz[idx], isValid)
  of DuckType.TimestampTz:
    return newValue(vec.valueTimestampTz[idx], isValid)
  of DuckType.UHugeInt:
    return newValue(vec.valueUHugeint[idx], isValid)

iterator items*(vec: Vector): Value =
  for idx in 0 ..< vec.len:
    yield vecToValue(vec, idx)

proc newVector*(kind: DuckType): Vector =
  var vec = Vector(kind: kind)
  case kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    raise newException(ValueError, fmt"got invalid enum type: {kind}")
  of DuckType.Boolean:
    vec.valueBoolean = newSeq[bool]()
  of DuckType.TinyInt:
    vec.valueTinyint = newSeq[int8]()
  of DuckType.SmallInt:
    vec.valueSmallint = newSeq[int16]()
  of DuckType.Integer:
    vec.valueInteger = newSeq[int32]()
  of DuckType.BigInt:
    vec.valueBigint = newSeq[int64]()
  of DuckType.UTinyInt:
    vec.valueUTinyint = newSeq[uint8]()
  of DuckType.USmallInt:
    vec.valueUSmallint = newSeq[uint16]()
  of DuckType.UInteger:
    vec.valueUInteger = newSeq[uint32]()
  of DuckType.UBigInt:
    vec.valueUBigint = newSeq[uint64]()
  of DuckType.Float:
    vec.valueFloat = newSeq[float32]()
  of DuckType.Double:
    vec.valueDouble = newSeq[float64]()
  of DuckType.Timestamp:
    vec.valueTimestamp = newSeq[Timestamp]()
  of DuckType.Date:
    vec.valueDate = newSeq[DateTime]()
  of DuckType.Time:
    vec.valueTime = newSeq[Time]()
  of DuckType.Interval:
    vec.valueInterval = newSeq[TimeInterval]()
  of DuckType.HugeInt:
    vec.valueHugeint = newSeq[Int128]()
  of DuckType.Varchar:
    vec.valueVarchar = newSeq[string]()
  of DuckType.Blob:
    vec.valueBlob = newSeq[seq[byte]]()
  of DuckType.Decimal:
    vec.valueDecimal = newSeq[DecimalType]()
  of DuckType.TimestampS:
    vec.valueTimestampS = newSeq[DateTime]()
  of DuckType.TimestampMs:
    vec.valueTimestampMs = newSeq[DateTime]()
  of DuckType.TimestampNs:
    vec.valueTimestampNs = newSeq[DateTime]()
  of DuckType.Enum:
    vec.valueEnum = newSeq[uint]()
  of DuckType.List, DuckType.Array:
    vec.valueList = newSeq[seq[Value]]()
  of DuckType.Struct, DuckType.Map:
    vec.valueStruct = newSeq[Table[string, Value]]()
  of DuckType.UUID:
    vec.valueUuid = newSeq[Uuid]()
  of DuckType.Union:
    vec.valueUnion = newSeq[Table[string, Value]]()
  of DuckType.Bit:
    vec.valueBit = newSeq[string]()
  of DuckType.TimeTz:
    vec.valueTimeTz = newSeq[ZonedTime]()
  of DuckType.TimestampTz:
    vec.valueTimestampTz = newSeq[ZonedTime]()
  of DuckType.UHugeInt:
    vec.valueUHugeint = newSeq[UInt128]()
  return vec

proc newVector*(data: seq[bool]): Vector =
  return Vector(kind: DuckType.Boolean, valueBoolean: data, mask: newValidityMask())

proc newVector*(data: seq[int8]): Vector =
  return Vector(kind: DuckType.TinyInt, valueTinyint: data, mask: newValidityMask())

proc newVector*(data: seq[int16]): Vector =
  return Vector(kind: DuckType.SmallInt, valueSmallint: data, mask: newValidityMask())

proc newVector*(data: seq[int32]): Vector =
  return Vector(kind: DuckType.Integer, valueInteger: data, mask: newValidityMask())

proc newVector*(data: seq[int64]): Vector =
  return Vector(kind: DuckType.BigInt, valueBigint: data, mask: newValidityMask())

proc newVector*(data: seq[uint8]): Vector =
  return Vector(kind: DuckType.UTinyInt, valueUTinyint: data, mask: newValidityMask())

proc newVector*(data: seq[uint16]): Vector =
  return Vector(kind: DuckType.USmallInt, valueUSmallint: data, mask: newValidityMask())

proc newVector*(data: seq[uint32]): Vector =
  return Vector(kind: DuckType.UInteger, valueUInteger: data, mask: newValidityMask())

proc newVector*(data: seq[uint64]): Vector =
  return Vector(kind: DuckType.UBigInt, valueUBigint: data, mask: newValidityMask())

proc newVector*(data: seq[float32]): Vector =
  return Vector(kind: DuckType.Float, valueFloat: data, mask: newValidityMask())

proc newVector*(data: seq[float64]): Vector =
  return Vector(kind: DuckType.Double, valueDouble: data, mask: newValidityMask())

proc newVector*(data: seq[Timestamp]): Vector =
  return Vector(kind: DuckType.Timestamp, valueTimestamp: data, mask: newValidityMask())

proc newVector*(data: seq[Time]): Vector =
  return Vector(kind: DuckType.Time, valueTime: data, mask: newValidityMask())

proc newVector*(data: seq[TimeInterval]): Vector =
  return Vector(kind: DuckType.Interval, valueInterval: data, mask: newValidityMask())

proc newVector*(data: seq[Int128]): Vector =
  return Vector(kind: DuckType.HugeInt, valueHugeint: data, mask: newValidityMask())

proc newVector*(data: seq[string]): Vector =
  return Vector(kind: DuckType.Varchar, valueVarchar: data, mask: newValidityMask())

proc newVector*(data: seq[seq[byte]]): Vector =
  return Vector(kind: DuckType.Blob, valueBlob: data, mask: newValidityMask())

proc newVector*(data: seq[DecimalType]): Vector =
  return Vector(kind: DuckType.Decimal, valueDecimal: data, mask: newValidityMask())

proc newVector*(data: seq[uint]): Vector =
  return Vector(kind: DuckType.Enum, valueEnum: data, mask: newValidityMask())

proc newVector*(data: seq[seq[Value]]): Vector =
  return Vector(kind: DuckType.List, valueList: data, mask: newValidityMask())

proc newVector*(data: seq[Table[string, Value]]): Vector =
  return Vector(kind: DuckType.Struct, valueStruct: data, mask: newValidityMask())

proc newVector*(data: seq[Uuid]): Vector =
  return Vector(kind: DuckType.UUID, valueUuid: data, mask: newValidityMask())

# proc newVector*(data: seq[string]): Vector =
#   return Vector(kind: DuckType.Bit, valueBit: data, mask: newValidityMask())

proc newVector*(data: seq[ZonedTime]): Vector =
  return Vector(kind: DuckType.TimeTz, valueTimeTz: data, mask: newValidityMask())

proc newVector*(data: seq[int | int64]): Vector =
  return Vector(
    kind: DuckType.BigInt, valueBigint: data.map(e => int64(e)), mask: newValidityMask()
  )

# proc newVector*(
#     vec: duckdb_vector, size: int, offset: int = 0, size: int, kind: DuckType, logicalType: LogicalType
# ): Vector =

template handleVectorCase(handle, cType, nimType, fieldName: untyped) =
  let
    raw = cast[ptr UncheckedArray[cType]](handle)
    validityMask = newValidityMask(duckVector, size)
  var data = newSeq[nimType](size)
  if size > 0:
    copyMem(addr data[0], addr raw[offset], size * sizeof(nimType))
  return Vector(kind: kind, mask: validityMask, fieldName: data)

template handleVectorCase(handle, cType, nimType, fieldName, caster: untyped) =
  let
    raw = cast[ptr UncheckedArray[cType]](handle)
    validityMask = newValidityMask(duckVector, size)
  var data = newSeq[nimType](size)
  for i in offset ..< size:
    data[i] = caster(raw[i])
  return Vector(kind: kind, mask: validityMask, fieldName: data)

proc newVector*(duckVector: duckdb_vector, size: int, offset: int = 0): Vector =
  let
    logicalType = newLogicalType(duckdbVectorGetColumnType(duckVector))
    kind = newDuckType(logicalType)
    handle = duckdbVectorGetData(duckVector)

  case kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    raise newException(ValueError, fmt"got invalid enum type: {kind}")
  of DuckType.Boolean:
    handleVectorCase(handle, uint8, bool, valueBoolean)
  of DuckType.TinyInt:
    handleVectorCase(handle, int8, int8, valueTinyint)
  of DuckType.SmallInt:
    handleVectorCase(handle, int16, int16, valueSmallint)
  of DuckType.Integer:
    handleVectorCase(handle, int32, int32, valueInteger)
  of DuckType.BigInt:
    handleVectorCase(handle, int64, int64, valueBigint)
  of DuckType.UTinyInt:
    handleVectorCase(handle, uint8, uint8, valueUtinyint)
  of DuckType.USmallInt:
    handleVectorCase(handle, uint16, uint16, valueUSmallint)
  of DuckType.UInteger:
    handleVectorCase(handle, uint32, uint32, valueUInteger)
  of DuckType.UBigInt:
    handleVectorCase(handle, uint64, uint64, valueUBigint)
  of DuckType.Float:
    handleVectorCase(handle, float32, float32, valueFloat)
  of DuckType.Double:
    handleVectorCase(handle, float64, float64, valueDouble)
  of DuckType.Timestamp:
    handleVectorCase(handle, int64, TimeStamp, valueTimeStamp, fromTimestamp)
  of DuckType.Date:
    handleVectorCase(handle, int32, DateTime, valueDate, fromDatetime)
  of DuckType.Time:
    handleVectorCase(handle, int64, Time, valueTime, fromTime)
  of DuckType.Interval:
    handleVectorCase(handle, duckdbInterval, TimeInterval, valueInterval, fromInterval)
  of DuckType.HugeInt:
    handleVectorCase(handle, duckdbHugeInt, Int128, valueHugeInt, fromHugeInt)
  of DuckType.VarChar:
    let validityMask = newValidityMask(duckVector, size)
    var data = newSeq[string](size)
    for i in offset ..< size:
      let
        basePtr = cast[pointer](cast[uint](handle) + (i * sizeof(duckdbstringt)).uint)
        strLength = cast[ptr int32](basePtr)[]
      var rawStr: cstring

      if strLength <= STRING_INLINE_LENGTH:
        rawStr = cast[cstring](cast[uint](basePtr) + sizeof(int32).uint)
      else:
        rawStr = cast[ptr cstring](cast[uint](basePtr) + sizeof(int32).uint * 2)[]
      data[i] = $rawStr
    return Vector(kind: kind, mask: validityMask, valueVarchar: data)
  of DuckType.Blob:
    let validityMask = newValidityMask(duckVector, size)
    var data = newSeq[seq[byte]](size)
    for i in offset ..< size:
      let
        basePtr = cast[pointer](cast[uint](handle) + (i * sizeof(duckdbstringt)).uint)
        strLength = cast[ptr int32](basePtr)[]
      var rawStr: cstring

      if strLength <= STRING_INLINE_LENGTH:
        rawStr = cast[cstring](cast[uint](basePtr) + sizeof(int32).uint)
      else:
        rawStr = cast[ptr cstring](cast[uint](basePtr) + sizeof(int32).uint * 2)[]
      var byteArray = newSeq[byte](rawStr.len)
      copyMem(addr byteArray[0], unsafeAddr rawStr[0], rawStr.len)
      data[i] = byteArray
    return Vector(kind: kind, mask: validityMask, valueBlob: data)
  of DuckType.Decimal:
    let
      scale = duckdb_decimal_scale(logicalType.handle).int
      width = duckdb_decimal_width(logicalType.handle).int
    if width <= 18:
      parseDecimalBigInt(handle, scale, size)
    else:
      parseDecimalHugeInt(handle, scale, size)
  else:
    discard


  # of DuckType.Boolean:
  #   let
  #     raw = cast[ptr UncheckedArray[uint8]](handle)
  #     validityMask = newValidityMask(duckVector, size)
  #   var data = newSeq[bool](size)
  #   if size > 0:
  #     copyMem(addr data[0], addr raw[offset], size * sizeof(bool))
  #   return Vector(kind: kind, mask: validityMask, valueBoolean: data)
  # else:
  #   discard

  # of DuckType.Boolean:
  #   parseHandle(handle, result, uint8, result.valueBoolean, bool)
  # of DuckType.TinyInt:
  #   parseHandle(handle, result, int8, result.valueTinyint)
  # of DuckType.SmallInt:
  #   parseHandle(handle, result, int16, result.valueSmallint)
  # of DuckType.Integer:
  #   parseHandle(handle, result, cint, result.valueInteger, int32)
  # of DuckType.BigInt:
  #   parseHandle(handle, result, int64, result.valueBigint)
  # of DuckType.UTinyInt:
  #   parseHandle(handle, result, uint8, result.valueUtinyint)
  # of DuckType.USmallInt:
  #   parseHandle(handle, result, uint16, result.valueUSmallint)
  # of DuckType.UInteger:
  #   parseHandle(handle, result, uint32, result.valueUInteger)
  # of DuckType.UBigInt:
  #   parseHandle(handle, result, uint64, result.valueUBigint)
  # of DuckType.Float:
  #   parseHandle(handle, result, float32, result.valueFloat)
  # of DuckType.Double:
  #   parseHandle(handle, result, float64, result.valueDouble)

  # of DuckType.Timestamp:
  #   result.valueTimestamp = collectValid[int64, Timestamp](handle, result, offset, size) do(
  #     val: int64
  #   ) -> Timestamp:
  #     fromTimestamp(val)
  # of DuckType.Date:
  #   result.valueDate = collectValid[int32, DateTime](handle, result, offset, size) do(
  #     val: int32
  #   ) -> DateTime:
  #     fromDatetime(val)
  # of DuckType.Time:
  #   result.valueTime = collectValid[int64, Time](handle, result, offset, size) do(
  #     val: int64
  #   ) -> Time:
  #     fromTime(val)
  # of DuckType.Interval:
  #   result.valueInterval = collectValid[duckdbInterval, TimeInterval](
  #     handle, result, offset, size
  #   ) do(val: duckdbInterval) -> TimeInterval:
  #     fromInterval(val)
  # of DuckType.HugeInt:
  #   result.valueHugeInt = collectValid[duckdb_hugeint, Int128](
  #     handle, result, offset, size
  #   ) do(val: duckdb_hugeint) -> Int128:
  #     fromHugeInt(val)
  # of DuckType.VarChar:
  #   collectValidString[string](handle, result, offset, size, result.valueVarChar) do(
  #     rawStr: cstring
  #   ) -> string:
  #     $rawStr
  # of DuckType.Blob:
  #   collectValidString[seq[byte]](handle, result, offset, size, result.valueBlob) do(
  #     rawStr: cstring
  #   ) -> seq[byte]:
  #     var byteArray = newSeq[byte](rawStr.len)
  #     copyMem(addr byteArray[0], unsafeAddr rawStr[0], rawStr.len)
  #     byteArray
  # of DuckType.Decimal:
  #   let
  #     scale = duckdb_decimal_scale(logicalType.handle).int
  #     width = duckdb_decimal_width(logicalType.handle).int
  #   if width <= 18:
  #     parseDecimalBigInt(handle, result, scale, result.valueDecimal)
  #   else:
  #     parseDecimalHugeInt(handle, result, scale, result.valueDecimal)
  # of DuckType.TimestampS:
  #   result.valueTimestampS = collectValid[int64, DateTime](handle, result, offset, size) do(
  #     val: int64
  #   ) -> DateTime:
  #     fromUnix(val).inZone(utc())
  # of DuckType.TimestampMs:
  #   result.valueTimestampMs = collectValid[int64, DateTime](
  #     handle, result, offset, size
  #   ) do(val: int64) -> DateTime:
  #     fromUnix(val div 1000).inZone(utc()) + initDuration(milliseconds = val mod 1000)
  # of DuckType.TimestampNs:
  #   result.valueTimestampNs = collectValid[int64, Datetime](
  #     handle, result, offset, size
  #   ) do(val: int64) -> DateTime:
  #     let
  #       seconds = val div 1_000_000_000
  #       microseconds = val mod 1_000_000_000 div 1000
  #     fromUnix(seconds).inZone(utc()) + initDuration(microseconds = microseconds)
  # # TODO: not sure if this needs to be the ord or the label
  # of DuckType.Enum:
  #   let enum_tp = cast[DuckType](duckdb_enum_internal_type(logicalType.handle))
  #   case enum_tp
  #   of UTinyInt:
  #     parseHandle(handle, result, uint8, result.valueEnum, uint)
  #   of USmallInt:
  #     parseHandle(handle, result, uint16, result.valueEnum, uint)
  #   of UInteger:
  #     parseHandle(handle, result, uint32, result.valueEnum, uint)
  #   else:
  #     raise newException(ValueError, fmt"got invalid enum type: {enum_tp}")
  # of DuckType.List, DuckType.Array:
  #   let
  #     raw = cast[ptr UncheckedArray[duckdb_list_entry]](handle)
  #     children = duckdb_list_vector_get_child(vec)

  #   for i in offset ..< size:
  #     if isValid(result, i):
  #       let
  #         list_data = raw[i]
  #         child_type = newLogicalType(duckdb_list_type_child_type(logicalType.handle))
  #         child = newVector(
  #           vec = children,
  #           offset = list_data.offset.int,
  #           size = (list_data.offset + list_data.length).int,
  #           kind = newDuckType(child_type),
  #           logicalType = child_type,
  #         )
  #       var child_array = newSeq[Value]()
  #       for c in child:
  #         child_array.add(cast[Value](c))
  #       result.valueList.add(child_array)
  # of DuckType.Struct:
  #   let child_count = duckdb_struct_type_child_count(logicalType.handle).int
  #   var vectorStruct = initTable[string, Vector]()
  #   for child_idx in 0 ..< child_count:
  #     let
  #       children = duckdb_struct_vector_get_child(vec, child_idx.idx_t)
  #       child_type = newLogicalType(
  #         duckdb_struct_type_child_type(logicalType.handle, child_idx.idx_t)
  #       )
  #       child_name = newDuckString(
  #         duckdb_struct_type_child_name(logicalType.handle, child_idx.idx_t)
  #       )
  #       child = newVector(
  #         vec = children,
  #         offset = offset,
  #         size = size,
  #         kind = newDuckType(child_type),
  #         logicalType = child_type,
  #       )

  #     vectorStruct[$child_name] = child
  #   result.valueStruct = collect:
  #     for i in offset ..< size:
  #       var row = initTable[string, Value]()
  #       for key, child_vector in vectorStruct.pairs:
  #         row[key] = vecToValue(child_vector, i)
  #       row
  # of DuckType.Map:
  #   let
  #     # don't know how to make use of key_type and value_type
  #     # key_type = newLogicalType(duckdb_map_type_key_type(logicalType.handle))
  #     # value_type = newLogicalType(duckdb_map_type_value_type(logicalType.handle))
  #     children = duckdb_list_vector_get_child(vec)
  #     lsize = duckdb_list_vector_get_size(vec)
  #     child_type = newLogicalType(duckdb_list_type_child_type(logicalType.handle))

  #   result.valueMap = collect:
  #     for i in 0 ..< size:
  #       var vectorMap = initTable[string, Value]()
  #       let elements = newVector(
  #         vec = children,
  #         offset = 0,
  #         size = lsize.int,
  #         kind = newDuckType(child_type),
  #         logicalType = child_type,
  #       )
  #       for e in elements.valueStruct:
  #         vectorMap[$e["key"]] = e["value"]
  #       vectorMap
  # # TODO: uuid is wrong
  # of DuckType.UUID:
  #   result.valueUuid = collectValid[duckdb_hugeint, Uuid](handle, result, offset, size) do(
  #     val: duckdb_hugeint
  #   ) -> Uuid:
  #     let huge_int = UInt128(lo: val.lower.uint64, hi: val.upper.uint64)
  #     initUuid(huge_int.toHex)
  # # TODO: this is shit and fragile
  # # TODO: some bugs, sometimes tags are missing
  # of DuckType.Union:
  #   let
  #     children =
  #       newVector(vec, offset, size, kind = DuckType.Struct, logicalType = logicalType)
  #     child_count = len(children)

  #   var tags = newSeq[string]()
  #   for child_idx in 0 ..< child_count:
  #     let child_name = newDuckString(
  #       duckdb_struct_type_child_name(logicalType.handle, child_idx.idx_t)
  #     )
  #     if $child_name != "":
  #       tags.add($child_name)

  #   result.valueUnion = collect:
  #     for e in children.valueStruct:
  #       var row = initTable[string, Value]()
  #       for tag in tags:
  #         if $e[tag] != "":
  #           row[tag] = e[tag]
  #           row
  # of DuckType.Bit:
  #   result.valueBit = newVector(
  #     vec, offset, size, kind = DuckType.Varchar, logicalType = logicalType
  #   ).valueVarChar
  # of DuckType.TimeTz:
  #   result = newVector(kind = kind)
  #   result.valueTimeTz = collectValid[int64, ZonedTime](handle, result, offset, size) do(
  #     val: int64
  #   ) -> ZonedTime:
  #     let
  #       tmz = duckdb_from_time_tz(cast[duckdb_time_tz](val))
  #       seconds = tmz.time.hour * 3600 + tmz.time.min.int * 60 + tmz.time.sec
  #       nanoseconds = tmz.time.micros * 1000
  #       tm = initTime(seconds, nanoseconds)

  #     proc zonedTimeFromAdjTime(adjTime: Time): ZonedTime =
  #       result = ZonedTime()
  #       result.isDst = false
  #       result.utcOffset = tmz.offset
  #       result.time = adjTime + initDuration(seconds = offset)

  #     proc zonedTimeFromTime(time: Time): ZonedTime =
  #       result = ZonedTime()
  #       result.isDst = false
  #       result.utcOffset = tmz.offset
  #       result.time = time

  #     let tz = newTimezone("Something", zonedTimeFromTime, zonedTimeFromAdjTime)
  #     let timeValue = zonedTimeFromTime(tz, tm)
  #     timeValue
  # of DuckType.TimestampTz:
  #   raise newException(ValueError, "TimestampTz type not implemented")
  # of DuckType.UHugeInt:
  #   result.valueUHugeInt = collectValid[duckdb_uhugeint, UInt128](
  #     handle, result, offset, size
  #   ) do(val: duckdb_uhugeint) -> UInt128:
  #     fromUHugeInt(val)

proc `[]`*(v: Vector, idx: int): Value =
  return vecToValue(v, idx)

proc `&=`*(left: var Vector, right: Vector): void =
  if left.kind != right.kind:
    raise newException(
      ValueError,
      fmt"Vector.kind:{left.kind} != Vector.kind:{right.kind}. Can't concatenate different kinds of vectors",
    )

  # TODO: this is not how mask works
  left.mask &= right.mask
  case left.kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    raise newException(ValueError, fmt"got invalid enum type: {left.kind}")
  of DuckType.Boolean:
    left.valueBoolean &= right.valueBoolean
  of DuckType.TinyInt:
    left.valueTinyint &= right.valueTinyint
  of DuckType.SmallInt:
    left.valueSmallint &= right.valueSmallint
  of DuckType.Integer:
    left.valueInteger &= right.valueInteger
  of DuckType.BigInt:
    left.valueBigint &= right.valueBigint
  of DuckType.UTinyInt:
    left.valueUtinyint &= right.valueUtinyint
  of DuckType.USmallInt:
    left.valueUsmallint &= right.valueUsmallint
  of DuckType.UInteger:
    left.valueUinteger &= right.valueUinteger
  of DuckType.UBigInt:
    left.valueUbigint &= right.valueUbigint
  of DuckType.Float:
    left.valueFloat &= right.valueFloat
  of DuckType.Double:
    left.valueDouble &= right.valueDouble
  of DuckType.Timestamp:
    left.valueTimestamp &= right.valueTimestamp
  of DuckType.Date:
    left.valueDate &= right.valueDate
  of DuckType.Time:
    left.valueTime &= right.valueTime
  of DuckType.Interval:
    left.valueInterval &= right.valueInterval
  of DuckType.HugeInt:
    left.valueHugeInt &= right.valueHugeInt
  of DuckType.VarChar:
    left.valueVarchar &= right.valueVarchar
  of DuckType.Blob:
    left.valueBlob &= right.valueBlob
  of DuckType.Decimal:
    left.valueDecimal &= right.valueDecimal
  of DuckType.TimestampS:
    left.valueTimestampS &= right.valueTimestampS
  of DuckType.TimestampMs:
    left.valueTimestampMs &= right.valueTimestampMs
  of DuckType.TimestampNs:
    left.valueTimestampNs &= right.valueTimestampNs
  of DuckType.Enum:
    left.valueEnum &= right.valueEnum
  of DuckType.List, DuckType.Array:
    left.valueList &= right.valueList
  of DuckType.Struct:
    left.valueStruct &= right.valueStruct
  of DuckType.Map:
    left.valueMap &= right.valueMap
  of DuckType.UUID:
    left.valueUuid &= right.valueUuid
  of DuckType.Union:
    left.valueUnion &= right.valueUnion
  of DuckType.Bit:
    left.valueBit &= right.valueBit
  of DuckType.TimeTz:
    left.valueTimeTz &= right.valueTimeTz
  of DuckType.TimestampTz:
    left.valueTimestampTz &= right.valueTimestampTz
  of DuckType.UHugeInt:
    left.valueUHugeInt &= right.valueUHugeInt
