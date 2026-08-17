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
## ``NimValue`` preserves integer widths losslessly: signed 64-bit values map
## to ``nvInt``, unsigned 64-bit to ``nvUInt``, and HUGEINT to ``nvHuge``
## (``Int128``). UHUGEINT and UUID have no lossless Nim scalar slot and
## materialize as ``nvString``.
##
## The zero-copy descent procs in ``qresult.nim`` remain the hot path for
## performance-sensitive code.

import std/[tables, hashes, times, strutils, sequtils, options]
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
    nvFloat
    nvString
    nvBlob
    nvList
    nvStruct
    nvMap
    nvUnion
    nvNull

  NimValue* = ref object ## Recursively materialized cell of any DuckDB kind.
    ## Allocates per row; the zero-copy `Vector[kt]` views in `qresult` are the
    ## hot path. Integer widths are lossless: signed 64-bit → `nvInt`,
    ## unsigned 64-bit → `nvUInt`, HUGEINT → `nvHuge`; UHUGEINT and UUID
    ## materialize as `nvString`.
    case kind*: NimValueKind
    of nvBool:   boolVal*: bool
    of nvInt:    intVal*: int64
    of nvUInt:   uintVal*: uint64
    of nvHuge:   hugeVal*: Int128
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

## Structural equality; two `nil` refs compare equal.
func `==`*(a, b: NimValue): bool =
  if a.isNil or b.isNil:
    return a.isNil == b.isNil
  if a.kind != b.kind:
    return false
  case a.kind
  of nvBool:   a.boolVal == b.boolVal
  of nvInt:    a.intVal == b.intVal
  of nvUInt:   a.uintVal == b.uintVal
  of nvHuge:   a.hugeVal == b.hugeVal
  of nvFloat:  a.floatVal == b.floatVal
  of nvString: a.strVal == b.strVal
  of nvBlob:   a.blobVal == b.blobVal
  of nvList:   a.listVal == b.listVal
  of nvStruct: a.fields == b.fields
  of nvMap:    a.mapVal == b.mapVal
  of nvUnion:  a.memberName == b.memberName and a.memberVal == b.memberVal
  of nvNull:   true

## Content hash, consistent with `==`.
func hash*(v: NimValue): Hash =
  result = hash(v.kind)
  case v.kind
  of nvBool:   result = result !& hash(v.boolVal)
  of nvInt:    result = result !& hash(v.intVal)
  of nvUInt:   result = result !& hash(v.uintVal)
  of nvHuge:   result = result !& hash(v.hugeVal)
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
  of nvUInt: $v.uintVal
  of nvHuge: $v.hugeVal
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

## Formats a `NimValue` in a SQL-ish literal syntax (lists, structs, maps
## bracket the children); NULL renders as `NULL`.
proc `$`*(v: NimValue): string =
  formatVal(v, true)

# ---------------------------------------------------------------------------
# toNimValue — recursive materializer (Layer B)
# ---------------------------------------------------------------------------

## Recursively materializes row `i` of any column into a `NimValue`.
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
    result = NimValue(kind: nvString, strVal: $v[i])
  of DuckType.UUID:
    let v = cv.bindAs(DuckType.UUID)
    result = NimValue(kind: nvString, strVal: $v[i])
  of DuckType.Enum:
    let rawIdx = fromDuckEnum(cv.data, i, cv.enumWidth)
    var name: string
    if cv.ltype.handle != nil:
      let cs = duckdb_enum_dictionary_value(cv.ltype.handle, rawIdx.idx_t)
      name = $cs
      duckdb_free(cast[pointer](cs))
    else:
      name = $rawIdx
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

## Materializes the whole column; NULL rows become `NimValue(kind: nvNull)`.
proc toNimValues*(cv: ColumnView): seq[NimValue] =
  result = newSeq[NimValue](cv.length)
  for i in 0 ..< cv.length:
    result[i] = toNimValue(cv, i)

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

## STRUCT row `i` as `(fieldName, materialized value)` pairs; NULL rows yield
## an empty `seq`.
proc `[]`*(v: Vector[DuckType.Struct], i: int): seq[(string, NimValue)] =
  if not v.valid(i):
    return newSeq[(string, NimValue)](0)
  let nc = v.structChildCount
  result = newSeq[(string, NimValue)](nc)
  for j in 0 ..< nc:
    let name = v.structChildName(j)
    let child = v.structChild(j)
    result[j] = (name, toNimValue(child, i))

## UNION row `i` as `(activeMemberName, materialized value)`; NULL rows yield
## `("", nvNull)`.
proc `[]`*(v: Vector[DuckType.Union], i: int): (string, NimValue) =
  if not v.valid(i):
    return ("", NimValue(kind: nvNull))
  let tag = v.unionTag(i)
  if tag < 0:
    return ("", NimValue(kind: nvNull))
  let name = v.unionMemberName(tag)
  let member = v.unionMemberChild(tag)
  (name, toNimValue(member, i))

## Row count of the struct-typed vector.
proc len*(v: Vector[DuckType.Struct]): int {.inline.} = v.length
## Row count of the union-typed vector.
proc len*(v: Vector[DuckType.Union]): int {.inline.} = v.length

## Yields each STRUCT row as `(fieldName, value)` pairs (see `[]`).
iterator items*(v: Vector[DuckType.Struct]): seq[(string, NimValue)] =
  for i in 0 ..< v.length:
    yield v[i]

## Yields each UNION row as `(memberName, value)` (see `[]`).
iterator items*(v: Vector[DuckType.Union]): (string, NimValue) =
  for i in 0 ..< v.length:
    yield v[i]

## Materializes the whole STRUCT column.
proc toSeq*(v: Vector[DuckType.Struct]): seq[seq[(string, NimValue)]] =
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

## Materializes the whole UNION column as `(memberName, value)` per row.
proc toSeq*(v: Vector[DuckType.Union]): seq[(string, NimValue)] =
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

## Converts a LIST column to `seq[seq[child]]` the typed way; child kind must
## be non-complex (use `toNimValue` for nested complex children).
proc toList*[childKt: static DuckType](
    v: Vector[DuckType.List]
  ): seq[seq[nimOf(childKt)]] =
  when childKt in DuckComplexKind:
    {.error: "toList requires a non-complex childKt; use toNimValue for nested complex types".}
  initListViewFromVector[childKt](v).toSeq

## Converts an ARRAY column to `seq[seq[child]]` the typed way; child kind
## must be non-complex (use `toNimValue` for nested complex children).
proc toArray*[childKt: static DuckType](
    v: Vector[DuckType.Array]
  ): seq[seq[nimOf(childKt)]] =
  when childKt in DuckComplexKind:
    {.error: "toArray requires a non-complex childKt; use toNimValue for nested complex types".}
  initArrayViewFromVector[childKt](v).toSeq

## Converts a STRUCT column to per-row `(name, value)` pairs (recursive).
proc toStructPairs*(v: Vector[DuckType.Struct]): seq[seq[(string, NimValue)]] =
  let nc = v.structChildCount
  # Hoist the child views and names once per chunk instead of re-deriving
  # them via FFI for every row.
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

## The typed column values of struct field `j`.
proc toStructChild*[childKt: static DuckType](
    v: Vector[DuckType.Struct], j: int
  ): seq[nimOf(childKt)] =
  v.structChild(j).bindAs(childKt).toSeq

## The typed column values of struct field `name`.
proc toStructChild*[childKt: static DuckType](
    v: Vector[DuckType.Struct], name: string
  ): seq[nimOf(childKt)] =
  v.structChild(name).bindAs(childKt).toSeq

## Converts a MAP column to per-row `OrderedTable[key, val]`; key/value kinds
## must be non-complex (use `toNimValue` for nested complex keys/values).
proc toMap*[keyKt, valKt: static DuckType](
    v: Vector[DuckType.Map]
  ): seq[OrderedTable[nimOf(keyKt), nimOf(valKt)]] =
  when keyKt in DuckComplexKind or valKt in DuckComplexKind:
    {.error: "toMap requires non-complex keyKt and valKt; use toNimValue for nested complex types".}
  initMapViewFromVector[keyKt, valKt](v).toSeq

## Converts a UNION column to per-row `(memberName, value)`.
proc toUnion*(v: Vector[DuckType.Union]): seq[(string, NimValue)] =
  # Hoist the tag view plus the member names/children once per chunk so the
  # row loop performs no FFI calls.
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
  of nvFloat:  some(DuckType.Double)
  of nvString: some(DuckType.Varchar)
  else:        none(DuckType)

## Encodes a `NimValue` as a `duckdb_value` for binding. Scalars map
## directly; LIST/STRUCT are derived from the first element (homogeneity is
## required); MAP/UNION raise `ValueError`. Caller must destroy the value.
proc toDuckValue*(nv: NimValue): duckdb_value =
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
  of nvFloat:
    result = duckdb_create_double(nv.floatVal)
  of nvString:
    result = duckdb_create_varchar(nv.strVal.cstring)
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
    for i, el in nv.listVal:
      values[i] = toDuckValue(el)
    result = duckdb_create_list_value(elType,
      cast[ptr duckdb_value](values[0].addr), values.len.idx_t)
    for v in values:
      duckdb_destroy_value(v.addr)
    duckdb_destroy_logical_type(elType.addr)
  of nvStruct:
    if nv.fields.len == 0:
      raise newException(ValueError,
        "cannot derive a DuckDB type for an empty nvStruct; " &
        "use typed bindVal/append overloads instead")
    var mtypes = newSeq[duckdb_logical_type](nv.fields.len)
    var mnames = newSeq[string](nv.fields.len)
    var mnamesC = newSeq[cstring](nv.fields.len)
    for i, (name, el) in nv.fields:
      let dt = duckTypeOfNimValue(el)
      if dt.isNone:
        raise newException(ValueError,
          "cannot derive a DuckDB type for struct member '" & name &
          "' (kind " & $el.kind & ")")
      mtypes[i] = duckdb_create_logical_type(duckdb_type(dt.get.ord))
      mnames[i] = name
      mnamesC[i] = mnames[i].cstring
    let structType = duckdb_create_struct_type(
      cast[ptr duckdb_logical_type](mtypes[0].addr),
      cast[ptr cstring](mnamesC[0].addr), nv.fields.len.idx_t)
    var values = newSeq[duckdb_value](nv.fields.len)
    for i, (name, el) in nv.fields:
      values[i] = toDuckValue(el)
    result = duckdb_create_struct_value(structType,
      cast[ptr duckdb_value](values[0].addr))
    for t in mtypes:
      duckdb_destroy_logical_type(t.addr)
    for v in values:
      duckdb_destroy_value(v.addr)
    duckdb_destroy_logical_type(structType.addr)
  of nvMap, nvUnion:
    raise newException(ValueError,
      "toDuckValue not yet implemented for complex kinds (" & $nv.kind &
      "); use typed bindVal/append overloads instead")


## The first cell of `qrs` (column 0, row 0) materialized as a `NimValue`;
## handy for `SELECT`-scalar convenience queries.
proc scalar*(qrs: QResult): NimValue =
  for chunk in qrs:
    return chunk.vector(0).toNimValue(0)

## The first cell of `qrs` (column 0, row 0) read via a typed `Vector[kt]`.
proc scalar*(qrs: QResult, kt: static DuckType): nimOf(kt) =
  for chunk in qrs:
    return chunk.bindAs(0, kt)[0]
