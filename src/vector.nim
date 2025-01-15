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
  of DuckType.List:
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
  of DuckType.List:
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

# has a bug when more chunks are present
proc isValid*(vec: Vector, idx: int): bool {.inline.} =
  let
    entryIdx = idx div BITS_PER_VALUE
    indexInEntry = idx mod BITS_PER_VALUE

  if entryIdx >= vec.mask.len:
    return true

  result = (vec.mask[entryIdx] and (1'u64 shl indexInEntry)) != 0

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
        var
          basePtr = cast[pointer](cast[uint](handle) + (i * sizeof(duckdbstringt)).uint)
          strLength = cast[ptr int32](basePtr)[]
          rawStr: cstring

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

template parseDecimalBigInt(
    handle: pointer, vec: Vector, scale: int, resultField: seq[DecimalType]
) =
  resultField = collectValid[int64, DecimalType](handle, vec, offset, size) do(
    val: int64
  ) -> DecimalType:
    let value = val.float / pow(10.float, scale.float)
    newDecimal($value)

template parseDecimalHugeInt(
    handle: pointer, vec: Vector, scale: int, resultField: seq[DecimalType]
) =
  resultField = collectValid[duckdb_hugeint, DecimalType](handle, vec, offset, size) do(
    val: duckdb_hugeint
  ) -> DecimalType:
    let
      value = Int128(hi: val.upper.int64, lo: val.lower.uint64)
      fractional = cast[float](value) / pow(10.float, scale.float)
    newDecimal($fractional)

proc vecToValue*(vec: Vector, idx: int): Value =
  let isValid = vec.isValid(idx)
  case vec.kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    raise newException(ValueError, fmt"got invalid enum type: {vec.kind}")
  of DuckType.Boolean:
    result = newValue(vec.valueBoolean[idx], isValid)
  of DuckType.TinyInt:
    result = newValue(vec.valueTinyint[idx], isValid)
  of DuckType.SmallInt:
    result = newValue(vec.valueSmallint[idx], isValid)
  of DuckType.Integer:
    result = newValue(vec.valueInteger[idx], isValid)
  of DuckType.BigInt:
    result = newValue(vec.valueBigint[idx], isValid)
  of DuckType.UTinyInt:
    result = newValue(vec.valueUTinyint[idx], isValid)
  of DuckType.USmallInt:
    result = newValue(vec.valueUSmallint[idx], isValid)
  of DuckType.UInteger:
    result = newValue(vec.valueUInteger[idx], isValid)
  of DuckType.UBigInt:
    result = newValue(vec.valueUBigint[idx], isValid)
  of DuckType.Float:
    result = newValue(vec.valueFloat[idx], isValid)
  of DuckType.Double:
    result = newValue(vec.valueDouble[idx], isValid)
  of DuckType.Timestamp:
    result = newValue(vec.valueTimestamp[idx], vec.kind, isValid)
  of DuckType.TimestampS:
    result = newValue(vec.valueTimestampS[idx], vec.kind, isValid)
  of DuckType.TimestampMs:
    result = newValue(vec.valueTimestampMs[idx], vec.kind, isValid)
  of DuckType.TimestampNs:
    result = newValue(vec.valueTimestampNs[idx], vec.kind, isValid)
  of DuckType.Date:
    result = newValue(vec.valueDate[idx], vec.kind, isValid)
  of DuckType.Time:
    result = newValue(vec.valueTime[idx], isValid)
  of DuckType.Interval:
    result = newValue(vec.valueInterval[idx], isValid)
  of DuckType.HugeInt:
    result = newValue(vec.valueHugeint[idx], isValid)
  of DuckType.Varchar:
    result = newValue(vec.valueVarchar[idx], isValid)
  of DuckType.Blob:
    result = newValue(vec.valueBlob[idx], isValid)
  of DuckType.Decimal:
    result = newValue(vec.valueDecimal[idx], isValid)
  of DuckType.Enum:
    result = newValue(vec.valueEnum[idx], isValid)
  of DuckType.List:
    result = newValue(vec.valueList[idx], isValid)
  of DuckType.Struct:
    result = newValue(vec.valueStruct[idx], vec.kind, isValid)
  of DuckType.Map:
    result = newValue(vec.valueMap[idx], vec.kind, isValid)
  of DuckType.UUID:
    result = newValue(vec.valueUuid[idx], isValid)
  of DuckType.Union:
    result = newValue(vec.valueUnion[idx], vec.kind, isValid)
  of DuckType.Bit:
    result = newValue(vec.valueBit[idx], vec.kind, isValid)
  of DuckType.TimeTz:
    result = newValue(vec.valueTimeTz[idx], isValid)

iterator items*(vec: Vector): Value =
  for idx in 0 ..< vec.len:
    yield vecToValue(vec, idx)

proc newVector*(kind: DuckType): Vector =
  result = Vector(kind: kind)
  case kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    raise newException(ValueError, fmt"got invalid enum type: {kind}")
  of DuckType.Boolean:
    result.valueBoolean = newSeq[bool]()
  of DuckType.TinyInt:
    result.valueTinyint = newSeq[int8]()
  of DuckType.SmallInt:
    result.valueSmallint = newSeq[int16]()
  of DuckType.Integer:
    result.valueInteger = newSeq[int32]()
  of DuckType.BigInt:
    result.valueBigint = newSeq[int64]()
  of DuckType.UTinyInt:
    result.valueUTinyint = newSeq[uint8]()
  of DuckType.USmallInt:
    result.valueUSmallint = newSeq[uint16]()
  of DuckType.UInteger:
    result.valueUInteger = newSeq[uint32]()
  of DuckType.UBigInt:
    result.valueUBigint = newSeq[uint64]()
  of DuckType.Float:
    result.valueFloat = newSeq[float32]()
  of DuckType.Double:
    result.valueDouble = newSeq[float64]()
  of DuckType.Timestamp:
    result.valueTimestamp = newSeq[DateTime]()
  of DuckType.Date:
    result.valueDate = newSeq[DateTime]()
  of DuckType.Time:
    result.valueTime = newSeq[Time]()
  of DuckType.Interval:
    result.valueInterval = newSeq[TimeInterval]()
  of DuckType.HugeInt:
    result.valueHugeint = newSeq[Int128]()
  of DuckType.Varchar:
    result.valueVarchar = newSeq[string]()
  of DuckType.Blob:
    result.valueBlob = newSeq[seq[byte]]()
  of DuckType.Decimal:
    result.valueDecimal = newSeq[DecimalType]()
  of DuckType.TimestampS:
    result.valueTimestampS = newSeq[DateTime]()
  of DuckType.TimestampMs:
    result.valueTimestampMs = newSeq[DateTime]()
  of DuckType.TimestampNs:
    result.valueTimestampNs = newSeq[DateTime]()
  of DuckType.Enum:
    result.valueEnum = newSeq[uint]()
  of DuckType.List:
    result.valueList = newSeq[seq[Value]]()
  of DuckType.Struct, DuckType.Map:
    result.valueStruct = newSeq[Table[string, Value]]()
  of DuckType.UUID:
    result.valueUuid = newSeq[Uuid]()
  of DuckType.Union:
    result.valueUnion = newSeq[Table[string, Value]]()
  of DuckType.Bit:
    result.valueBit = newSeq[string]()
  of DuckType.TimeTz:
    result.valueTimeTz = newSeq[ZonedTime]()
  # of DuckType.TimestampTz:    result.valueTimestampTz = newSeq[tuple[timestamp: Time, timezone: string]]()
  # of DuckType.UHugeInt:       result.valueUHugeint    = newSeq[tuple[high: uint64, low: uint64]]()
  # of DuckType.Array:          result.valueArray       = newSeq[Vector]()

proc newVector*(data: seq[bool]): Vector =
  result = Vector(kind: DuckType.Boolean, valueBoolean: data, mask: newValidityMask())

proc newVector*(data: seq[int8]): Vector =
  result = Vector(kind: DuckType.TinyInt, valueTinyint: data, mask: newValidityMask())

proc newVector*(data: seq[int16]): Vector =
  result = Vector(kind: DuckType.SmallInt, valueSmallint: data, mask: newValidityMask())

proc newVector*(data: seq[int32]): Vector =
  result = Vector(kind: DuckType.Integer, valueInteger: data, mask: newValidityMask())

proc newVector*(data: seq[int64]): Vector =
  result = Vector(kind: DuckType.BigInt, valueBigint: data, mask: newValidityMask())

proc newVector*(data: seq[uint8]): Vector =
  result = Vector(kind: DuckType.UTinyInt, valueUTinyint: data, mask: newValidityMask())

proc newVector*(data: seq[uint16]): Vector =
  result =
    Vector(kind: DuckType.USmallInt, valueUSmallint: data, mask: newValidityMask())

proc newVector*(data: seq[uint32]): Vector =
  result = Vector(kind: DuckType.UInteger, valueUInteger: data, mask: newValidityMask())

proc newVector*(data: seq[uint64]): Vector =
  result = Vector(kind: DuckType.UBigInt, valueUBigint: data, mask: newValidityMask())

proc newVector*(data: seq[float32]): Vector =
  result = Vector(kind: DuckType.Float, valueFloat: data, mask: newValidityMask())

proc newVector*(data: seq[float64]): Vector =
  result = Vector(kind: DuckType.Double, valueDouble: data, mask: newValidityMask())

proc newVector*(data: seq[DateTime]): Vector =
  result =
    Vector(kind: DuckType.Timestamp, valueTimestamp: data, mask: newValidityMask())

proc newVector*(data: seq[Time]): Vector =
  result = Vector(kind: DuckType.Time, valueTime: data, mask: newValidityMask())

proc newVector*(data: seq[TimeInterval]): Vector =
  result = Vector(kind: DuckType.Interval, valueInterval: data, mask: newValidityMask())

proc newVector*(data: seq[Int128]): Vector =
  result = Vector(kind: DuckType.HugeInt, valueHugeint: data, mask: newValidityMask())

proc newVector*(data: seq[string]): Vector =
  result = Vector(kind: DuckType.Varchar, valueVarchar: data, mask: newValidityMask())

proc newVector*(data: seq[seq[byte]]): Vector =
  result = Vector(kind: DuckType.Blob, valueBlob: data, mask: newValidityMask())

proc newVector*(data: seq[DecimalType]): Vector =
  result = Vector(kind: DuckType.Decimal, valueDecimal: data, mask: newValidityMask())

proc newVector*(data: seq[uint]): Vector =
  result = Vector(kind: DuckType.Enum, valueEnum: data, mask: newValidityMask())

proc newVector*(data: seq[seq[Value]]): Vector =
  result = Vector(kind: DuckType.List, valueList: data, mask: newValidityMask())

proc newVector*(data: seq[Table[string, Value]]): Vector =
  result = Vector(kind: DuckType.Struct, valueStruct: data, mask: newValidityMask())

proc newVector*(data: seq[Uuid]): Vector =
  result = Vector(kind: DuckType.UUID, valueUuid: data, mask: newValidityMask())

# proc newVector*(data: seq[string]): Vector =
#   result = Vector(kind: DuckType.Bit, valueBit: data, mask: newValidityMask())

proc newVector*(data: seq[ZonedTime]): Vector =
  result = Vector(kind: DuckType.TimeTz, valueTimeTz: data, mask: newValidityMask())

proc newVector*(data: seq[int | int64]): Vector =
  result = Vector(
    kind: DuckType.BigInt, valueBigint: data.map(e => int64(e)), mask: newValidityMask()
  )

proc newVector*(
    vec: duckdb_vector, offset: int, size: int, kind: DuckType, logicalType: LogicalType
): Vector =
  result = Vector(kind: kind, mask: newValidityMask(vec, size))
  let handle = duckdb_vector_get_data(vec)

  # TODO: abstract a lot of duplication around here
  case kind
  of DuckType.Invalid, DuckType.Any, DuckType.VarInt, DuckType.SqlNull:
    raise newException(ValueError, fmt"got invalid enum type: {kind}")
  of DuckType.Boolean:
    parseHandle(handle, result, uint8, result.valueBoolean, bool)
  of DuckType.TinyInt:
    parseHandle(handle, result, int8, result.valueTinyint)
  of DuckType.SmallInt:
    parseHandle(handle, result, int16, result.valueSmallint)
  of DuckType.Integer:
    parseHandle(handle, result, cint, result.valueInteger, int32)
  of DuckType.BigInt:
    parseHandle(handle, result, int64, result.valueBigint)
  of DuckType.UTinyInt:
    parseHandle(handle, result, uint8, result.valueUtinyint)
  of DuckType.USmallInt:
    parseHandle(handle, result, uint16, result.valueUSmallint)
  of DuckType.UInteger:
    parseHandle(handle, result, uint32, result.valueUInteger)
  of DuckType.UBigInt:
    parseHandle(handle, result, uint64, result.valueUBigint)
  of DuckType.Float:
    parseHandle(handle, result, float32, result.valueFloat)
  of DuckType.Double:
    parseHandle(handle, result, float64, result.valueDouble)
  of DuckType.Timestamp:
    result.valueTimestamp = collectValid[int64, DateTime](handle, result, offset, size) do(
      val: int64
    ) -> DateTime:
      let
        seconds = val div 1000000
        microseconds = val mod 1000000
      fromUnix(seconds).inZone(utc()) + initDuration(microseconds = microseconds)
  of DuckType.Date:
    result.valueDate = collectValid[int32, DateTime](handle, result, offset, size) do(
      val: int32
    ) -> DateTime:
      inZone(fromUnix(val.int32 * SECONDS_PER_DAY), utc())
  of DuckType.Time:
    result.valueTime = collectValid[int64, Time](handle, result, offset, size) do(
      val: int64
    ) -> Time:
      let
        nanos = val * 1000 # Convert microseconds to nanoseconds
        seconds = nanos div 1_000_000_000
        remainingNanos = nanos mod 1_000_000_000
      initTime(seconds.int, remainingNanos.int)
  of DuckType.Interval:
    result.valueInterval = collectValid[duckdbInterval, TimeInterval](
      handle, result, offset, size
    ) do(val: duckdbInterval) -> TimeInterval:
      initTimeInterval(months = val.months, days = val.days, microseconds = val.micros)
  of DuckType.HugeInt:
    result.valueHugeInt = collectValid[duckdb_hugeint, Int128](
      handle, result, offset, size
    ) do(val: duckdb_hugeint) -> Int128:
      Int128(hi: val.upper.int64, lo: val.lower.uint64)
  of DuckType.VarChar:
    collectValidString[string](handle, result, offset, size, result.valueVarChar) do(
      rawStr: cstring
    ) -> string:
      $rawStr
  of DuckType.Blob:
    collectValidString[seq[byte]](handle, result, offset, size, result.valueBlob) do(
      rawStr: cstring
    ) -> seq[byte]:
      var byteArray = newSeq[byte](rawStr.len)
      copyMem(addr byteArray[0], unsafeAddr rawStr[0], rawStr.len)
      byteArray
  of DuckType.Decimal:
    let
      scale = duckdb_decimal_scale(logicalType.handle).int
      width = duckdb_decimal_width(logicalType.handle).int
    if width <= 18:
      parseDecimalBigInt(handle, result, scale, result.valueDecimal)
    else:
      parseDecimalHugeInt(handle, result, scale, result.valueDecimal)
  of DuckType.TimestampS:
    result.valueTimestampS = collectValid[int64, DateTime](handle, result, offset, size) do(
      val: int64
    ) -> DateTime:
      fromUnix(val).inZone(utc())
  of DuckType.TimestampMs:
    result.valueTimestampMs = collectValid[int64, DateTime](
      handle, result, offset, size
    ) do(val: int64) -> DateTime:
      fromUnix(val div 1000).inZone(utc()) + initDuration(milliseconds = val mod 1000)
  of DuckType.TimestampNs:
    result.valueTimestampNs = collectValid[int64, Datetime](
      handle, result, offset, size
    ) do(val: int64) -> DateTime:
      let
        seconds = val div 1_000_000_000
        microseconds = val mod 1_000_000_000 div 1000
      fromUnix(seconds).inZone(utc()) + initDuration(microseconds = microseconds)
  # TODO: not sure if this needs to be the ord or the label
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
  of DuckType.List:
    let
      raw = cast[ptr UncheckedArray[duckdb_list_entry]](handle)
      children = duckdb_list_vector_get_child(vec)

    for i in offset ..< size:
      if isValid(result, i):
        let
          list_data = raw[i]
          child_type = newLogicalType(duckdb_list_type_child_type(logicalType.handle))
          child = newVector(
            vec = children,
            offset = list_data.offset.int,
            size = (list_data.offset + list_data.length).int,
            kind = newDuckType(child_type),
            logicalType = child_type,
          )
        var child_array = newSeq[Value]()
        for c in child:
          child_array.add(cast[Value](c))
        result.valueList.add(child_array)
  of DuckType.Struct:
    let child_count = duckdb_struct_type_child_count(logicalType.handle).int
    var vectorStruct = initTable[string, Vector]()
    for child_idx in 0 ..< child_count:
      let
        children = duckdb_struct_vector_get_child(vec, child_idx.idx_t)
        child_type = newLogicalType(
          duckdb_struct_type_child_type(logicalType.handle, child_idx.idx_t)
        )
        child_name = newDuckString(
          duckdb_struct_type_child_name(logicalType.handle, child_idx.idx_t)
        )
        child = newVector(
          vec = children,
          offset = offset,
          size = size,
          kind = newDuckType(child_type),
          logicalType = child_type,
        )

      vectorStruct[$child_name] = child
    result.valueStruct = collect:
      for i in offset ..< size:
        var row = initTable[string, Value]()
        for key, child_vector in vectorStruct.pairs:
          row[key] = vecToValue(child_vector, i)
        row
  of DuckType.Map:
    let
      # don't know how to make use of key_type and value_type
      # key_type = newLogicalType(duckdb_map_type_key_type(logicalType.handle))
      # value_type = newLogicalType(duckdb_map_type_value_type(logicalType.handle))
      children = duckdb_list_vector_get_child(vec)
      lsize = duckdb_list_vector_get_size(vec)
      child_type = newLogicalType(duckdb_list_type_child_type(logicalType.handle))

    result.valueMap = collect:
      for i in 0 ..< size:
        var vectorMap = initTable[string, Value]()
        let elements = newVector(
          vec = children,
          offset = 0,
          size = lsize.int,
          kind = newDuckType(child_type),
          logicalType = child_type,
        )
        for e in elements.valueStruct:
          vectorMap[$e["key"]] = e["value"]
        vectorMap
  # TODO: uuid is wrong
  of DuckType.UUID:
    result.valueUuid = collectValid[duckdb_hugeint, Uuid](handle, result, offset, size) do(
      val: duckdb_hugeint
    ) -> Uuid:
      let huge_int = UInt128(lo: val.lower.uint64, hi: val.upper.uint64)
      initUuid(huge_int.toHex)
  # TODO: this is shit and fragile
  # TODO: some bugs, sometimes tags are missing
  of DuckType.Union:
    let
      children =
        newVector(vec, offset, size, kind = DuckType.Struct, logicalType = logicalType)
      child_count = len(children)

    var tags = newSeq[string]()
    for child_idx in 0 ..< child_count:
      let child_name = newDuckString(
        duckdb_struct_type_child_name(logicalType.handle, child_idx.idx_t)
      )
      if $child_name != "":
        tags.add($child_name)

    result.valueUnion = collect:
      for e in children.valueStruct:
        var row = initTable[string, Value]()
        for tag in tags:
          if $e[tag] != "":
            row[tag] = e[tag]
            row
  of DuckType.Bit:
    result.valueBit = newVector(
      vec, offset, size, kind = DuckType.Varchar, logicalType = logicalType
    ).valueVarChar
  of DuckType.TimeTz:
    result = newVector(kind = kind)
    result.valueTimeTz = collectValid[int64, ZonedTime](handle, result, offset, size) do(
      val: int64
    ) -> ZonedTime:
      let
        tmz = duckdb_from_time_tz(cast[duckdb_time_tz](val))
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

      let tz = newTimezone("Something", zonedTimeFromTime, zonedTimeFromAdjTime)
      let timeValue = zonedTimeFromTime(tz, tm)
      timeValue

proc `[]`*(v: Vector, idx: int): Value =
  result = vecToValue(v, idx)

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
  of DuckType.List:
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
