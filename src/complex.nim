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
## materializer.  Fully generic row-by-row materialization, allocates per row.
## For ad-hoc querying where the column shape is not known statically.
##
## The zero-copy descent procs in ``qresult.nim`` remain the hot path for
## performance-sensitive code.

import std/[tables, hashes, times, strutils, sequtils]
import nint128

import /[ffi, types, qresult, codec]

# ---------------------------------------------------------------------------
# NimValue — sum-type materialized value
# ---------------------------------------------------------------------------

type
  NimValueKind* = enum
    nvBool
    nvInt
    nvFloat
    nvString
    nvBlob
    nvList
    nvStruct
    nvMap
    nvUnion
    nvNull

  NimValue* = ref object
    case kind*: NimValueKind
    of nvBool:   boolVal*: bool
    of nvInt:    intVal*: int64
    of nvFloat:  floatVal*: float64
    of nvString: strVal*: string
    of nvBlob:   blobVal*: seq[byte]
    of nvList:   listVal*: seq[NimValue]
    of nvStruct: fields*: seq[(string, NimValue)]
    of nvMap:    mapVal*: seq[(NimValue, NimValue)]
    of nvUnion:
      memberName*: string
      memberVal*: NimValue
    of nvNull:   discard

func `==`*(a, b: NimValue): bool =
  if a.isNil or b.isNil:
    return a.isNil == b.isNil
  if a.kind != b.kind:
    return false
  case a.kind
  of nvBool:   a.boolVal == b.boolVal
  of nvInt:    a.intVal == b.intVal
  of nvFloat:  a.floatVal == b.floatVal
  of nvString: a.strVal == b.strVal
  of nvBlob:   a.blobVal == b.blobVal
  of nvList:   a.listVal == b.listVal
  of nvStruct: a.fields == b.fields
  of nvMap:    a.mapVal == b.mapVal
  of nvUnion:  a.memberName == b.memberName and a.memberVal == b.memberVal
  of nvNull:   true

func hash*(v: NimValue): Hash =
  result = hash(v.kind)
  case v.kind
  of nvBool:   result = result !& hash(v.boolVal)
  of nvInt:    result = result !& hash(v.intVal)
  of nvFloat:  result = result !& hash(v.floatVal)
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
    result = result !& hash(v.memberVal)
  of nvNull: discard
  result = !$result

func formatVal(v: NimValue, quoteStr: bool = true): string =
  if v.isNil:
    return "NULL"
  case v.kind
  of nvBool: (if v.boolVal: "true" else: "false")
  of nvInt: $v.intVal
  of nvFloat: $v.floatVal
  of nvString:
    if quoteStr: "'" & v.strVal.replace("'", "''") & "'"
    else: v.strVal
  of nvBlob:
    var s = "'\\x"
    for b in v.blobVal:
      s.add(toLowerAscii(b.toHex(2)))
    s.add("'")
    s
  of nvList:
    "[" & v.listVal.mapIt(formatVal(it, quoteStr)).join(", ") & "]"
  of nvStruct:
    "{" & v.fields.mapIt(
      "'" & it[0] & "': " & formatVal(it[1], false)).join(", ") & "}"
  of nvMap:
    "{" & v.mapVal.mapIt(
      formatVal(it[0], false) & "=" & formatVal(it[1], false)).join(", ") & "}"
  of nvUnion:
    formatVal(v.memberVal, quoteStr)
  of nvNull: "NULL"

proc `$`*(v: NimValue): string =
  formatVal(v, true)

# ---------------------------------------------------------------------------
# toNimValue — recursive materializer (Layer B)
# ---------------------------------------------------------------------------

proc toNimValue*(cv: ColumnView, i: int): NimValue =
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
    result = NimValue(kind: nvString, strVal: $v[i])
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
    result = NimValue(kind: nvString, strVal: $v[i])
  of DuckType.UHugeInt:
    let v = cv.bindAs(DuckType.UHugeInt)
    result = NimValue(kind: nvString, strVal: $v[i])
  of DuckType.UUID:
    let v = cv.bindAs(DuckType.UUID)
    result = NimValue(kind: nvString, strVal: $v[i])
  of DuckType.Enum:
    let rawIdx = fromDuckEnum(cv.data, i, cv.enumWidth)
    let name =
      if cv.ltype.handle != nil:
        $duckdb_enum_dictionary_value(cv.ltype.handle, rawIdx.idx_t)
      else:
        $rawIdx
    result = NimValue(kind: nvString, strVal: name)
  of DuckType.Timestamp:
    let v = cv.bindAs(DuckType.Timestamp)
    result = NimValue(kind: nvString, strVal: $v[i])
  of DuckType.TimestampS:
    let v = cv.bindAs(DuckType.TimestampS)
    result = NimValue(kind: nvString, strVal: $v[i])
  of DuckType.TimestampMs:
    let v = cv.bindAs(DuckType.TimestampMs)
    result = NimValue(kind: nvString, strVal: $v[i])
  of DuckType.TimestampNs:
    let v = cv.bindAs(DuckType.TimestampNs)
    result = NimValue(kind: nvString, strVal: $v[i])
  of DuckType.Date:
    let v = cv.bindAs(DuckType.Date)
    result = NimValue(kind: nvString, strVal: $v[i])
  of DuckType.Time:
    let v = cv.bindAs(DuckType.Time)
    result = NimValue(kind: nvString, strVal: $v[i])
  of DuckType.TimeTz:
    let v = cv.bindAs(DuckType.TimeTz)
    result = NimValue(kind: nvString, strVal: $v[i])
  of DuckType.TimestampTz:
    let v = cv.bindAs(DuckType.TimestampTz)
    result = NimValue(kind: nvString, strVal: $v[i])
  of DuckType.Interval:
    let v = cv.bindAs(DuckType.Interval)
    result = NimValue(kind: nvString, strVal: $v[i])
  of DuckType.Decimal:
    let v = cv.bindAs(DuckType.Decimal)
    result = NimValue(kind: nvString, strVal: $v[i])
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
                        memberVal: toNimValue(memberCV, i))
  else:
    raise newException(ValueError,
                       "unsupported DuckDB type for materialization: " & $cv.kind)

proc toNimValues*(cv: ColumnView): seq[NimValue] =
  result = newSeq[NimValue](cv.length)
  for i in 0 ..< cv.length:
    result[i] = toNimValue(cv, i)

# ---------------------------------------------------------------------------
# Typed single-level helpers (Layer A)
# ---------------------------------------------------------------------------

proc toList*[childKt: static DuckType](
    v: Vector[DuckType.List]
): seq[seq[nimOf(childKt)]] =
  when childKt in DuckComplexKind:
    {.error: "toList requires a non-complex childKt; use toNimValue for nested complex types".}
  let child = v.listChild.bindAs(childKt)
  result = newSeq[seq[nimOf(childKt)]](v.length)
  for i in 0 ..< v.length:
    if not v.valid(i):
      result[i] = newSeq[nimOf(childKt)](0)
      continue
    let (off, ln) = v.listEntry(i)
    var row = newSeq[nimOf(childKt)](ln.int)
    for j in 0 ..< ln.int:
      let cidx = off.int + j
      if child.valid(cidx):
        row[j] = child[cidx]
      else:
        row[j] = default(nimOf(childKt))
    result[i] = row

proc toArray*[childKt: static DuckType](
    v: Vector[DuckType.Array]
): seq[seq[nimOf(childKt)]] =
  when childKt in DuckComplexKind:
    {.error: "toArray requires a non-complex childKt; use toNimValue for nested complex types".}
  let n = v.arraySize
  let child = v.arrayChild.bindAs(childKt)
  result = newSeq[seq[nimOf(childKt)]](v.length)
  for i in 0 ..< v.length:
    if not v.valid(i):
      result[i] = newSeq[nimOf(childKt)](0)
      continue
    var row = newSeq[nimOf(childKt)](n)
    for j in 0 ..< n:
      let cidx = i * n + j
      if child.valid(cidx):
        row[j] = child[cidx]
      else:
        row[j] = default(nimOf(childKt))
    result[i] = row

proc toStructPairs*(v: Vector[DuckType.Struct]): seq[seq[(string, NimValue)]] =
  let nc = v.structChildCount
  result = newSeq[seq[(string, NimValue)]](v.length)
  for i in 0 ..< v.length:
    if not v.valid(i):
      result[i] = newSeq[(string, NimValue)](0)
      continue
    var fields = newSeq[(string, NimValue)](nc)
    for j in 0 ..< nc:
      let name = v.structChildName(j)
      let child = v.structChild(j)
      fields[j] = (name, toNimValue(child, i))
    result[i] = fields

proc toStructChild*[childKt: static DuckType](
    v: Vector[DuckType.Struct], j: int
): seq[nimOf(childKt)] =
  v.structChild(j).bindAs(childKt).toSeq

proc toStructChild*[childKt: static DuckType](
    v: Vector[DuckType.Struct], name: string
): seq[nimOf(childKt)] =
  v.structChild(name).bindAs(childKt).toSeq

proc toMap*[keyKt, valKt: static DuckType](
    v: Vector[DuckType.Map]
): seq[OrderedTable[nimOf(keyKt), nimOf(valKt)]] =
  when keyKt in DuckComplexKind or valKt in DuckComplexKind:
    {.error: "toMap requires non-complex keyKt and valKt; use toNimValue for nested complex types".}
  let entryStruct = v.mapEntriesChild.bindAs(DuckType.Struct)
  let keys = entryStruct.structChild(0).bindAs(keyKt)
  let vals = entryStruct.structChild(1).bindAs(valKt)
  result = newSeq[OrderedTable[nimOf(keyKt), nimOf(valKt)]](v.length)
  for i in 0 ..< v.length:
    if not v.valid(i):
      result[i] = initOrderedTable[nimOf(keyKt), nimOf(valKt)](0)
      continue
    let (off, ln) = v.mapEntry(i)
    var tbl = initOrderedTable[nimOf(keyKt), nimOf(valKt)](ln.int)
    for j in 0 ..< ln.int:
      let cidx = off.int + j
      var key: nimOf(keyKt)
      var val: nimOf(valKt)
      if keys.valid(cidx): key = keys[cidx] else: key = default(nimOf(keyKt))
      if vals.valid(cidx): val = vals[cidx] else: val = default(nimOf(valKt))
      tbl[key] = val
    result[i] = tbl

proc toUnion*(v: Vector[DuckType.Union]): seq[(string, NimValue)] =
  result = newSeq[(string, NimValue)](v.length)
  for i in 0 ..< v.length:
    if not v.valid(i):
      result[i] = ("", NimValue(kind: nvNull))
      continue
    let tag = v.unionTag(i)
    if tag < 0:
      result[i] = ("", NimValue(kind: nvNull))
      continue
    let name = v.unionMemberName(tag)
    let member = v.unionMemberChild(tag)
    result[i] = (name, toNimValue(member, i))

# ---------------------------------------------------------------------------
# toDuckValue — NimValue → duckdb_value round-trip
# ---------------------------------------------------------------------------

proc toDuckValue*(nv: NimValue): duckdb_value =
  case nv.kind
  of nvNull:
    result = duckdb_create_null_value()
  of nvBool:
    result = duckdb_create_bool(nv.boolVal)
  of nvInt:
    result = duckdb_create_int64(nv.intVal)
  of nvFloat:
    result = duckdb_create_double(nv.floatVal)
  of nvString:
    result = duckdb_create_varchar(nv.strVal.cstring)
  of nvBlob:
    result = duckdb_create_blob(cast[ptr uint8](nv.blobVal[0].addr), nv.blobVal.len.idx_t)
  of nvList, nvStruct, nvMap, nvUnion:
    raise newException(ValueError,
      "toDuckValue not yet implemented for complex kinds (" & $nv.kind &
      "); use typed bindVal/append overloads instead")


proc scalar*(qrs: QResult): NimValue =
  for chunk in qrs:
    return chunk.vector(0).toNimValue(0)

proc scalar*(qrs: QResult, kt: static DuckType): nimOf(kt) =
  for chunk in qrs:
    return chunk.bindAs(0, kt)[0]
