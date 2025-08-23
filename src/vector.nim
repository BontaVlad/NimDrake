# {.experimental: "codeReordering".}
import
  std/[tables, times, math, strformat, sequtils, sugar, typetraits, enumerate, macros]

import nint128
import uuid4

import /[api, value, types]
import /compatibility/decimal_compat

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
  if len(vec.mask) == 0:
    return true

  let
    entryIdx = idx div BITS_PER_VALUE
    indexInEntry = idx mod BITS_PER_VALUE

  if entryIdx >= len(vec.mask):
    raise newException(ValueError, fmt"Idx {idx} greather than {len(vec.mask)}")

  return (vec.mask[entryIdx] and (1'u64 shl indexInEntry)) != 0

template parseDecimalBigInt(data: var untyped, handle, size, scale: untyped) =
  let raw = cast[ptr UncheckedArray[int64]](handle)

  for i in offset ..< size:
    let value = raw[i].float / pow(10.0, scale.float)
    data[i] = newDecimal($value)

template parseDecimalHugeInt(data: var untyped, handle, size, scale: untyped) =
  let
    raw = cast[ptr UncheckedArray[duckdbHugeInt]](handle)
    fracScale = i128(int(pow(10.0, scale.float)))

  for i in offset ..< size:
    let
      value = fromHugeInt(raw[i])
      whole = $(value div fracScale)
      fractional = $(value mod fracScale)
    data[i] = newDecimal(whole & '.' & fractional)

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

proc newVector*(kind: DuckType, size: int): Vector =
  var vec = Vector(kind: kind)
  case kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    raise newException(ValueError, fmt"got invalid enum type: {kind}")
  of DuckType.Boolean:
    vec.valueBoolean = newSeq[bool](size)
  of DuckType.TinyInt:
    vec.valueTinyint = newSeq[int8](size)
  of DuckType.SmallInt:
    vec.valueSmallint = newSeq[int16](size)
  of DuckType.Integer:
    vec.valueInteger = newSeq[int32](size)
  of DuckType.BigInt:
    vec.valueBigint = newSeq[int64](size)
  of DuckType.UTinyInt:
    vec.valueUTinyint = newSeq[uint8](size)
  of DuckType.USmallInt:
    vec.valueUSmallint = newSeq[uint16](size)
  of DuckType.UInteger:
    vec.valueUInteger = newSeq[uint32](size)
  of DuckType.UBigInt:
    vec.valueUBigint = newSeq[uint64](size)
  of DuckType.Float:
    vec.valueFloat = newSeq[float32](size)
  of DuckType.Double:
    vec.valueDouble = newSeq[float64](size)
  of DuckType.Timestamp:
    vec.valueTimestamp = newSeq[Timestamp](size)
  of DuckType.Date:
    vec.valueDate = newSeq[DateTime](size)
  of DuckType.Time:
    vec.valueTime = newSeq[Time](size)
  of DuckType.Interval:
    vec.valueInterval = newSeq[TimeInterval](size)
  of DuckType.HugeInt:
    vec.valueHugeint = newSeq[Int128](size)
  of DuckType.Varchar:
    vec.valueVarchar = newSeq[string](size)
  of DuckType.Blob:
    vec.valueBlob = newSeq[seq[byte]](size)
  of DuckType.Decimal:
    vec.valueDecimal = newSeq[DecimalType](size)
  of DuckType.TimestampS:
    vec.valueTimestampS = newSeq[DateTime](size)
  of DuckType.TimestampMs:
    vec.valueTimestampMs = newSeq[DateTime](size)
  of DuckType.TimestampNs:
    vec.valueTimestampNs = newSeq[DateTime](size)
  of DuckType.Enum:
    vec.valueEnum = newSeq[uint](size)
  of DuckType.List, DuckType.Array:
    vec.valueList = newSeq[seq[Value]](size)
  of DuckType.Struct, DuckType.Map:
    vec.valueStruct = newSeq[Table[string, Value]](size)
  of DuckType.UUID:
    vec.valueUuid = newSeq[Uuid](size)
  of DuckType.Union:
    vec.valueUnion = newSeq[Table[string, Value]](size)
  of DuckType.Bit:
    vec.valueBit = newSeq[string](size)
  of DuckType.TimeTz:
    vec.valueTimeTz = newSeq[ZonedTime](size)
  of DuckType.TimestampTz:
    vec.valueTimestampTz = newSeq[ZonedTime](size)
  of DuckType.UHugeInt:
    vec.valueUHugeint = newSeq[UInt128](size)
  return vec

proc newVector*(data: seq[bool]): Vector =
  return Vector(kind: DuckType.Boolean, valueBoolean: data)

proc newVector*(data: seq[int8]): Vector =
  return Vector(kind: DuckType.TinyInt, valueTinyint: data)

proc newVector*(data: seq[int16]): Vector =
  return Vector(kind: DuckType.SmallInt, valueSmallint: data)

proc newVector*(data: seq[int32]): Vector =
  return Vector(kind: DuckType.Integer, valueInteger: data)

proc newVector*(data: seq[int64]): Vector =
  return Vector(kind: DuckType.BigInt, valueBigint: data)

proc newVector*(data: seq[uint8]): Vector =
  return Vector(kind: DuckType.UTinyInt, valueUTinyint: data)

proc newVector*(data: seq[uint16]): Vector =
  return Vector(kind: DuckType.USmallInt, valueUSmallint: data)

proc newVector*(data: seq[uint32]): Vector =
  return Vector(kind: DuckType.UInteger, valueUInteger: data)

proc newVector*(data: seq[uint64]): Vector =
  return Vector(kind: DuckType.UBigInt, valueUBigint: data)

proc newVector*(data: seq[float32]): Vector =
  return Vector(kind: DuckType.Float, valueFloat: data)

proc newVector*(data: seq[float64]): Vector =
  return Vector(kind: DuckType.Double, valueDouble: data)

proc newVector*(data: seq[Timestamp]): Vector =
  return Vector(kind: DuckType.Timestamp, valueTimestamp: data)

proc newVector*(data: seq[Time]): Vector =
  return Vector(kind: DuckType.Time, valueTime: data)

proc newVector*(data: seq[TimeInterval]): Vector =
  return Vector(kind: DuckType.Interval, valueInterval: data)

proc newVector*(data: seq[Int128]): Vector =
  return Vector(kind: DuckType.HugeInt, valueHugeint: data)

proc newVector*(data: seq[string]): Vector =
  return Vector(kind: DuckType.Varchar, valueVarchar: data)

proc newVector*(data: seq[seq[byte]]): Vector =
  return Vector(kind: DuckType.Blob, valueBlob: data)

proc newVector*(data: seq[DecimalType]): Vector =
  return Vector(kind: DuckType.Decimal, valueDecimal: data)

proc newVector*(data: seq[uint]): Vector =
  return Vector(kind: DuckType.Enum, valueEnum: data)

proc newVector*(data: seq[seq[Value]]): Vector =
  return Vector(kind: DuckType.List, valueList: data)

proc newVector*(data: seq[Table[string, Value]]): Vector =
  return Vector(kind: DuckType.Struct, valueStruct: data)

proc newVector*(data: seq[Uuid]): Vector =
  return Vector(kind: DuckType.UUID, valueUuid: data)

# proc newVector*(data: seq[string]): Vector =
#   return Vector(kind: DuckType.Bit, valueBit: data, mask: newValidityMask())

proc newVector*(data: seq[ZonedTime]): Vector =
  return Vector(kind: DuckType.TimeTz, valueTimeTz: data)

proc newVector*(data: seq[int | int64]): Vector =
  return Vector(kind: DuckType.BigInt, valueBigint: data.map(e => int64(e)))

template handleVectorCase(data: var untyped, handle, size, cType: untyped) =
  data.setLen(size)
  let raw = cast[ptr UncheckedArray[cType]](handle)
  if size > 0:
    copyMem(data[0].addr, raw[offset].addr, size * sizeof(type(data[0])))

template handleVectorCase(data: var untyped, handle, size, cType, caster: untyped) =
  data.setLen(size)
  let raw = cast[ptr UncheckedArray[cType]](handle)
  for i in offset ..< size:
    data[i] = caster(raw[i])

template handleVectorCaseString(data: var untyped, handle, size: untyped) =
  data.setLen(size)
  let raw = cast[ptr UncheckedArray[duckdbstringt]](handle)
  for i in offset ..< size:
    if duckdb_string_is_inlined(raw[i]):
      let stringStruct = cast[struct_duckdb_string_t_value_t_inlined_t](raw[i])
      var output = newString(stringStruct.length)
      for e in 0 ..< stringStruct.length.int:
        output[e] = char(stringStruct.inlined[e])
      data[i] = output
    else:
      let stringStruct = cast[struct_duckdb_string_t_value_t](raw[i])
      var output = $cast[cstring](stringStruct.pointer.ptr_field)
      output.setLen(stringStruct.pointer.length)
      data[i] = output

# TODO: this is most likelly wrong
template handleVectorCaseBlob(data: var untyped, handle, size: untyped) =
  data.setLen(size)
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

proc newVector*(
    duckVector: duckdbVector,
    size: int,
    offset: int,
    kind: DuckType,
    logicalType: LogicalType,
): Vector =
  let
    handle = duckdbVectorGetData(duckVector)
    validityMask = newValidityMask(duckVector, size)

  result = Vector(kind: kind)

  if not isNil(validityMask.handle):
    for i in 0 ..< validityMask.size:
      result.mask.add(validityMask.handle[i])

  case kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    raise newException(ValueError, fmt"got invalid enum type: {kind}")
  of DuckType.Boolean:
    handleVectorCase(result.valueBoolean, handle, size, uint8)
  of DuckType.TinyInt:
    handleVectorCase(result.valueTinyint, handle, size, int8)
  of DuckType.SmallInt:
    handleVectorCase(result.valueSmallint, handle, size, int16)
  of DuckType.Integer:
    handleVectorCase(result.valueInteger, handle, size, int32)
  of DuckType.BigInt:
    handleVectorCase(result.valueBigint, handle, size, int64)
  of DuckType.UTinyInt:
    handleVectorCase(result.valueUtinyint, handle, size, uint8)
  of DuckType.USmallInt:
    handleVectorCase(result.valueUSmallint, handle, size, uint16)
  of DuckType.UInteger:
    handleVectorCase(result.valueUInteger, handle, size, uint32)
  of DuckType.UBigInt:
    handleVectorCase(result.valueUBigint, handle, size, uint64)
  of DuckType.Float:
    handleVectorCase(result.valueFloat, handle, size, float32)
  of DuckType.Double:
    handleVectorCase(result.valueDouble, handle, size, float64)
  of DuckType.Timestamp:
    handleVectorCase(result.valueTimeStamp, handle, size, int64, fromTimestamp)
  of DuckType.Date:
    handleVectorCase(result.valueDate, handle, size, int32, fromDatetime)
  of DuckType.Time:
    handleVectorCase(result.valueTime, handle, size, int64, fromTime)
  of DuckType.Interval:
    handleVectorCase(result.valueInterval, handle, size, duckdbInterval, fromInterval)
  of DuckType.HugeInt:
    handleVectorCase(result.valueHugeInt, handle, size, duckdbHugeInt, fromHugeInt)
  of DuckType.VarChar:
    handleVectorCaseString(result.valueVarchar, handle, size)
  of DuckType.Blob:
    handleVectorCaseBlob(result.valueBlob, handle, size)
  of DuckType.Decimal:
    let
      scale = duckdb_decimal_scale(logicalType.handle).int
      width = duckdb_decimal_width(logicalType.handle).int
    if width <= 18:
      parseDecimalBigInt(result.valueDecimal, handle, size, scale)
    else:
      parseDecimalHugeInt(result.valueDecimal, handle, size, scale)
  of DuckType.TimestampS:
    # TODO: move this implemnetation to value
    result.valueTimestampS.setLen(size)
    let raw = cast[ptr UncheckedArray[int64]](handle)
    for i in offset ..< size:
      result.valueTimestampS[i] = fromUnix(raw[i]).inZone(utc())
  of DuckType.TimestampMs:
    # TODO: move this implemnetation to value
    result.valueTimestampMs.setLen(size)
    let raw = cast[ptr UncheckedArray[int64]](handle)
    for i in offset ..< size:
      let (seconds, milliseconds) = divmod(raw[i], 1000)
      result.valueTimestampMs[i] =
        fromUnix(seconds).inZone(utc()) + initDuration(milliseconds = milliseconds)
  of DuckType.TimestampNs:
    # TODO: move this implemnetation to value
    result.valueTimestampNs.setLen(size)
    let raw = cast[ptr UncheckedArray[int64]](handle)
    for i in offset ..< size:
      let
        (s, ns) = divMod(raw[i], 1_000_000_000)
        us = ns div 1000
        nsRem = ns mod 1000
      result.valueTimestampNs[i] =
        fromUnix(s).inZone(utc()) + initDuration(microseconds = us, nanoseconds = nsRem)
  of DuckType.Enum:
    let enum_tp = cast[DuckType](duckdbEnumInternalType(logicalType.handle))
    case enum_tp
    of UTinyInt:
      handleVectorCase(result.valueEnum, handle, size, uint8, uint)
    of USmallInt:
      handleVectorCase(result.valueEnum, handle, size, uint16, uint)
    of UInteger:
      handleVectorCase(result.valueEnum, handle, size, uint32, uint)
    else:
      raise newException(ValueError, fmt"got invalid enum type: {enum_tp}")
  of DuckType.List, DuckType.Array:
    let
      raw = cast[ptr UncheckedArray[duckdbListEntry]](handle)
      children = duckdbListVectorGetChild(duckVector)

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
      result.valueList[i] = childArray
  of DuckType.Struct:
    let childCount = duckdbStructTypeChildCount(logicalType.handle).int

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

    for i in offset ..< size:
      var row = initTable[string, Value]()
      for key, childVector in vectorStruct.pairs:
        row[key] = vecToValue(childVector, i)
      result.valueStruct[i] = row
  of DuckType.Map:
    let
      # don't know how to make use of key_type and value_type
      # key_type = newLogicalType(duckdb_map_type_key_type(logicalType.handle))
      # value_type = newLogicalType(duckdb_map_type_value_type(logicalType.handle))
      children = duckdbListVectorGetChild(duckVector)
      lsize = duckdbListVectorGetSize(duckVector)
      childType = newLogicalType(duckdbListTypeChildType(logicalType.handle))

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
      result.valueMap[i] = vectorMap
  # TODO: uuid is wrong
  of DuckType.UUID:
    let raw = cast[ptr UncheckedArray[duckdbHugeInt]](handle)

    for i in offset ..< size:
      let hugeInt = UInt128(lo: raw[i].lower.uint64, hi: raw[i].upper.uint64)
      result.valueUuid[i] = initUuid(hugeInt.toHex)

  # TODO: this is shit and fragile
  # TODO: some bugs, sometimes tags are missing
  of DuckType.Union:
    let
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

    for i in offset ..< size:
      for e in children.valueStruct:
        var row = initTable[string, Value]()
        for tag in tags:
          if $e[tag] != "":
            row[tag] = e[tag]
        result.valueUnion[i] = row
  # TODO: make tests to back this up
  of DuckType.Bit:
    result.valueBit =
      newVector(duckVector, size, offset, kind, logicalType).valueVarChar
  of DuckType.TimeTz:
    let raw = cast[ptr UncheckedArray[int64]](handle)

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
      result.valueTimeTz[i] = timeValue
  of DuckType.TimestampTz:
    raise newException(ValueError, "TimestampTz type not implemented")
  of DuckType.UHugeInt:
    result.valueUHugeInt.setLen(size)
    let raw = cast[ptr UncheckedArray[duckdbUHugeInt]](handle)
    for i in offset ..< size:
      result.valueUHugeInt[i] = fromUHugeInt(raw[i])

proc newVector*(duckVector: duckdbVector, size: int, offset: int = 0): Vector =
  let
    logicalType = newLogicalType(duckdbVectorGetColumnType(duckVector))
    kind = newDuckType(logicalType)
  return newVector(duckVector, size, offset, kind, logicalType)

proc `[]`*(v: Vector, idx: int): Value =
  return vecToValue(v, idx)

proc values*(vec: Vector, T: typedesc): lent seq[T] =
  when T is bool:
    case vec.kind
    of DuckType.Boolean:
      result = vec.valueBoolean
    else:
      raise newException(
        ValueError, "Type mismatch: requested bool but vector is " & $vec.kind
      )
  elif T is int8:
    case vec.kind
    of DuckType.TinyInt:
      result = vec.valueTinyint
    else:
      raise newException(
        ValueError, "Type mismatch: requested int8 but vector is " & $vec.kind
      )
  elif T is int16:
    case vec.kind
    of DuckType.SmallInt:
      result = vec.valueSmallint
    else:
      raise newException(
        ValueError, "Type mismatch: requested int16 but vector is " & $vec.kind
      )
  elif T is int32:
    case vec.kind
    of DuckType.Integer:
      result = vec.valueInteger
    else:
      raise newException(
        ValueError, "Type mismatch: requested int32 but vector is " & $vec.kind
      )
  elif T is int64:
    case vec.kind
    of DuckType.BigInt:
      result = vec.valueBigint
    else:
      raise newException(
        ValueError, "Type mismatch: requested int64 but vector is " & $vec.kind
      )
  elif T is uint8:
    case vec.kind
    of DuckType.UTinyInt:
      result = vec.valueUTinyint
    else:
      raise newException(
        ValueError, "Type mismatch: requested uint8 but vector is " & $vec.kind
      )
  elif T is uint16:
    case vec.kind
    of DuckType.USmallInt:
      result = vec.valueUSmallint
    else:
      raise newException(
        ValueError, "Type mismatch: requested uint16 but vector is " & $vec.kind
      )
  elif T is uint32:
    case vec.kind
    of DuckType.UInteger:
      result = vec.valueUInteger
    else:
      raise newException(
        ValueError, "Type mismatch: requested uint32 but vector is " & $vec.kind
      )
  elif T is uint64:
    case vec.kind
    of DuckType.UBigInt:
      result = vec.valueUBigint
    else:
      raise newException(
        ValueError, "Type mismatch: requested uint64 but vector is " & $vec.kind
      )
  elif T is uint:
    case vec.kind
    of DuckType.Enum:
      result = vec.valueEnum
    else:
      raise newException(
        ValueError, "Type mismatch: requested uint but vector is " & $vec.kind
      )
  elif T is float32:
    case vec.kind
    of DuckType.Float:
      result = vec.valueFloat
    else:
      raise newException(
        ValueError, "Type mismatch: requested float32 but vector is " & $vec.kind
      )
  elif T is float64:
    case vec.kind
    of DuckType.Double:
      result = vec.valueDouble
    else:
      raise newException(
        ValueError, "Type mismatch: requested float64 but vector is " & $vec.kind
      )
  elif T is string:
    case vec.kind
    of DuckType.Varchar:
      result = vec.valueVarchar
    of DuckType.Bit:
      result = vec.valueBit
    else:
      raise newException(
        ValueError, "Type mismatch: requested string but vector is " & $vec.kind
      )
  elif T is seq[byte]:
    case vec.kind
    of DuckType.Blob:
      result = vec.valueBlob
    else:
      raise newException(
        ValueError, "Type mismatch: requested seq[byte] but vector is " & $vec.kind
      )
  elif T is Timestamp:
    case vec.kind
    of DuckType.Timestamp:
      result = vec.valueTimestamp
    else:
      raise newException(
        ValueError, "Type mismatch: requested Timestamp but vector is " & $vec.kind
      )
  elif T is DateTime:
    case vec.kind
    of DuckType.Date:
      result = vec.valueDate
    of DuckType.TimestampS:
      result = vec.valueTimestampS
    of DuckType.TimestampMs:
      result = vec.valueTimestampMs
    of DuckType.TimestampNs:
      result = vec.valueTimestampNs
    else:
      raise newException(
        ValueError, "Type mismatch: requested DateTime but vector is " & $vec.kind
      )
  elif T is Time:
    case vec.kind
    of DuckType.Time:
      result = vec.valueTime
    else:
      raise newException(
        ValueError, "Type mismatch: requested Time but vector is " & $vec.kind
      )
  elif T is TimeInterval:
    case vec.kind
    of DuckType.Interval:
      result = vec.valueInterval
    else:
      raise newException(
        ValueError, "Type mismatch: requested TimeInterval but vector is " & $vec.kind
      )
  elif T is Int128:
    case vec.kind
    of DuckType.HugeInt:
      result = vec.valueHugeint
    else:
      raise newException(
        ValueError, "Type mismatch: requested Int128 but vector is " & $vec.kind
      )
  elif T is UInt128:
    case vec.kind
    of DuckType.UHugeInt:
      result = vec.valueUHugeint
    else:
      raise newException(
        ValueError, "Type mismatch: requested UInt128 but vector is " & $vec.kind
      )
  elif T is DecimalType:
    case vec.kind
    of DuckType.Decimal:
      result = vec.valueDecimal
    else:
      raise newException(
        ValueError, "Type mismatch: requested DecimalType but vector is " & $vec.kind
      )
  elif T is seq[Value]:
    case vec.kind
    of DuckType.List, DuckType.Array:
      result = vec.valueList
    else:
      raise newException(
        ValueError, "Type mismatch: requested seq[Value] but vector is " & $vec.kind
      )
  elif T is Table[string, Value]:
    case vec.kind
    of DuckType.Struct:
      result = vec.valueStruct
    of DuckType.Map:
      result = vec.valueMap
    of DuckType.Union:
      result = vec.valueUnion
    else:
      raise newException(
        ValueError,
        "Type mismatch: requested Table[string, Value] but vector is " & $vec.kind,
      )
  elif T is Uuid:
    case vec.kind
    of DuckType.UUID:
      result = vec.valueUUID
    else:
      raise newException(
        ValueError, "Type mismatch: requested Uuid but vector is " & $vec.kind
      )
  elif T is ZonedTime:
    case vec.kind
    of DuckType.TimeTz:
      result = vec.valueTimeTz
    of DuckType.TimestampTz:
      result = vec.valueTimestampTz
    else:
      raise newException(
        ValueError, "Type mismatch: requested ZonedTime but vector is " & $vec.kind
      )
  else:
    {.error: "Unsupported type for Vector.values: " & $T.}

proc `&=`*(left: var Vector, right: sink Vector): void =
  if left.kind != right.kind:
    raise newException(
      ValueError,
      fmt"Vector.kind:{left.kind} != Vector.kind:{right.kind}. Can't concatenate different kinds of vectors",
    )

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
