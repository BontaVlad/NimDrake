## Recursive materialization helpers for DuckDB complex types.
##
## Two complementary layers:
##
## **Layer A — typed single-level helpers** (``toList``, ``toArray``,
## ``toStructPairs``, ``toStructChild``, ``toMap``, ``toUnion``).
## Return concrete Nim types with static type dispatch.  No runtime kind tag
## and no recursion into children beyond the declared child types.
##
## **Layer B — sum-type ``NimValue``** + ``toNimValue`` recursive
## materializer. Fully generic row-by-row materialization with inline scalar
## values and recursively allocated containers.
## For ad-hoc querying where the column shape is not known statically.
##
## ``NimValue`` preserves integer widths losslessly: signed 64-bit values map
## to ``nvInt``, unsigned 64-bit to ``nvUInt``, and HUGEINT to ``nvHuge``
## (``Int128``). Temporal, UUID, decimal, and enum values retain their native
## value representations as well.
##
## The zero-copy descent procs in ``qresult.nim`` remain the hot path for
## performance-sensitive code.

import std/[tables, hashes, times, options]
import nint128

import /[ffi, types, qresult, codec]

# ---------------------------------------------------------------------------
# NimValue — sum-type materialized value
# ---------------------------------------------------------------------------

type
  NimValueKind* = enum ## The materialized value categories a `NimValue` can hold.
    nvBool
    nvInt
    nvUInt
    nvHuge
    nvUHuge
    nvUUID
    nvFloat
    nvTimestamp
    nvTimestampS
    nvTimestampMs
    nvTimestampNs
    nvDate
    nvTime
    nvTimeTz
    nvTimestampTz
    nvInterval
    nvDecimal
    nvEnum
    nvString
    nvBlob
    nvList
    nvStruct
    nvMap
    nvUnion
    nvNull

  NimValue* = object ## Value-oriented materialized cell of any DuckDB kind.
    ## Scalar cells are stored inline. Recursive containers use seq storage;
    ## UNION keeps one ref only for its recursive member value.
    case kind*: NimValueKind
    of nvBool:   boolVal*: bool
    of nvInt:    intVal*: int64
    of nvUInt:   uintVal*: uint64
    of nvHuge:   hugeVal*: Int128
    of nvUHuge:  uhugeVal*: UInt128
    of nvUUID:   uuidVal*: Uuid
    of nvFloat:  floatVal*: float64
    of nvTimestamp: timestampVal*: Timestamp
    of nvTimestampS: timestampSVal*: DateTime
    of nvTimestampMs: timestampMsVal*: DateTime
    of nvTimestampNs: timestampNsVal*: DateTime
    of nvDate: dateVal*: DateTime
    of nvTime: timeVal*: Time
    of nvTimeTz: timeTzVal*: ZonedTime
    of nvTimestampTz: timestampTzVal*: ZonedTime
    of nvInterval: intervalVal*: TimeInterval
    of nvDecimal:
      decimalRaw*: Int128
      decimalWidth*: int8
      decimalScale*: int8
    of nvEnum:
      enumVal*: uint
      enumLabels*: ref seq[string]
    of nvString: strVal*: string
    of nvBlob:   blobVal*: seq[byte]
    of nvList:   listVal*: seq[NimValue]
    of nvStruct: fields*: seq[(string, NimValue)]
    of nvMap:    mapVal*: seq[(NimValue, NimValue)]
    of nvUnion:
      memberName*: string
      memberVal*: ref NimValue
    of nvNull:   discard

proc refValue(value: NimValue): ref NimValue =
  new(result)
  result[] = value

func `==`*(a, b: NimValue): bool =
  ## Structural equality for value-oriented materialized values.
  if a.kind != b.kind:
    return false
  case a.kind
  of nvBool:   a.boolVal == b.boolVal
  of nvInt:    a.intVal == b.intVal
  of nvUInt:   a.uintVal == b.uintVal
  of nvHuge:   a.hugeVal == b.hugeVal
  of nvUHuge:  a.uhugeVal == b.uhugeVal
  of nvUUID:   a.uuidVal == b.uuidVal
  of nvFloat:  a.floatVal == b.floatVal
  of nvTimestamp: a.timestampVal == b.timestampVal
  of nvTimestampS: a.timestampSVal == b.timestampSVal
  of nvTimestampMs: a.timestampMsVal == b.timestampMsVal
  of nvTimestampNs: a.timestampNsVal == b.timestampNsVal
  of nvDate: a.dateVal == b.dateVal
  of nvTime: a.timeVal == b.timeVal
  of nvTimeTz: a.timeTzVal == b.timeTzVal
  of nvTimestampTz: a.timestampTzVal == b.timestampTzVal
  of nvInterval: a.intervalVal == b.intervalVal
  of nvDecimal:
    a.decimalRaw == b.decimalRaw and a.decimalWidth == b.decimalWidth and
      a.decimalScale == b.decimalScale
  of nvEnum:
    a.enumVal == b.enumVal and a.enumLabels == b.enumLabels
  of nvString: a.strVal == b.strVal
  of nvBlob:   a.blobVal == b.blobVal
  of nvList:   a.listVal == b.listVal
  of nvStruct: a.fields == b.fields
  of nvMap:    a.mapVal == b.mapVal
  of nvUnion:  a.memberName == b.memberName and a.memberVal[] == b.memberVal[]
  of nvNull:   true

func hash*(v: NimValue): Hash =
  ## Content hash, consistent with `==`.
  result = hash(v.kind)
  case v.kind
  of nvBool:   result = result !& hash(v.boolVal)
  of nvInt:    result = result !& hash(v.intVal)
  of nvUInt:   result = result !& hash(v.uintVal)
  of nvHuge:   result = result !& hash(v.hugeVal)
  of nvUHuge:  result = result !& hash(v.uhugeVal)
  of nvUUID:   result = result !& hash(v.uuidVal)
  of nvFloat:  result = result !& hash(v.floatVal)
  of nvTimestamp:
    let t = v.timestampVal.toTime
    result = result !& hash(t.toUnix)
    result = result !& hash(t.nanosecond)
  of nvTimestampS, nvTimestampMs, nvTimestampNs, nvDate:
    let t =
      case v.kind
      of nvTimestampS: v.timestampSVal.toTime
      of nvTimestampMs: v.timestampMsVal.toTime
      of nvTimestampNs: v.timestampNsVal.toTime
      else: v.dateVal.toTime
    result = result !& hash(t.toUnix)
    result = result !& hash(t.nanosecond)
  of nvTime:
    result = result !& hash(v.timeVal.toUnix)
    result = result !& hash(v.timeVal.nanosecond)
  of nvTimeTz:
    result = result !& hash(v.timeTzVal.time.toUnix)
    result = result !& hash(v.timeTzVal.time.nanosecond)
    result = result !& hash(v.timeTzVal.utcOffset)
    result = result !& hash(v.timeTzVal.isDst)
  of nvTimestampTz:
    result = result !& hash(v.timestampTzVal.time.toUnix)
    result = result !& hash(v.timestampTzVal.time.nanosecond)
    result = result !& hash(v.timestampTzVal.utcOffset)
    result = result !& hash(v.timestampTzVal.isDst)
  of nvInterval:
    result = result !& hash(v.intervalVal.years)
    result = result !& hash(v.intervalVal.months)
    result = result !& hash(v.intervalVal.days)
    result = result !& hash(v.intervalVal.hours)
    result = result !& hash(v.intervalVal.minutes)
    result = result !& hash(v.intervalVal.seconds)
    result = result !& hash(v.intervalVal.microseconds)
  of nvDecimal:
    result = result !& hash(v.decimalRaw)
    result = result !& hash(v.decimalWidth)
    result = result !& hash(v.decimalScale)
  of nvEnum:
    result = result !& hash(v.enumVal)
    if v.enumLabels != nil:
      result = result !& hash(v.enumLabels[])
  of nvString: result = result !& hash(v.strVal)
  of nvBlob:   result = result !& hash(v.blobVal)
  of nvList:
    for item in v.listVal:
      result = result !& hash(item)
  of nvStruct:
    for (name, item) in v.fields:
      result = result !& hash(name)
      result = result !& hash(item)
  of nvMap:
    for (key, val) in v.mapVal:
      result = result !& hash(key)
      result = result !& hash(val)
  of nvUnion:
    result = result !& hash(v.memberName)
    result = result !& hash(v.memberVal[])
  of nvNull: discard
  result = !$result

proc appendFormat(result: var string, v: NimValue, quoteStr: bool) =
  proc formatUuid(value: Uuid): string =
    const hex = "0123456789abcdef"
    let bytes = value.bytes
    result = newStringOfCap(36)
    for i, byte in bytes:
      if i in {4, 6, 8, 10}:
        result.add '-'
      result.add hex[int(byte shr 4)]
      result.add hex[int(byte and 0x0f)]

  proc enumName(value: NimValue): string =
    if value.enumLabels != nil and value.enumVal < value.enumLabels[].len.uint:
      value.enumLabels[][value.enumVal]
    else:
      $value.enumVal

  case v.kind
  of nvBool:
    result.add if v.boolVal: "true" else: "false"
  of nvInt:
    result.add $v.intVal
  of nvUInt:
    result.add $v.uintVal
  of nvHuge:
    result.add $v.hugeVal
  of nvUHuge:
    result.add $v.uhugeVal
  of nvUUID:
    result.add formatUuid(v.uuidVal)
  of nvFloat:
    result.add $v.floatVal
  of nvTimestamp:
    result.add $v.timestampVal
  of nvTimestampS:
    result.add $v.timestampSVal
  of nvTimestampMs:
    result.add $v.timestampMsVal
  of nvTimestampNs:
    result.add $v.timestampNsVal
  of nvDate:
    result.add $v.dateVal
  of nvTime:
    result.add $v.timeVal
  of nvTimeTz:
    result.add $v.timeTzVal
  of nvTimestampTz:
    result.add $v.timestampTzVal
  of nvInterval:
    result.add $v.intervalVal
  of nvDecimal:
    appendDuckDecimal(result, v.decimalRaw, v.decimalScale)
  of nvEnum:
    result.add enumName(v)
  of nvString:
    if quoteStr:
      result.add '\''
      for ch in v.strVal:
        result.add ch
        if ch == '\'':
          result.add '\''
      result.add '\''
    else:
      result.add v.strVal
  of nvBlob:
    const hex = "0123456789abcdef"
    result.add "'\\x"
    for b in v.blobVal:
      result.add hex[int(b shr 4)]
      result.add hex[int(b and 0x0f)]
    result.add '\''
  of nvList:
    result.add '['
    for i, item in v.listVal:
      if i > 0:
        result.add ", "
      appendFormat(result, item, quoteStr)
    result.add ']'
  of nvStruct:
    result.add '{'
    for i, field in v.fields:
      if i > 0:
        result.add ", "
      result.add '\''
      result.add field[0]
      result.add "': "
      appendFormat(result, field[1], false)
    result.add '}'
  of nvMap:
    result.add '{'
    for i, pair in v.mapVal:
      if i > 0:
        result.add ", "
      appendFormat(result, pair[0], false)
      result.add '='
      appendFormat(result, pair[1], false)
    result.add '}'
  of nvUnion:
    appendFormat(result, v.memberVal[], quoteStr)
  of nvNull:
    result.add "NULL"

proc formatVal(v: NimValue, quoteStr: bool = true): string =
  result = newStringOfCap(32)
  appendFormat(result, v, quoteStr)

proc `$`*(v: NimValue): string =
  ## Formats a `NimValue` in a SQL-ish literal syntax (lists, structs, maps
  ## bracket the children); NULL renders as `NULL`.
  formatVal(v, true)

# ---------------------------------------------------------------------------
# toNimValue — recursive materializer (Layer B)
# ---------------------------------------------------------------------------

proc toNimValue*(cv: ColumnView, i: int): NimValue =
  ## Recursively materializes row `i` of any column into a `NimValue`.
  if not cv.valid(i):
    return NimValue(kind: nvNull)
  case cv.kind
  of DuckType.Boolean:
    let v = cv.bindAs(DuckType.Boolean)
    result = NimValue(kind: nvBool, boolVal: v[i])
  of DuckType.TinyInt:
    let v = cv.bindAs(DuckType.TinyInt)
    result = NimValue(kind: nvInt, intVal: int64(v[i]))
  of DuckType.SmallInt:
    let v = cv.bindAs(DuckType.SmallInt)
    result = NimValue(kind: nvInt, intVal: int64(v[i]))
  of DuckType.Integer:
    let v = cv.bindAs(DuckType.Integer)
    result = NimValue(kind: nvInt, intVal: int64(v[i]))
  of DuckType.BigInt:
    let v = cv.bindAs(DuckType.BigInt)
    result = NimValue(kind: nvInt, intVal: v[i])
  of DuckType.UTinyInt:
    let v = cv.bindAs(DuckType.UTinyInt)
    result = NimValue(kind: nvInt, intVal: int64(v[i]))
  of DuckType.USmallInt:
    let v = cv.bindAs(DuckType.USmallInt)
    result = NimValue(kind: nvInt, intVal: int64(v[i]))
  of DuckType.UInteger:
    let v = cv.bindAs(DuckType.UInteger)
    result = NimValue(kind: nvInt, intVal: int64(v[i]))
  of DuckType.UBigInt:
    let v = cv.bindAs(DuckType.UBigInt)
    result = NimValue(kind: nvUInt, uintVal: v[i])
  of DuckType.Float:
    let v = cv.bindAs(DuckType.Float)
    result = NimValue(kind: nvFloat, floatVal: float64(v[i]))
  of DuckType.Double:
    let v = cv.bindAs(DuckType.Double)
    result = NimValue(kind: nvFloat, floatVal: v[i])
  of DuckType.Varchar:
    let v = cv.bindAs(DuckType.Varchar)
    result = NimValue(kind: nvString, strVal: v[i])
  of DuckType.Bit:
    let v = cv.bindAs(DuckType.Bit)
    result = NimValue(kind: nvString, strVal: v[i])
  of DuckType.Blob:
    let v = cv.bindAs(DuckType.Blob)
    result = NimValue(kind: nvBlob, blobVal: v[i])
  of DuckType.HugeInt:
    let v = cv.bindAs(DuckType.HugeInt)
    result = NimValue(kind: nvHuge, hugeVal: v[i])
  of DuckType.UHugeInt:
    let v = cv.bindAs(DuckType.UHugeInt)
    result = NimValue(kind: nvUHuge, uhugeVal: v[i])
  of DuckType.UUID:
    let v = cv.bindAs(DuckType.UUID)
    result = NimValue(kind: nvUUID, uuidVal: v[i])
  of DuckType.Enum:
    let rawIdx = fromDuckEnum(cv.data, i, cv.enumWidth)
    result = NimValue(kind: nvEnum, enumVal: rawIdx,
      enumLabels: if cv.ltype == nil: nil else: cv.ltype.enumLabels)
  of DuckType.Timestamp:
    let v = cv.bindAs(DuckType.Timestamp)
    result = NimValue(kind: nvTimestamp, timestampVal: v[i])
  of DuckType.TimestampS:
    let v = cv.bindAs(DuckType.TimestampS)
    result = NimValue(kind: nvTimestampS, timestampSVal: v[i])
  of DuckType.TimestampMs:
    let v = cv.bindAs(DuckType.TimestampMs)
    result = NimValue(kind: nvTimestampMs, timestampMsVal: v[i])
  of DuckType.TimestampNs:
    let v = cv.bindAs(DuckType.TimestampNs)
    result = NimValue(kind: nvTimestampNs, timestampNsVal: v[i])
  of DuckType.Date:
    let v = cv.bindAs(DuckType.Date)
    result = NimValue(kind: nvDate, dateVal: v[i])
  of DuckType.Time:
    let v = cv.bindAs(DuckType.Time)
    result = NimValue(kind: nvTime, timeVal: v[i])
  of DuckType.TimeTz:
    let v = cv.bindAs(DuckType.TimeTz)
    result = NimValue(kind: nvTimeTz, timeTzVal: v[i])
  of DuckType.TimestampTz:
    let v = cv.bindAs(DuckType.TimestampTz)
    result = NimValue(kind: nvTimestampTz, timestampTzVal: v[i])
  of DuckType.Interval:
    let v = cv.bindAs(DuckType.Interval)
    result = NimValue(kind: nvInterval, intervalVal: v[i])
  of DuckType.Decimal:
    let v = cv.bindAs(DuckType.Decimal)
    let (raw, width, scale) = v.borrowDecimal(i)
    result = NimValue(kind: nvDecimal, decimalRaw: raw,
      decimalWidth: width, decimalScale: scale)
  of DuckType.List:
    let vl = cv.bindAs(DuckType.List)
    let (off, ln) = vl.listEntry(i)
    let child = vl.listChild
    var lst = newSeq[NimValue](ln.int)
    for j in 0 ..< ln.int:
      lst[j] = toNimValue(child, off.int + j)
    result = NimValue(kind: nvList, listVal: lst)
  of DuckType.Array:
    let va = cv.bindAs(DuckType.Array)
    let n = va.arraySize
    let child = va.arrayChild
    var lst = newSeq[NimValue](n)
    for j in 0 ..< n:
      lst[j] = toNimValue(child, i * n + j)
    result = NimValue(kind: nvList, listVal: lst)
  of DuckType.Struct:
    let vs = cv.bindAs(DuckType.Struct)
    let nc = vs.structChildCount
    var fields = newSeq[(string, NimValue)](nc)
    for j in 0 ..< nc:
      let name = vs.structChildName(j)
      let childCV = vs.structChild(j)
      fields[j] = (name, toNimValue(childCV, i))
    result = NimValue(kind: nvStruct, fields: fields)
  of DuckType.Map:
    let vm = cv.bindAs(DuckType.Map)
    let (off, ln) = vm.mapEntry(i)
    let entryStruct = vm.mapEntriesChild.bindAs(DuckType.Struct)
    let keyChild = entryStruct.structChild(0)
    let valChild = entryStruct.structChild(1)
    var pairs = newSeq[(NimValue, NimValue)](ln.int)
    for j in 0 ..< ln.int:
      let idx = off.int + j
      pairs[j] = (toNimValue(keyChild, idx), toNimValue(valChild, idx))
    result = NimValue(kind: nvMap, mapVal: pairs)
  of DuckType.Union:
    let vu = cv.bindAs(DuckType.Union)
    let tag = vu.unionTag(i)
    if tag < 0:
      result = NimValue(kind: nvNull)
    else:
      let name = vu.unionMemberName(tag)
      let memberCV = vu.unionMemberChild(tag)
      result = NimValue(kind: nvUnion, memberName: name,
                        memberVal: refValue(toNimValue(memberCV, i)))
  else:
    raise newException(ValueError,
                       "unsupported DuckDB type for materialization: " & $cv.kind)

type
  NimDecoder = ref object
    ## Chunk-bound decoder. Child views and union metadata are bound once.
    kind: DuckType
    cv: ColumnView
    listView: Vector[DuckType.List]
    arrayView: Vector[DuckType.Array]
    mapView: Vector[DuckType.Map]
    unionTagData: ptr UncheckedArray[uint8]
    unionTagValidity: ptr UncheckedArray[uint64]
    childNames: seq[string]
    children: seq[NimDecoder]

proc newNimDecoder(cv: ColumnView): NimDecoder =
  result = NimDecoder(kind: cv.kind, cv: cv)
  case cv.kind
  of DuckType.List:
    result.listView = cv.bindAs(DuckType.List)
    result.children = @[newNimDecoder(result.listView.listChild)]
  of DuckType.Array:
    result.arrayView = cv.bindAs(DuckType.Array)
    result.children = @[newNimDecoder(result.arrayView.arrayChild)]
  of DuckType.Struct:
    let view = cv.bindAs(DuckType.Struct)
    let count = view.structChildCount
    result.childNames = newSeq[string](count)
    result.children = newSeq[NimDecoder](count)
    for j in 0 ..< count:
      result.childNames[j] = view.structChildName(j)
      result.children[j] = newNimDecoder(view.structChild(j))
  of DuckType.Map:
    result.mapView = cv.bindAs(DuckType.Map)
    let entries = result.mapView.mapEntriesChild.bindAs(DuckType.Struct)
    result.children = @[
      newNimDecoder(entries.structChild(0)),
      newNimDecoder(entries.structChild(1))]
  of DuckType.Union:
    let view = cv.bindAs(DuckType.Union)
    let tag = view.unionTagView
    result.unionTagData = tag.data
    result.unionTagValidity = tag.validity
    let count = view.unionMemberCount
    result.childNames = newSeq[string](count)
    result.children = newSeq[NimDecoder](count)
    for j in 0 ..< count:
      result.childNames[j] = view.unionMemberName(j)
      result.children[j] = newNimDecoder(view.unionMemberChild(j))
  else:
    discard

proc decode(decoder: NimDecoder, i: int): NimValue =
  if not decoder.cv.valid(i):
    return NimValue(kind: nvNull)
  case decoder.kind
  of DuckType.List:
    let (offset, length) = decoder.listView.listEntry(i)
    result = NimValue(kind: nvList, listVal: newSeq[NimValue](length.int))
    for j in 0 ..< length.int:
      result.listVal[j] = decoder.children[0].decode(offset.int + j)
  of DuckType.Array:
    let size = decoder.arrayView.arraySize
    result = NimValue(kind: nvList, listVal: newSeq[NimValue](size))
    for j in 0 ..< size:
      result.listVal[j] = decoder.children[0].decode(i * size + j)
  of DuckType.Struct:
    result = NimValue(kind: nvStruct,
      fields: newSeq[(string, NimValue)](decoder.children.len))
    for j, child in decoder.children:
      result.fields[j] = (decoder.childNames[j], child.decode(i))
  of DuckType.Map:
    let (offset, length) = decoder.mapView.mapEntry(i)
    result = NimValue(kind: nvMap,
      mapVal: newSeq[(NimValue, NimValue)](length.int))
    for j in 0 ..< length.int:
      let index = offset.int + j
      result.mapVal[j] = (decoder.children[0].decode(index),
                          decoder.children[1].decode(index))
  of DuckType.Union:
    if decoder.unionTagValidity != nil and
        (decoder.unionTagValidity[i shr 6] and (1'u64 shl (i and 63))) == 0:
      return NimValue(kind: nvNull)
    let tag = decoder.unionTagData[i].int
    if tag < 0 or tag >= decoder.children.len:
      return NimValue(kind: nvNull)
    result = NimValue(kind: nvUnion, memberName: decoder.childNames[tag],
      memberVal: refValue(decoder.children[tag].decode(i)))
  else:
    result = decoder.cv.toNimValue(i)

proc toNimValues*(cv: ColumnView): seq[NimValue] =
  ## Materializes the whole column; NULL rows become `NimValue(kind: nvNull)`.
  result = newSeq[NimValue](cv.length)
  proc makeBool(value: bool): NimValue =
    NimValue(kind: nvBool, boolVal: value)
  proc makeInt[T](value: T): NimValue =
    NimValue(kind: nvInt, intVal: int64(value))
  proc makeUInt(value: uint64): NimValue =
    NimValue(kind: nvUInt, uintVal: value)
  proc makeFloat[T](value: T): NimValue =
    NimValue(kind: nvFloat, floatVal: float64(value))
  proc makeUHuge(value: UInt128): NimValue =
    NimValue(kind: nvUHuge, uhugeVal: value)
  proc makeUUID(value: Uuid): NimValue =
    NimValue(kind: nvUUID, uuidVal: value)
  proc makeTimestamp(value: Timestamp): NimValue =
    NimValue(kind: nvTimestamp, timestampVal: value)
  proc makeTimestampS(value: DateTime): NimValue =
    NimValue(kind: nvTimestampS, timestampSVal: value)
  proc makeTimestampMs(value: DateTime): NimValue =
    NimValue(kind: nvTimestampMs, timestampMsVal: value)
  proc makeTimestampNs(value: DateTime): NimValue =
    NimValue(kind: nvTimestampNs, timestampNsVal: value)
  proc makeDate(value: DateTime): NimValue =
    NimValue(kind: nvDate, dateVal: value)
  proc makeTime(value: Time): NimValue =
    NimValue(kind: nvTime, timeVal: value)
  proc makeTimeTz(value: ZonedTime): NimValue =
    NimValue(kind: nvTimeTz, timeTzVal: value)
  proc makeTimestampTz(value: ZonedTime): NimValue =
    NimValue(kind: nvTimestampTz, timestampTzVal: value)
  proc makeInterval(value: TimeInterval): NimValue =
    NimValue(kind: nvInterval, intervalVal: value)
  proc makeString(value: string): NimValue =
    NimValue(kind: nvString, strVal: value)
  proc makeBlob(value: seq[byte]): NimValue =
    NimValue(kind: nvBlob, blobVal: value)
  template fillScalar(kt: static DuckType, maker: untyped) =
    let v = cv.bindAs(kt)
    for i in 0 ..< cv.length:
      if v.valid(i): result[i] = maker(v[i])
      else: result[i] = NimValue(kind: nvNull)

  case cv.kind
  of DuckType.Boolean:
    fillScalar(DuckType.Boolean, makeBool)
  of DuckType.TinyInt:
    fillScalar(DuckType.TinyInt, makeInt)
  of DuckType.SmallInt:
    fillScalar(DuckType.SmallInt, makeInt)
  of DuckType.Integer:
    fillScalar(DuckType.Integer, makeInt)
  of DuckType.BigInt:
    fillScalar(DuckType.BigInt, makeInt)
  of DuckType.UTinyInt:
    fillScalar(DuckType.UTinyInt, makeInt)
  of DuckType.USmallInt:
    fillScalar(DuckType.USmallInt, makeInt)
  of DuckType.UInteger:
    fillScalar(DuckType.UInteger, makeInt)
  of DuckType.UBigInt:
    fillScalar(DuckType.UBigInt, makeUInt)
  of DuckType.Float:
    fillScalar(DuckType.Float, makeFloat)
  of DuckType.Double:
    fillScalar(DuckType.Double, makeFloat)
  of DuckType.Varchar:
    fillScalar(DuckType.Varchar, makeString)
  of DuckType.Bit:
    fillScalar(DuckType.Bit, makeString)
  of DuckType.Blob:
    fillScalar(DuckType.Blob, makeBlob)
  of DuckType.HugeInt:
    let v = cv.bindAs(DuckType.HugeInt)
    for i in 0 ..< cv.length:
      if v.valid(i): result[i] = NimValue(kind: nvHuge, hugeVal: v[i])
      else: result[i] = NimValue(kind: nvNull)
  of DuckType.UHugeInt:
    fillScalar(DuckType.UHugeInt, makeUHuge)
  of DuckType.UUID:
    fillScalar(DuckType.UUID, makeUUID)
  of DuckType.Timestamp:
    fillScalar(DuckType.Timestamp, makeTimestamp)
  of DuckType.TimestampS:
    fillScalar(DuckType.TimestampS, makeTimestampS)
  of DuckType.TimestampMs:
    fillScalar(DuckType.TimestampMs, makeTimestampMs)
  of DuckType.TimestampNs:
    fillScalar(DuckType.TimestampNs, makeTimestampNs)
  of DuckType.Date:
    fillScalar(DuckType.Date, makeDate)
  of DuckType.Time:
    fillScalar(DuckType.Time, makeTime)
  of DuckType.TimeTz:
    fillScalar(DuckType.TimeTz, makeTimeTz)
  of DuckType.TimestampTz:
    fillScalar(DuckType.TimestampTz, makeTimestampTz)
  of DuckType.Interval:
    fillScalar(DuckType.Interval, makeInterval)
  of DuckType.Decimal:
    let v = cv.bindAs(DuckType.Decimal)
    for i in 0 ..< cv.length:
      if v.valid(i):
        let (raw, width, scale) = v.borrowDecimal(i)
        result[i] = NimValue(kind: nvDecimal, decimalRaw: raw,
          decimalWidth: width, decimalScale: scale)
      else:
        result[i] = NimValue(kind: nvNull)
  of DuckType.Enum:
    let v = cv.bindAs(DuckType.Enum)
    for i in 0 ..< cv.length:
      if v.valid(i):
        result[i] = NimValue(kind: nvEnum, enumVal: v[i],
          enumLabels: if cv.ltype == nil: nil else: cv.ltype.enumLabels)
      else:
        result[i] = NimValue(kind: nvNull)
  else:
    let decoder = newNimDecoder(cv)
    for i in 0 ..< cv.length:
      result[i] = decoder.decode(i)

# ---------------------------------------------------------------------------
# Per-row `[]` materialisers for Struct and Union
#
# These deliberately shadow the complex-kind `.error` branch of the generic
# `Vector[kt].[]` in qresult.nim: Nim overload resolution picks the more
# specific non-generic proc for `Vector[DuckType.Struct]` /
# `Vector[DuckType.Union]`, so the `.error` is never instantiated for these
# kinds. Return shapes mirror `toStructPairs` / `toUnion` so a single row
# produces exactly what those column-level helpers yield per row.
# ---------------------------------------------------------------------------

proc `[]`*(v: Vector[DuckType.Struct], i: int): seq[(string, NimValue)] =
  ## STRUCT row `i` as `(fieldName, materialized value)` pairs; NULL rows yield
  ## an empty `seq`.
  if not v.valid(i):
    return newSeq[(string, NimValue)](0)
  let nc = v.structChildCount
  result = newSeq[(string, NimValue)](nc)
  for j in 0 ..< nc:
    let name = v.structChildName(j)
    let child = v.structChild(j)
    result[j] = (name, toNimValue(child, i))

proc `[]`*(v: Vector[DuckType.Union], i: int): (string, NimValue) =
  ## UNION row `i` as `(activeMemberName, materialized value)`; NULL rows yield
  ## `("", nvNull)`.
  if not v.valid(i):
    return ("", NimValue(kind: nvNull))
  let tag = v.unionTag(i)
  if tag < 0:
    return ("", NimValue(kind: nvNull))
  let name = v.unionMemberName(tag)
  let member = v.unionMemberChild(tag)
  (name, toNimValue(member, i))

proc len*(v: Vector[DuckType.Struct]): int {.inline.} =
  ## Row count of the struct-typed vector.
  v.length
proc len*(v: Vector[DuckType.Union]): int {.inline.} =
  ## Row count of the union-typed vector.
  v.length

iterator items*(v: Vector[DuckType.Struct]): seq[(string, NimValue)] =
  ## Yields each STRUCT row as `(fieldName, value)` pairs (see `[]`).
  for i in 0 ..< v.length:
    yield v[i]

iterator items*(v: Vector[DuckType.Union]): (string, NimValue) =
  ## Yields each UNION row as `(memberName, value)` (see `[]`).
  for i in 0 ..< v.length:
    yield v[i]

proc toSeq*(v: Vector[DuckType.Struct]): seq[seq[(string, NimValue)]] =
  ## Materializes the whole STRUCT column.
  let nc = v.structChildCount
  var names = newSeq[string](nc)
  var children = newSeq[ColumnView](nc)
  for j in 0 ..< nc:
    names[j] = v.structChildName(j)
    children[j] = v.structChild(j)
  result = newSeq[seq[(string, NimValue)]](v.length)
  for i in 0 ..< v.length:
    if not v.valid(i):
      result[i] = newSeq[(string, NimValue)](0)
      continue
    var fields = newSeq[(string, NimValue)](nc)
    for j in 0 ..< nc:
      fields[j] = (names[j], toNimValue(children[j], i))
    result[i] = fields

proc toSeq*(v: Vector[DuckType.Union]): seq[(string, NimValue)] =
  ## Materializes the whole UNION column as `(memberName, value)` per row.
  let nMembers = v.unionMemberCount
  var names = newSeq[string](nMembers)
  var members = newSeq[ColumnView](nMembers)
  for j in 0 ..< nMembers:
    names[j] = v.unionMemberName(j)
    members[j] = v.unionMemberChild(j)
  let tagView = v.unionTagView
  result = newSeq[(string, NimValue)](v.length)
  for i in 0 ..< v.length:
    if not v.valid(i):
      result[i] = ("", NimValue(kind: nvNull))
      continue
    let tv = tagView.validity
    let tag =
      if tv != nil and (tv[i shr 6] and (1'u64 shl (i and 63))) == 0: -1
      else: tagView.data[i].int
    if tag < 0:
      result[i] = ("", NimValue(kind: nvNull))
      continue
    result[i] = (names[tag], toNimValue(members[tag], i))

# ---------------------------------------------------------------------------
# Typed single-level helpers (Layer A)
# ---------------------------------------------------------------------------

proc toList*[childKt: static DuckType](
    v: Vector[DuckType.List]
  ): seq[seq[nimOf(childKt)]] =
  ## Converts a LIST column to `seq[seq[child]]` the typed way; child kind must
  ## be non-complex (use `toNimValue` for nested complex children).
  when childKt in DuckComplexKind:
    {.error: "toList requires a non-complex childKt; use toNimValue for nested complex types".}
  initListViewFromVector[childKt](v).toSeq

proc toArray*[childKt: static DuckType](
    v: Vector[DuckType.Array]
  ): seq[seq[nimOf(childKt)]] =
  ## Converts an ARRAY column to `seq[seq[child]]` the typed way; child kind
  ## must be non-complex (use `toNimValue` for nested complex children).
  when childKt in DuckComplexKind:
    {.error: "toArray requires a non-complex childKt; use toNimValue for nested complex types".}
  initArrayViewFromVector[childKt](v).toSeq

proc toStructPairs*(v: Vector[DuckType.Struct]): seq[seq[(string, NimValue)]] =
  ## Converts a STRUCT column to per-row `(name, value)` pairs (recursive).
  v.toSeq

proc toStructChild*[childKt: static DuckType](
    v: Vector[DuckType.Struct], j: int
  ): seq[nimOf(childKt)] =
  ## The typed column values of struct field `j`.
  v.structChild(j).bindAs(childKt).toSeq

proc toStructChild*[childKt: static DuckType](
    v: Vector[DuckType.Struct], name: string
  ): seq[nimOf(childKt)] =
  ## The typed column values of struct field `name`.
  v.structChild(name).bindAs(childKt).toSeq

proc toMap*[keyKt, valKt: static DuckType](
    v: Vector[DuckType.Map]
  ): seq[OrderedTable[nimOf(keyKt), nimOf(valKt)]] =
  ## Converts a MAP column to per-row `OrderedTable[key, val]`; key/value kinds
  ## must be non-complex (use `toNimValue` for nested complex keys/values).
  when keyKt in DuckComplexKind or valKt in DuckComplexKind:
    {.error: "toMap requires non-complex keyKt and valKt; use toNimValue for nested complex types".}
  initMapViewFromVector[keyKt, valKt](v).toSeq

proc toUnion*(v: Vector[DuckType.Union]): seq[(string, NimValue)] =
  ## Converts a UNION column to per-row `(memberName, value)`.
  v.toSeq

# ---------------------------------------------------------------------------
# toDuckValue — NimValue → duckdb_value round-trip
# ---------------------------------------------------------------------------

proc duckTypeOfNimValue(nv: NimValue): Option[DuckType] =
  ## Derives a scalar DuckDB logical type for a scalar `NimValue`. Returns
  ## `none` for kinds without a lossless scalar slot (blob, complex kinds).
  case nv.kind
  of nvBool:   some(DuckType.Boolean)
  of nvInt:    some(DuckType.BigInt)
  of nvUInt:   some(DuckType.UBigInt)
  of nvHuge:   some(DuckType.HugeInt)
  of nvUHuge:  some(DuckType.UHugeInt)
  of nvUUID:   some(DuckType.UUID)
  of nvFloat:  some(DuckType.Double)
  of nvTimestamp: some(DuckType.Timestamp)
  of nvTimestampS: some(DuckType.TimestampS)
  of nvTimestampMs: some(DuckType.TimestampMs)
  of nvTimestampNs: some(DuckType.TimestampNs)
  of nvDate: some(DuckType.Date)
  of nvTime: some(DuckType.Time)
  of nvTimeTz: some(DuckType.TimeTz)
  of nvTimestampTz: some(DuckType.TimestampTz)
  of nvInterval: some(DuckType.Interval)
  of nvString: some(DuckType.Varchar)
  else:        none(DuckType)

proc toDuckValue*(nv: NimValue): duckdb_value =
  ## Encodes a `NimValue` as a `duckdb_value` for binding. Scalars map
  ## directly; LIST/STRUCT are derived from the first element (homogeneity is
  ## required); MAP/UNION raise `ValueError`. Caller must destroy the value.
  case nv.kind
  of nvNull:
    result = duckdb_create_null_value()
  of nvBool:
    result = duckdb_create_bool(nv.boolVal)
  of nvInt:
    result = duckdb_create_int64(nv.intVal)
  of nvUInt:
    result = duckdb_create_uint64(nv.uintVal)
  of nvHuge:
    result = duckdb_create_hugeint(nv.hugeVal.toHugeInt)
  of nvUHuge:
    result = duckdb_create_uhugeint(nv.uhugeVal.toUHugeInt)
  of nvUUID:
    let raw = nv.uuidVal.toDuckUuid
    result = duckdb_create_uuid(duckdb_uhugeint(
      lower: raw.lower, upper: cast[uint64](raw.upper)))
  of nvFloat:
    result = duckdb_create_double(nv.floatVal)
  of nvTimestamp:
    result = duckdb_create_timestamp(nv.timestampVal.toTimestamp)
  of nvTimestampS:
    result = duckdb_create_timestamp_s(duckdb_timestamp_s(
      seconds: toDuckTimestampS(nv.timestampSVal)))
  of nvTimestampMs:
    result = duckdb_create_timestamp_ms(duckdb_timestamp_ms(
      millis: toDuckTimestampMs(nv.timestampMsVal)))
  of nvTimestampNs:
    result = duckdb_create_timestamp_ns(duckdb_timestamp_ns(
      nanos: toDuckTimestampNs(nv.timestampNsVal)))
  of nvDate:
    result = duckdb_create_date(toDatetime(nv.dateVal))
  of nvTime:
    result = duckdb_create_time(toTime(nv.timeVal))
  of nvTimeTz:
    result = duckdb_create_time_tz_value(duckdb_time_tz(
      bits: uint64(toDuckTimeTz(nv.timeTzVal))))
  of nvTimestampTz:
    result = duckdb_create_timestamp_tz(duckdb_timestamp(
      micros: toDuckTimestampTz(nv.timestampTzVal)))
  of nvInterval:
    result = duckdb_create_interval(toInterval(nv.intervalVal))
  of nvDecimal:
    result = duckdb_create_decimal(duckdb_decimal(
      width: nv.decimalWidth.uint8,
      scale: nv.decimalScale.uint8,
      value: nv.decimalRaw.toHugeInt))
  of nvEnum:
    raise newException(ValueError,
      "cannot derive an enum logical type without a schema")
  of nvString:
    result = duckdb_create_varchar_length(
      nv.strVal.cstring, nv.strVal.len.idx_t)
  of nvBlob:
    if nv.blobVal.len == 0:
      result = duckdb_create_blob(nil, 0)
    else:
      result = duckdb_create_blob(cast[ptr uint8](nv.blobVal[0].addr), nv.blobVal.len.idx_t)
  of nvList:
    if nv.listVal.len == 0:
      raise newException(ValueError,
        "cannot derive an element type for an empty nvList; " &
        "use typed bindVal/append overloads instead")
    let elDuck = duckTypeOfNimValue(nv.listVal[0])
    if elDuck.isNone:
      raise newException(ValueError,
        "cannot derive a DuckDB type for list element kind " & $nv.listVal[0].kind)
    # require a homogeneous element type
    for el in nv.listVal:
      if duckTypeOfNimValue(el) != elDuck:
        raise newException(ValueError,
          "nvList elements have mixed DuckDB types; " &
          "use typed bindVal/append overloads instead")
    # `duckdb_create_list_value` takes the CHILD type (it wraps it in a LIST)
    let elType = duckdb_create_logical_type(duckdb_type(elDuck.get.ord))
    var values = newSeq[duckdb_value](nv.listVal.len)
    defer:
      for v in values:
        if v != nil:
          duckdb_destroy_value(v.addr)
      duckdb_destroy_logical_type(elType.addr)
    for i, el in nv.listVal:
      values[i] = toDuckValue(el)
    result = duckdb_create_list_value(elType,
      cast[ptr duckdb_value](values[0].addr), values.len.idx_t)
  of nvStruct:
    if nv.fields.len == 0:
      raise newException(ValueError,
        "cannot derive a DuckDB type for an empty nvStruct; " &
        "use typed bindVal/append overloads instead")
    var mtypes = newSeq[duckdb_logical_type](nv.fields.len)
    var mnamesC = newSeq[cstring](nv.fields.len)
    var structType: duckdb_logical_type
    var values = newSeq[duckdb_value](nv.fields.len)
    defer:
      for t in mtypes:
        if t != nil:
          duckdb_destroy_logical_type(t.addr)
      for v in values:
        if v != nil:
          duckdb_destroy_value(v.addr)
      if structType != nil:
        duckdb_destroy_logical_type(structType.addr)
    for i, (name, el) in nv.fields:
      let dt = duckTypeOfNimValue(el)
      if dt.isNone:
        raise newException(ValueError,
          "cannot derive a DuckDB type for struct member '" & name &
          "' (kind " & $el.kind & ")")
      mtypes[i] = duckdb_create_logical_type(duckdb_type(dt.get.ord))
      mnamesC[i] = name.cstring
    structType = duckdb_create_struct_type(
      cast[ptr duckdb_logical_type](mtypes[0].addr),
      cast[ptr cstring](mnamesC[0].addr), nv.fields.len.idx_t)
    for i, (name, el) in nv.fields:
      values[i] = toDuckValue(el)
    result = duckdb_create_struct_value(structType,
      cast[ptr duckdb_value](values[0].addr))
  of nvMap, nvUnion:
    raise newException(ValueError,
      "toDuckValue not yet implemented for complex kinds (" & $nv.kind &
      "); use typed bindVal/append overloads instead")

proc logicalChild(lt: LogicalType, index: int): LogicalType =
  if lt.childTypes != nil:
    return lt.childTypes[][index]
  case toDuckType(lt)
  of DuckType.List, DuckType.Array:
    newLogicalType(duckdb_list_type_child_type(lt.handle))
  of DuckType.Map:
    if index == 0:
      newLogicalType(duckdb_map_type_key_type(lt.handle))
    else:
      newLogicalType(duckdb_map_type_value_type(lt.handle))
  of DuckType.Struct:
    newLogicalType(duckdb_struct_type_child_type(lt.handle, index.idx_t))
  of DuckType.Union:
    newLogicalType(duckdb_union_type_member_type(lt.handle, index.idx_t))
  else:
    raise newException(ValueError, "logical type has no child types")

proc requireValueKind(nv: NimValue, expected: set[NimValueKind],
    target: DuckType) =
  if nv.kind notin expected:
    raise newException(ValueError,
      "NimValue kind " & $nv.kind & " does not match " & $target)

proc valueArray(values: seq[duckdb_value]): ptr duckdb_value {.inline.} =
  if values.len == 0: nil
  else: cast[ptr duckdb_value](values[0].addr)

proc toDuckValue*(nv: NimValue, logicalType: LogicalType): duckdb_value =
  ## Encodes a value against a supplied logical schema. Complex values do not
  ## need first-element type inference when this overload is used.
  if nv.kind == nvNull:
    return duckdb_create_null_value()
  let target = toDuckType(logicalType)
  case target
  of DuckType.Boolean:
    requireValueKind(nv, {nvBool}, target)
    result = duckdb_create_bool(nv.boolVal)
  of DuckType.TinyInt:
    requireValueKind(nv, {nvInt}, target)
    result = duckdb_create_int8(nv.intVal.int8)
  of DuckType.SmallInt:
    requireValueKind(nv, {nvInt}, target)
    result = duckdb_create_int16(nv.intVal.int16)
  of DuckType.Integer:
    requireValueKind(nv, {nvInt}, target)
    result = duckdb_create_int32(nv.intVal.int32)
  of DuckType.BigInt:
    requireValueKind(nv, {nvInt}, target)
    result = duckdb_create_int64(nv.intVal)
  of DuckType.UTinyInt:
    requireValueKind(nv, {nvInt, nvUInt}, target)
    let value = if nv.kind == nvUInt: nv.uintVal else:
      (if nv.intVal < 0: raise newException(ValueError,
        "negative value does not match " & $target) else: nv.intVal.uint64)
    result = duckdb_create_uint8(value.uint8)
  of DuckType.USmallInt:
    requireValueKind(nv, {nvInt, nvUInt}, target)
    let value = if nv.kind == nvUInt: nv.uintVal else:
      (if nv.intVal < 0: raise newException(ValueError,
        "negative value does not match " & $target) else: nv.intVal.uint64)
    result = duckdb_create_uint16(value.uint16)
  of DuckType.UInteger:
    requireValueKind(nv, {nvInt, nvUInt}, target)
    let value = if nv.kind == nvUInt: nv.uintVal else:
      (if nv.intVal < 0: raise newException(ValueError,
        "negative value does not match " & $target) else: nv.intVal.uint64)
    result = duckdb_create_uint32(value.uint32)
  of DuckType.UBigInt:
    requireValueKind(nv, {nvUInt}, target)
    result = duckdb_create_uint64(nv.uintVal)
  of DuckType.HugeInt:
    requireValueKind(nv, {nvHuge}, target)
    result = duckdb_create_hugeint(nv.hugeVal.toHugeInt)
  of DuckType.UHugeInt:
    requireValueKind(nv, {nvUHuge, nvUInt}, target)
    let value =
      if nv.kind == nvUHuge:
        nv.uhugeVal
      else:
        UInt128(hi: 0'u64, lo: nv.uintVal)
    result = duckdb_create_uhugeint(value.toUHugeInt)
  of DuckType.UUID:
    requireValueKind(nv, {nvUUID}, target)
    let raw = nv.uuidVal.toDuckUuid
    result = duckdb_create_uuid(duckdb_uhugeint(
      lower: raw.lower, upper: cast[uint64](raw.upper)))
  of DuckType.Float:
    requireValueKind(nv, {nvFloat}, target)
    result = duckdb_create_float(nv.floatVal.cfloat)
  of DuckType.Double:
    requireValueKind(nv, {nvFloat}, target)
    result = duckdb_create_double(nv.floatVal)
  of DuckType.Varchar, DuckType.Bit:
    requireValueKind(nv, {nvString}, target)
    result = duckdb_create_varchar_length(nv.strVal.cstring, nv.strVal.len.idx_t)
  of DuckType.Blob:
    requireValueKind(nv, {nvBlob}, target)
    result = duckdb_create_blob(
      if nv.blobVal.len == 0: nil else: cast[ptr uint8](nv.blobVal[0].addr),
      nv.blobVal.len.idx_t)
  of DuckType.Decimal:
    let width = duckdb_decimal_width(logicalType.handle).int8
    let scale = duckdb_decimal_scale(logicalType.handle).int8
    let raw =
      if nv.kind == nvDecimal:
        nv.decimalRaw
      elif nv.kind == nvString:
        let decimal = newDecimal(nv.strVal)
        toDuckDecimal(decimal, width, scale)
      else:
        raise newException(ValueError,
          "schema decimal binding requires a decimal or string value")
    result = duckdb_create_decimal(duckdb_decimal(
      width: width.uint8, scale: scale.uint8,
      value: toHugeInt(raw)))
  of DuckType.Timestamp:
    requireValueKind(nv, {nvTimestamp}, target)
    result = duckdb_create_timestamp(nv.timestampVal.toTimestamp)
  of DuckType.TimestampS:
    requireValueKind(nv, {nvTimestampS}, target)
    result = duckdb_create_timestamp_s(duckdb_timestamp_s(
      seconds: toDuckTimestampS(nv.timestampSVal)))
  of DuckType.TimestampMs:
    requireValueKind(nv, {nvTimestampMs}, target)
    result = duckdb_create_timestamp_ms(duckdb_timestamp_ms(
      millis: toDuckTimestampMs(nv.timestampMsVal)))
  of DuckType.TimestampNs:
    requireValueKind(nv, {nvTimestampNs}, target)
    result = duckdb_create_timestamp_ns(duckdb_timestamp_ns(
      nanos: toDuckTimestampNs(nv.timestampNsVal)))
  of DuckType.Date:
    requireValueKind(nv, {nvDate}, target)
    result = duckdb_create_date(toDatetime(nv.dateVal))
  of DuckType.Time:
    requireValueKind(nv, {nvTime}, target)
    result = duckdb_create_time(toTime(nv.timeVal))
  of DuckType.TimeTz:
    requireValueKind(nv, {nvTimeTz}, target)
    result = duckdb_create_time_tz_value(duckdb_time_tz(
      bits: uint64(toDuckTimeTz(nv.timeTzVal))))
  of DuckType.TimestampTz:
    requireValueKind(nv, {nvTimestampTz}, target)
    result = duckdb_create_timestamp_tz(duckdb_timestamp(
      micros: toDuckTimestampTz(nv.timestampTzVal)))
  of DuckType.Interval:
    requireValueKind(nv, {nvInterval}, target)
    result = duckdb_create_interval(toInterval(nv.intervalVal))
  of DuckType.List:
    requireValueKind(nv, {nvList}, target)
    let childType = logicalChild(logicalType, 0)
    var values = newSeq[duckdb_value](nv.listVal.len)
    defer:
      for value in values:
        if value != nil: duckdb_destroy_value(value.addr)
    for i, value in nv.listVal:
      values[i] = value.toDuckValue(childType)
    var emptyValue: duckdb_value = nil
    let valuesPtr = if values.len == 0: addr emptyValue else: valueArray(values)
    result = duckdb_create_list_value(childType.handle, valuesPtr, values.len.idx_t)
  of DuckType.Array:
    requireValueKind(nv, {nvList}, target)
    let childType = logicalChild(logicalType, 0)
    let size = duckdb_array_type_array_size(logicalType.handle).int
    if nv.listVal.len != size:
      raise newException(ValueError, "ARRAY value length does not match schema")
    var values = newSeq[duckdb_value](size)
    defer:
      for value in values:
        if value != nil: duckdb_destroy_value(value.addr)
    for i, value in nv.listVal:
      values[i] = value.toDuckValue(childType)
    # DuckDB 1.5.x accepts the child LIST value at append/bind boundaries, but
    # its C API array constructor returns nil for the same valid ARRAY value.
    result = duckdb_create_list_value(childType.handle, valueArray(values), size.idx_t)
  of DuckType.Struct:
    if nv.kind != nvStruct or logicalType.childTypes == nil or
        nv.fields.len != logicalType.childTypes[].len:
      raise newException(ValueError, "STRUCT value does not match schema field count")
    var values = newSeq[duckdb_value](nv.fields.len)
    defer:
      for value in values:
        if value != nil: duckdb_destroy_value(value.addr)
    for i, field in nv.fields:
      if logicalType.childNames == nil or logicalType.childNames[][i] != field[0]:
        raise newException(ValueError, "STRUCT field does not match schema")
      values[i] = field[1].toDuckValue(logicalChild(logicalType, i))
    result = duckdb_create_struct_value(logicalType.handle, valueArray(values))
  of DuckType.Map:
    if nv.kind != nvMap:
      raise newException(ValueError, "MAP value does not match schema")
    let keyType = logicalChild(logicalType, 0)
    let valueType = logicalChild(logicalType, 1)
    var keys = newSeq[duckdb_value](nv.mapVal.len)
    var values = newSeq[duckdb_value](nv.mapVal.len)
    defer:
      for value in keys:
        if value != nil: duckdb_destroy_value(value.addr)
      for value in values:
        if value != nil: duckdb_destroy_value(value.addr)
    for i, pair in nv.mapVal:
      keys[i] = pair[0].toDuckValue(keyType)
      values[i] = pair[1].toDuckValue(valueType)
    var emptyKey, emptyValue: duckdb_value = nil
    let keysPtr = if keys.len == 0: addr emptyKey else: valueArray(keys)
    let valuesPtr = if values.len == 0: addr emptyValue else: valueArray(values)
    result = duckdb_create_map_value(logicalType.handle, keysPtr,
      valuesPtr, nv.mapVal.len.idx_t)
  of DuckType.Union:
    if nv.kind != nvUnion or logicalType.childNames == nil:
      raise newException(ValueError, "UNION value does not match schema")
    var tag = -1
    for i, name in logicalType.childNames[]:
      if name == nv.memberName:
        tag = i
        break
    if tag < 0:
      raise newException(ValueError, "UNION member does not match schema")
    let value = nv.memberVal[].toDuckValue(logicalChild(logicalType, tag))
    defer: duckdb_destroy_value(value.addr)
    result = duckdb_create_union_value(logicalType.handle, tag.idx_t, value)
  of DuckType.Enum:
    if nv.kind != nvEnum:
      raise newException(ValueError, "ENUM value does not match schema")
    result = duckdb_create_enum_value(logicalType.handle, nv.enumVal.uint64)
  else:
    result = nv.toDuckValue

proc scalar*(qrs: QResult): NimValue =
  ## The first cell of `qrs` (column 0, row 0) materialized as a `NimValue`;
  ## handy for `SELECT`-scalar convenience queries.
  for chunk in qrs:
    return chunk.vector(0).toNimValue(0)

proc scalar*(qrs: QResult, kt: static DuckType): nimOf(kt) =
  ## The first cell of `qrs` (column 0, row 0) read via a typed `Vector[kt]`.
  for chunk in qrs:
    return chunk.bindAs(0, kt)[0]
