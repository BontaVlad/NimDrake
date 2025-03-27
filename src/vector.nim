# {.experimental: "codeReordering".}
import
  std/[tables, times, math, strformat, sequtils, sugar, typetraits, enumerate, macros]

import nint128
import decimal
import uuid4

import /[api, value, types]

template `[]=`*[T: SomeNumber](vec: duckdbVector, i: int, val: T) =
  var raw = duckdbVectorGetData(vec)
  when T is int:
    cast[ptr UncheckedArray[cint]](raw)[i] = cint(val)
  else:
    cast[ptr UncheckedArray[T]](raw)[i] = val

template `[]=`*(vec: duckdbVector, i: int, val: bool) =
  var raw = duckdbVectorGetData(vec)
  cast[ptr UncheckedArray[uint8]](raw)[i] = val.uint8

template `[]=`*(vec: duckdbVector, i: int, val: string) =
  duckdbVectorAssignStringElement(vec, i.idx_t, val.cstring)

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

proc isValid*(vec: Vector, idx: int): bool {.inline.} =
  return vec.mask.isValid(idx)

template collectValid[T, U](
    handle: pointer, vec: Vector, offset, size: int, transform: untyped
): seq[U] =
  let raw = cast[ptr UncheckedArray[T]](handle)
  collect:
    for i in offset ..< size:
      transform(raw[i])

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

template parseDecimalBigInt(kind, handle, scale, size: untyped) =
  var data = newSeq[DecimalType](size)
  let
    raw = cast[ptr UncheckedArray[int64]](handle)
    validityMask = newValidityMask(duckVector, size)

  for i in offset ..< size:
    let value = raw[i].float / pow(10.0, scale.float)
    data[i] = newDecimal($value)

  return Vector(kind: kind, mask: validityMask, valueDecimal: data)

template parseDecimalHugeInt(kind, handle, scale, size: untyped) =
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

template handleVectorCase(
    kind, handle, duckdbVector, cType, nimType, fieldName: untyped
) =
  let
    raw = cast[ptr UncheckedArray[cType]](handle)
    validityMask = newValidityMask(duckVector, size)
  var data = newSeq[nimType](size)
  if size > 0:
    copyMem(addr data[0], addr raw[offset], size * sizeof(nimType))
  return Vector(kind: kind, mask: validityMask, fieldName: data)

template handleVectorCase(
    kind, handle, duckdbVector, cType, nimType, fieldName, caster: untyped
) =
  let
    raw = cast[ptr UncheckedArray[cType]](handle)
    validityMask = newValidityMask(duckVector, size)
  var data = newSeq[nimType](size)
  for i in offset ..< size:
    data[i] = caster(raw[i])
  return Vector(kind: kind, mask: validityMask, fieldName: data)

template handleVectorCaseString(kind, handle, duckdbVector, size) =
  let validityMask = newValidityMask(duckVector, size)
  var data = newSeq[string](size)
  let raw = cast[ptr UncheckedArray[duckdbstringt]](handle)
  for i in offset ..< size:
    if duckdb_string_is_inlined(raw[i]):
      let stringStruct = cast[struct_duckdb_string_t_value_t_inlined_t](raw[i])
      var output = newString(stringStruct.length)
      for i in 0 ..< stringStruct.length.int:
        output[i] = char(stringStruct.inlined[i])
      data[i] = output
    else:
      let stringStruct = cast[struct_duckdb_string_t_value_t](raw[i])
      var output = $cast[cstring](stringStruct.pointer_field.ptr_field)
      output.setLen(stringStruct.pointer_field.length)
      data[i] = output

  return Vector(kind: kind, mask: validityMask, valueVarchar: data)

# TODO: this is most likelly wrong
template handleVectorCaseBlob(kind, handle, duckdbVector, size) =
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

proc newVector*(
    duckVector: duckdbVector,
    size: int,
    offset: int,
    kind: DuckType,
    logicalType: LogicalType,
): Vector =
  let handle = duckdbVectorGetData(duckVector)
  case kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    raise newException(ValueError, fmt"got invalid enum type: {kind}")
  of DuckType.Boolean:
    handleVectorCase(kind, handle, duckdbVector, uint8, bool, valueBoolean)
  of DuckType.TinyInt:
    handleVectorCase(kind, handle, duckdbVector, int8, int8, valueTinyint)
  of DuckType.SmallInt:
    handleVectorCase(kind, handle, duckdbVector, int16, int16, valueSmallint)
  of DuckType.Integer:
    handleVectorCase(kind, handle, duckdbVector, int32, int32, valueInteger)
  of DuckType.BigInt:
    handleVectorCase(kind, handle, duckdbVector, int64, int64, valueBigint)
  of DuckType.UTinyInt:
    handleVectorCase(kind, handle, duckdbVector, uint8, uint8, valueUtinyint)
  of DuckType.USmallInt:
    handleVectorCase(kind, handle, duckdbVector, uint16, uint16, valueUSmallint)
  of DuckType.UInteger:
    handleVectorCase(kind, handle, duckdbVector, uint32, uint32, valueUInteger)
  of DuckType.UBigInt:
    handleVectorCase(kind, handle, duckdbVector, uint64, uint64, valueUBigint)
  of DuckType.Float:
    handleVectorCase(kind, handle, duckdbVector, float32, float32, valueFloat)
  of DuckType.Double:
    handleVectorCase(kind, handle, duckdbVector, float64, float64, valueDouble)
  of DuckType.Timestamp:
    handleVectorCase(
      kind, handle, duckdbVector, int64, TimeStamp, valueTimeStamp, fromTimestamp
    )
  of DuckType.Date:
    handleVectorCase(
      kind, handle, duckdbVector, int32, DateTime, valueDate, fromDatetime
    )
  of DuckType.Time:
    handleVectorCase(kind, handle, duckdbVector, int64, Time, valueTime, fromTime)
  of DuckType.Interval:
    handleVectorCase(
      kind, handle, duckdbVector, duckdbInterval, TimeInterval, valueInterval,
      fromInterval,
    )
  of DuckType.HugeInt:
    handleVectorCase(
      kind, handle, duckdbVector, duckdbHugeInt, Int128, valueHugeInt, fromHugeInt
    )
  of DuckType.VarChar:
    handleVectorCaseString(kind, handle, duckdbVector, size)
  of DuckType.Blob:
    handleVectorCaseBlob(kind, handle, duckdbVector, size)
  of DuckType.Decimal:
    let
      scale = duckdb_decimal_scale(logicalType.handle).int
      width = duckdb_decimal_width(logicalType.handle).int
    if width <= 18:
      parseDecimalBigInt(kind, handle, scale, size)
    else:
      parseDecimalHugeInt(kind, handle, scale, size)
  of DuckType.TimestampS:
    var data = newSeq[DateTime](size)
    let
      raw = cast[ptr UncheckedArray[int64]](handle)
      validityMask = newValidityMask(duckVector, size)

    for i in offset ..< size:
      data[i] = fromUnix(raw[i]).inZone(utc())

    return Vector(kind: kind, mask: validityMask, valueTimestampS: data)
  of DuckType.TimestampMs:
    var data = newSeq[DateTime](size)
    let
      raw = cast[ptr UncheckedArray[int64]](handle)
      validityMask = newValidityMask(duckVector, size)

    for i in offset ..< size:
      let (seconds, milliseconds) = divmod(raw[i], 1000)
      data[i] =
        fromUnix(seconds).inZone(utc()) + initDuration(milliseconds = milliseconds)

    return Vector(kind: kind, mask: validityMask, valueTimestampMs: data)
  of DuckType.TimestampNs:
    var data = newSeq[DateTime](size)
    let
      raw = cast[ptr UncheckedArray[int64]](handle)
      validityMask = newValidityMask(duckVector, size)

    for i in offset ..< size:
      let
        (s, ns) = divMod(raw[i], 1_000_000_000)
        us = ns div 1000
        nsRem = ns mod 1000
      data[i] =
        fromUnix(s).inZone(utc()) + initDuration(microseconds = us, nanoseconds = nsRem)

    return Vector(kind: kind, mask: validityMask, valueTimestampNs: data)
  of DuckType.Enum:
    let enum_tp = cast[DuckType](duckdb_enum_internal_type(logicalType.handle))
    case enum_tp
    of UTinyInt:
      parseHandle(handle, result, uint8, result.valueEnum, uint)
    of USmallInt:
      parseHandle(handle, result, uint16, result.valueEnum, uint)
    of UInteger:
      parseHandle(handle, result, uint32, result.valueEnum, uint)
    else:
      raise newException(ValueError, fmt"got invalid enum type: {enum_tp}")
  of DuckType.List, DuckType.Array:
    let
      raw = cast[ptr UncheckedArray[duckdbListEntry]](handle)
      validityMask = newValidityMask(duckVector, size)
      children = duckdbListVectorGetChild(duckVector)

    var data = newSeq[seq[Value]](size)

    for i in offset ..< size:
      let
        listData = raw[i]
        childType = newLogicalType(duckdbListTypeChildType(logicalType.handle))
        child = newVector(
          duckVector = children,
          size = (listData.offset + listData.length).int,
          offset = listData.offset.int,
          kind = newDuckType(childType),
          logicalType = childType,
        )
      var childArray = newSeq[Value](len(child))
      for i, c in enumerate(child):
        childArray[i] = cast[Value](c)
      data[i] = childArray

    return Vector(kind: kind, mask: validityMask, valueList: data)
  of DuckType.Struct:
    let
      childCount = duckdbStructTypeChildCount(logicalType.handle).int
      validityMask = newValidityMask(duckVector, size)

    var vectorStruct = initTable[string, Vector]()
    for childIdx in 0 ..< childCount:
      let
        children = duckdbStructVectorGetChild(duckVector, childIdx.idx_t)
        childType =
          newLogicalType(duckdbStructTypeChildType(logicalType.handle, childIdx.idx_t))
        childName =
          newDuckString(duckdbStructTypeChildName(logicalType.handle, childIdx.idx_t))
        child = newVector(
          duckVector = children,
          size = size,
          offset = offset,
          kind = newDuckType(childType),
          logicalType = childType,
        )

      vectorStruct[$child_name] = child

    var data = newSeq[Table[string, Value]](size)
    for i in offset ..< size:
      var row = initTable[string, Value]()
      for key, childVector in vectorStruct.pairs:
        row[key] = vecToValue(childVector, i)
      data[i] = row

    return Vector(kind: kind, mask: validityMask, valueStruct: data)
  of DuckType.Map:
    let
      # don't know how to make use of key_type and value_type
      # key_type = newLogicalType(duckdb_map_type_key_type(logicalType.handle))
      # value_type = newLogicalType(duckdb_map_type_value_type(logicalType.handle))
      children = duckdbListVectorGetChild(duckVector)
      lsize = duckdbListVectorGetSize(duckVector)
      childType = newLogicalType(duckdbListTypeChildType(logicalType.handle))
      validityMask = newValidityMask(duckVector, size)

    var data = newSeq[Table[string, Value]](size)
    for i in offset ..< size:
      var vectorMap = initTable[string, Value]()
      let elements = newVector(
        duckVector = children,
        size = lsize.int,
        offset = 0,
        kind = newDuckType(childType),
        logicalType = childType,
      )
      for e in elements.valueStruct:
        vectorMap[$e["key"]] = e["value"]
      data[i] = vectorMap

    return Vector(kind: kind, mask: validityMask, valueMap: data)
  # TODO: uuid is wrong
  of DuckType.UUID:
    let
      raw = cast[ptr UncheckedArray[duckdbHugeInt]](handle)
      validityMask = newValidityMask(duckVector, size)

    var data = newSeq[Uuid](size)
    for i in offset ..< size:
      let hugeInt = UInt128(lo: raw[i].lower.uint64, hi: raw[i].upper.uint64)
      data[i] = initUuid(hugeInt.toHex)

    return Vector(kind: kind, mask: validityMask, valueUuid: data)
  # TODO: this is shit and fragile
  # TODO: some bugs, sometimes tags are missing
  of DuckType.Union:
    let
      validityMask = newValidityMask(duckVector, size)
      children = newVector(
        duckVector = duckVector,
        size = size,
        offset = offset,
        kind = DuckType.Struct,
        logicalType = logicalType,
      )
      childCount = len(children)

    var tags = newSeq[string]()
    for childIdx in 0 ..< childCount:
      let childName =
        newDuckString(duckdbStructTypeChildName(logicalType.handle, childIdx.idxT))
      if $childName != "":
        tags.add($childName)

    var data = newSeq[Table[string, Value]](size)
    for i in offset ..< size:
      for e in children.valueStruct:
        var row = initTable[string, Value]()
        for tag in tags:
          if $e[tag] != "":
            row[tag] = e[tag]
        data[i] = row
    return Vector(kind: kind, mask: validityMask, valueUnion: data)
  of DuckType.Bit:
    let validityMask = newValidityMask(duckVector, size)
    var data = newVector(duckVector, size, offset, kind, logicalType).valueVarChar
    return Vector(kind: kind, mask: validityMask, valueBit: data)
  of DuckType.TimeTz:
    let
      raw = cast[ptr UncheckedArray[int64]](handle)
      validityMask = newValidityMask(duckVector, size)
    var data = newSeq[ZonedTime](size)

    for i in offset ..< size:
      let
        tmz = duckdbFromTimeTz(cast[duckdbTimeTz](raw[i]))
        seconds = tmz.time.hour * 3600 + tmz.time.min.int * 60 + tmz.time.sec
        nanoseconds = tmz.time.micros * 1000
        tm = initTime(seconds, nanoseconds)

      proc zonedTimeFromAdjTime(adjTime: Time): ZonedTime =
        result = ZonedTime()
        result.isDst = false
        result.utcOffset = tmz.offset
        result.time = adjTime + initDuration(seconds = offset)

      proc zonedTimeFromTime(time: Time): ZonedTime =
        result = ZonedTime()
        result.isDst = false
        result.utcOffset = tmz.offset
        result.time = time

      let
        tz = newTimezone("Something", zonedTimeFromTime, zonedTimeFromAdjTime)
        timeValue = zonedTimeFromTime(tz, tm)
      data[i] = timeValue

    return Vector(kind: kind, mask: validityMask, valueTimeTz: data)
  of DuckType.TimestampTz:
    raise newException(ValueError, "TimestampTz type not implemented")
  of DuckType.UHugeInt:
    let
      raw = cast[ptr UncheckedArray[duckdbUHugeInt]](handle)
      validityMask = newValidityMask(duckVector, size)

    var data = newSeq[UInt128](size)
    for i in offset ..< size:
      data[i] = fromUHugeInt(raw[i])

    return Vector(kind: kind, mask: validityMask, valueUHugeInt: data)

proc newVector*(duckVector: duckdbVector, size: int, offset: int = 0): Vector =
  let
    logicalType = newLogicalType(duckdbVectorGetColumnType(duckVector))
    kind = newDuckType(logicalType)
  return newVector(duckVector, size, offset, kind, logicalType)

proc `[]`*(v: Vector, idx: int): Value =
  return vecToValue(v, idx)

proc `&=`*(left: var Vector, right: sink Vector): void =
  if left.kind != right.kind:
    raise newException(
      ValueError,
      fmt"Vector.kind:{left.kind} != Vector.kind:{right.kind}. Can't concatenate different kinds of vectors",
    )

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
