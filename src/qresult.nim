## Zero-copy *view* query-result API.
##
## A `QResult[T]` owns column metadata via a shared `ChunkMeta` ref and, for
## Materialized, a `seq` of owning `DataChunk` refs.  For Streaming, chunks are
## pulled lazily via `duckdb_fetch_chunk` and the result handle is destroyed
## when the QResult goes out of scope.
##
## A `Vector[kt]` is a *bound*, non-owning column view into one chunk: it
## holds a `pointer` to the raw `duckdb_vector` buffer, a length, a (possibly
## nil) validity bitmask pointer, and a back-ref to the owning `DataChunk` so
## the chunk stays ARC-alive for as long as any view references it. `kt` is a
## `static DuckType` — the compile-time source of truth — so bound vectors
## carry no runtime `kind` field and `[]`/`toSeq` dispatch at compile time,
## eliminating the giant per-row `case kind` of the old materialized `Vector`.
## Constructing a `Vector[kt]` (via `bindAs`) is zero-copy: it copies only the
## buffer pointer, validity pointer, and chunk back-ref — never the data.
##
## Element access via `[]` is zero-allocation for primitive, temporal,
## hugeint, enum, and interval kinds (it returns value types constructed from
## the raw buffer).  For varchar/bit/blob it **allocates and copies** per row;
## use `borrow()` for a true zero-copy pointer view into the duckdb buffer.
## UUID and Decimal `[]` allocate intermediate strings.  `toSeq` and `items`
## are explicit bulk materialize operations and always copy.
##
## A `ColumnView` is the *type-erased* intermediate you get from
## `chunk.vector(i)` or `chunk["name"]`; it carries a runtime `kind` and
## exists only so the caller can introspect before `bindAs`-ing.
##
## Complex child kinds (List/Array/Struct/Map/Union) are accessed through
## zero-copy descent procs: `listChild`, `listEntry`, `arrayChild`, `arraySize`,
## `structChild`, `structChildCount`, `structChildName`, `mapEntriesChild`,
## `mapKeyType`, `mapValueType`, `unionMemberChild`, `unionMemberCount`,
## `unionMemberName`.  `Vector[kt].[]` does not exist for complex kinds.

import std/[tables, math, times, strformat, sequtils, macros]
import nint128
import uuid4
import terminaltables

import /[ffi, types, codec]
import /compatibility/decimal_compat

type
  QResultType* = enum
    Streaming = 0
    Materialized = 1

  Column* = object
    idx*: int
    name*: string
    kind*: DuckType
    ltype*: LogicalType

  ChunkMeta* = ref object
    columns*: seq[Column]
    nameIndex*: Table[string, int]
    rlen*: int

  # --- owning ref: ARC-managed via =destroy on the underlying object ---

  DataChunkObj = object of RootObj
    handle: duckdb_data_chunk
    meta: ChunkMeta

  DataChunk* = ref DataChunkObj

  # --- wrapper that gives =destroy/=/=wasMoved to raw duckdb_result ---

  DuckdbResultHandle = object
    raw: duckdb_result

  # --- QResult variants ---

  QResult*[T: static QResultType] = object
    meta*: ChunkMeta
    when T == Streaming:
      handle*: DuckdbResultHandle
    when T == Materialized:
      chunks*: seq[DataChunk]

  # --- views: non-owning, carry a DataChunk back-ref for ARC safety ---

  Vector*[kt: static DuckType] = object
    data: pointer
    length*: int
    validity: ptr UncheckedArray[uint64]
    vec: duckdb_vector
    chunk: DataChunk
    when kt == DuckType.Decimal:
      scale*, width*: int8
    elif kt == DuckType.Enum:
      enumWidth*: DuckType
    when kt in DuckComplexKind:
      ltype: LogicalType
      colIdx: int

  ColumnView* = object
    kind*: DuckType
    vec: duckdb_vector
    ltype*: LogicalType
    colIdx: int
    data*: pointer
    length*: int
    validity: ptr UncheckedArray[uint64]
    chunk: DataChunk
    scale: int8
    width: int8
    enumWidth*: DuckType

# ---------------------------------------------------------------------------
# =destroy / =wasMoved / =copy hooks
# ---------------------------------------------------------------------------

proc `=destroy`(d: DataChunkObj) =
  if d.handle != nil:
    duckdb_destroy_data_chunk(d.handle.addr)

proc rawHandle*(d: DataChunk): duckdb_data_chunk {.inline.} =
  d.handle

proc `=destroy`(h: var DuckdbResultHandle) =
  if h.raw.internal_data != nil:
    duckdb_destroy_result(h.raw.addr)

proc `=wasMoved`(h: var DuckdbResultHandle) =
  h.raw.internal_data = nil

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------
proc newChunkMeta(columns: sink seq[Column]): ChunkMeta =
  new(result)
  result.columns = columns
  result.rlen = 0
  for i in 0 ..< columns.len:
    result.nameIndex[result.columns[i].name] = i

proc newChunkMeta(handle: duckdb_result): ChunkMeta =
  new(result)
  let colCount = duckdb_column_count(handle.addr).int
  result.columns = newSeq[Column](colCount)
  for i in 0 ..< colCount:
    let
      name = $duckdb_column_name(handle.addr, i.idx_t)
      kind = toDuckType(duckdb_column_type(handle.addr, i.idx_t))
      lhandle = duckdb_column_logical_type(handle.addr, i.idx_t)
      ltype = newLogicalType(lhandle)
    result.columns[i] = Column(idx: i, name: name, kind: kind, ltype: ltype)
    result.nameIndex[name] = i

proc newDataChunk*(
    handle: duckdb_data_chunk, meta: ChunkMeta
): DataChunk =
  DataChunk(handle: handle, meta: meta)

proc newDataChunk*(columns: sink seq[Column]): DataChunk =
  new(result)
  let ncols = columns.len
  if ncols == 0:
    raise newException(ValueError, "Cannot create a DataChunk with zero columns")
  result.meta = newChunkMeta(columns)
  for i, col in result.meta.columns:
    doAssert col.ltype != nil, "Column " & $i & " has nil LogicalType"
  var ltypes = newSeq[duckdb_logical_type](ncols)
  for i, col in result.meta.columns:
    ltypes[i] = col.ltype.handle
  result.handle = duckdb_create_data_chunk(cast[ptr duckdb_logical_type](ltypes[0].addr), ncols.idx_t)

proc newColumn*(name: string, ltype: LogicalType, idx = 0): Column =
  Column(idx: idx, name: name, kind: toDuckType(ltype), ltype: ltype)

proc newQResult*(_: typedesc[QResult[Materialized]], raw: duckdb_result): QResult[Materialized] =
  result.meta = newChunkMeta(raw)
  while true:
    let chunk = duckdb_fetch_chunk(raw)
    if chunk == nil: break
    let c = newDataChunk(chunk, result.meta)
    result.chunks.add(c)
    result.meta.rlen += duckdb_data_chunk_get_size(chunk).int
  duckdb_destroy_result(raw.addr)

proc newQResult*(_: typedesc[QResult[Streaming]], raw: duckdb_result): QResult[Streaming] =
  result.meta = newChunkMeta(raw)
  doAssert duckdb_result_is_streaming(raw) == true,
    "QResult[Streaming] requires a streaming result"
  result.meta.rlen = -1
  result.handle = DuckdbResultHandle(raw: raw)

# ---------------------------------------------------------------------------
# Iterators
# ---------------------------------------------------------------------------

iterator items*(res: QResult[Streaming]): DataChunk =
  while true:
    let raw = duckdb_fetch_chunk(res.handle.raw)
    if raw == nil: break
    yield newDataChunk(raw, res.meta)
  duckdb_destroy_result(res.handle.raw.addr)

iterator items*(res: QResult[Materialized]): DataChunk =
  for c in res.chunks:
    yield c

# ---------------------------------------------------------------------------
# DataChunk operations
# ---------------------------------------------------------------------------

proc len*(c: DataChunk): int {.inline.} =
  duckdb_data_chunk_get_size(c.handle).int

proc setSize*(c: DataChunk, n: int) {.inline.} =
  duckdb_data_chunk_set_size(c.handle, n.idx_t)

proc columnCount*(c: DataChunk): int {.inline.} = c.meta.columns.len

proc makeColumnView(
    vec: duckdb_vector, ltype: LogicalType, chunk: DataChunk, length: int, colIdx: int
): ColumnView {.inline.} =
  result.kind = toDuckType(ltype)
  result.vec = vec
  result.ltype = ltype
  result.colIdx = colIdx
  result.data = duckdb_vector_get_data(vec)
  result.length = length
  result.validity = cast[ptr UncheckedArray[uint64]](duckdb_vector_get_validity(vec))
  result.chunk = chunk
  if result.kind == DuckType.Decimal:
    result.scale = int8(duckdb_decimal_scale(ltype.handle))
    result.width = int8(duckdb_decimal_width(ltype.handle))
  elif result.kind == DuckType.Enum:
    result.enumWidth = cast[DuckType](duckdb_enum_internal_type(ltype.handle))

proc newColumnView(
    c: DataChunk, i: int, col: Column
): ColumnView {.inline.} =
  let vec = duckdb_data_chunk_get_vector(c.handle, i.idx_t)
  makeColumnView(vec, col.ltype, c, c.len, i)

proc vector*(c: DataChunk, i: int): ColumnView {.inline.} =
  if i < 0 or i >= c.meta.columns.len:
    raise newException(ValueError, "column index out of range: " & $i)
  let col = c.meta.columns[i]
  newColumnView(c, i, col)

proc vector*(c: DataChunk, name: string): ColumnView {.inline.} =
  if name notin c.meta.nameIndex:
    raise newException(KeyError, "no such column: " & name)
  let i = c.meta.nameIndex[name]
  c.vector(i)

proc `[]`*(c: DataChunk, name: string): ColumnView {.inline.} =
  c.vector(name)

# ---------------------------------------------------------------------------
# QResult metadata
# ---------------------------------------------------------------------------

proc columnCount*(q: QResult): int {.inline.} = q.meta.columns.len
proc column*(q: QResult, i: int): Column {.inline.} = q.meta.columns[i]
proc column*(q: QResult, name: string): Column {.inline.} =
  q.meta.columns[q.meta.nameIndex[name]]

proc columnIndex*(q: QResult, name: string): int {.inline.} = q.meta.nameIndex[name]

proc columnName*(q: QResult, i: int): string {.inline.} = q.meta.columns[i].name
proc columnKind*(q: QResult, i: int): DuckType {.inline.} = q.meta.columns[i].kind

iterator columns*(q: QResult): Column =
  for c in q.meta.columns:
    yield c

proc `$`*(c: Column): string =
  fmt("Column(idx={c.idx}, name={c.name}, kind={c.kind})")

proc `$`*(q: QResult[Streaming]): string =
  fmt("QResult(streaming, cols={q.meta.columns.len})")

# ---------------------------------------------------------------------------
# ColumnView / Vector[kt] — binding & validity
# ---------------------------------------------------------------------------

proc valid*(v: ColumnView, i: int): bool {.inline.} =
  if v.validity.isNil: return true
  (v.validity[i shr 6] and (1'u64 shl (i and 63))) != 0

proc valid*[kt: static DuckType](v: Vector[kt], i: int): bool {.inline.} =
  if v.validity.isNil: return true
  (v.validity[i shr 6] and (1'u64 shl (i and 63))) != 0

proc len*(v: ColumnView): int {.inline.} = v.length
proc len*[kt: static DuckType](v: Vector[kt]): int {.inline.} = v.length

proc bindAs*(cv: ColumnView, kt: static DuckType): Vector[kt] {.inline.} =
  if cv.kind != kt:
    raise newException(
      ValueError,
      "Vector kind mismatch: column is " & $cv.kind & ", requested " & $kt,
    )
  result.data = cv.data
  result.length = cv.length
  result.validity = cv.validity
  result.vec = cv.vec
  result.chunk = cv.chunk
  when kt == DuckType.Decimal:
    result.scale = cv.scale
    result.width = cv.width
  elif kt == DuckType.Enum:
    result.enumWidth = cv.enumWidth
  when kt in DuckComplexKind:
    result.ltype = cv.ltype
    result.colIdx = cv.colIdx

proc bindAs*(c: DataChunk, i: int, kt: static DuckType): Vector[kt] {.inline.} =
  c.vector(i).bindAs(kt)

proc bindAs*(c: DataChunk, name: string, kt: static DuckType): Vector[kt] {.inline.} =
  c[name].bindAs(kt)

# ---------------------------------------------------------------------------
# Per-kind Nim type mapping
# ---------------------------------------------------------------------------

template nimOf*(kt: static DuckType): typedesc =
  when kt == DuckType.Boolean: bool
  elif kt in DuckIntegerKind:
    when kt == DuckType.TinyInt: int8
    elif kt == DuckType.SmallInt: int16
    elif kt == DuckType.Integer: int32
    elif kt == DuckType.BigInt: int64
    elif kt == DuckType.UTinyInt: uint8
    elif kt == DuckType.USmallInt: uint16
    elif kt == DuckType.UInteger: uint32
    else: uint64
  elif kt == DuckType.Float: float32
  elif kt == DuckType.Double: float64
  elif kt in DuckStringKind: string
  elif kt in DuckBlobKind: seq[byte]
  elif kt == DuckType.HugeInt: Int128
  elif kt == DuckType.UHugeInt: UInt128
  elif kt == DuckType.UUID: Uuid
  elif kt == DuckType.Enum: uint
  elif kt == DuckType.Interval: TimeInterval
  elif kt == DuckType.Decimal: DecimalType
  elif kt == DuckType.Timestamp: Timestamp
  elif kt in {DuckType.TimestampS, DuckType.TimestampMs, DuckType.TimestampNs,
              DuckType.Date}:
    DateTime
  elif kt in {DuckType.Time, DuckType.TimeTz, DuckType.TimestampTz}:
    when kt == DuckType.Time: Time
    elif kt == DuckType.TimeTz: ZonedTime
    else: ZonedTime
  elif kt in DuckComplexKind:
    void

template colDuckTypeOf*(T: typedesc): static DuckType =
  when T is bool: DuckType.Boolean
  elif T is int8: DuckType.TinyInt
  elif T is int16: DuckType.SmallInt
  elif T is int32: DuckType.Integer
  elif T is int64 or T is int: DuckType.BigInt
  elif T is uint8 or T is byte: DuckType.UTinyInt
  elif T is uint16: DuckType.USmallInt
  elif T is uint32: DuckType.UInteger
  elif T is uint64 or T is uint: DuckType.UBigInt
  elif T is float32: DuckType.Float
  elif T is float64: DuckType.Double
  elif T is string: DuckType.Varchar
  elif T is seq[byte]: DuckType.Blob
  elif T is Timestamp or T is DateTime: DuckType.Timestamp
  elif T is Time: DuckType.Time
  elif T is TimeInterval: DuckType.Interval
  elif T is Int128: DuckType.HugeInt
  elif T is UInt128: DuckType.UHugeInt
  elif T is Uuid: DuckType.UUID
  elif T is DecimalType:
    {.error: "Decimal columns need explicit width/scale; use newLogicalType(duckdb_create_decimal_type(w, s)) + ChunkBuilder".}
  elif T is ZonedTime:
    {.error: "ZonedTime is ambiguous (TimeTz vs TimestampTz); use an explicit LogicalType".}
  else:
    {.error: "colDuckTypeOf: unsupported element type".}

# ---------------------------------------------------------------------------
# duckdb_string_t decoding — shared helpers
# ---------------------------------------------------------------------------

template rawStringView(s: ptr duckdb_string_t): (pointer, int) =
  if duckdb_string_is_inlined(s[]):
    let sinl = cast[ptr struct_duckdb_string_t_value_t_inlined_t](s)
    (cast[pointer](addr sinl.inlined[0]), int(sinl.length))
  else:
    let sptr = cast[ptr struct_duckdb_string_t_value_t](s)
    (cast[pointer](sptr.pointer.ptr_field), int(sptr.pointer.length))

proc decodeDuckString(s: ptr duckdb_string_t): string {.inline.} =
  let (src, ln) = rawStringView(s)
  if ln <= 0:
    return ""
  result = newString(ln)
  copyMem(addr result[0], src, ln)

proc decodeDuckBlob(s: ptr duckdb_string_t): seq[byte] {.inline.} =
  let (src, ln) = rawStringView(s)
  if ln <= 0:
    return @[]
  result = newSeq[byte](ln)
  copyMem(addr result[0], src, ln)

type
  DuckStringRef* = object
    data: pointer
    length*: int

  DuckBlobRef* = DuckStringRef

proc len*(r: DuckStringRef): int {.inline.} = r.length
proc data*(r: DuckStringRef): pointer {.inline.} = r.data

proc toString*(r: DuckStringRef): string =
  if r.length <= 0:
    return ""
  result = newString(r.length)
  copyMem(addr result[0], r.data, r.length)

proc toBytes*(r: DuckStringRef): seq[byte] =
  if r.length <= 0:
    return @[]
  result = newSeq[byte](r.length)
  copyMem(addr result[0], r.data, r.length)

proc borrow*(s: ptr duckdb_string_t): DuckStringRef {.inline.} =
  let (src, ln) = rawStringView(s)
  result = DuckStringRef(data: src, length: ln)

# ---------------------------------------------------------------------------
# Vector[kt] indexing — compile-time dispatch
# ---------------------------------------------------------------------------

proc `[]`*[kt: static DuckType](v: Vector[kt], i: int): nimOf(kt) {.inline.} =
  doAssert i >= 0 and i < v.length, "Vector index out of bounds: " & $i
  when kt in DuckPrimitiveKind:
    cast[ptr UncheckedArray[nimOf(kt)]](v.data)[i]
  elif kt == DuckType.Boolean:
    bool(cast[ptr UncheckedArray[uint8]](v.data)[i])
  elif kt in DuckStringKind:
    decodeDuckString(addr cast[ptr UncheckedArray[duckdb_string_t]](v.data)[i])
  elif kt in DuckBlobKind:
    decodeDuckBlob(addr cast[ptr UncheckedArray[duckdb_string_t]](v.data)[i])
  elif kt == DuckType.Timestamp:
    fromTimestamp(cast[ptr UncheckedArray[int64]](v.data)[i])
  elif kt == DuckType.TimestampS:
    fromDuckTimestampS(cast[ptr UncheckedArray[int64]](v.data)[i])
  elif kt == DuckType.TimestampMs:
    fromDuckTimestampMs(cast[ptr UncheckedArray[int64]](v.data)[i])
  elif kt == DuckType.TimestampNs:
    fromDuckTimestampNs(cast[ptr UncheckedArray[int64]](v.data)[i])
  elif kt == DuckType.Date:
    fromDuckDate(cast[ptr UncheckedArray[int32]](v.data)[i])
  elif kt == DuckType.Time:
    fromDuckTime(cast[ptr UncheckedArray[int64]](v.data)[i])
  elif kt == DuckType.TimeTz:
    fromDuckTimeTz(cast[ptr UncheckedArray[int64]](v.data)[i])
  elif kt == DuckType.TimestampTz:
    fromDuckTimestampTz(cast[ptr UncheckedArray[int64]](v.data)[i])
  elif kt == DuckType.HugeInt:
    fromHugeInt(cast[ptr UncheckedArray[duckdb_hugeint]](v.data)[i])
  elif kt == DuckType.UHugeInt:
    fromUHugeInt(cast[ptr UncheckedArray[duckdb_uhugeint]](v.data)[i])
  elif kt == DuckType.UUID:
    fromDuckUuid(cast[ptr UncheckedArray[duckdb_hugeint]](v.data)[i])
  elif kt == DuckType.Interval:
    fromInterval(cast[ptr UncheckedArray[duckdb_interval]](v.data)[i])
  elif kt == DuckType.Decimal:
    fromDuckDecimal(v.scale, v.width, v.data, i)
  elif kt == DuckType.Enum:
    fromDuckEnum(v.enumWidth, v.data, i)
  elif kt in DuckComplexKind:
    {.error: "Vector[" & $kt & "] does not support `[]`; use listChild/" &
            "structChild/mapEntriesChild/unionMemberChild descent procs".}

# ---------------------------------------------------------------------------
# Vector[kt] `[]=` — compile-time dispatch, zero-copy for primitives
# ---------------------------------------------------------------------------

proc `[]=`*[kt: static DuckType](v: var Vector[kt], i: int, val: nimOf(kt)) {.inline.} =
  doAssert i >= 0 and i < v.length, "Vector index out of bounds: " & $i
  when kt in DuckPrimitiveKind:
    cast[ptr UncheckedArray[nimOf(kt)]](v.data)[i] = val
  elif kt == DuckType.Boolean:
    cast[ptr UncheckedArray[uint8]](v.data)[i] = uint8(val)
  elif kt in DuckStringKind:
    duckdb_vector_assign_string_element_len(v.vec, i.idx_t, val.cstring, val.len.idx_t)
  elif kt in DuckBlobKind:
    duckdb_vector_assign_string_element_len(v.vec, i.idx_t,
      cast[cstring](if val.len > 0: cast[pointer](val[0].addr) else: nil),
      val.len.idx_t)
  elif kt == DuckType.Timestamp:
    cast[ptr UncheckedArray[int64]](v.data)[i] = toTimestamp(val).micros
  elif kt == DuckType.Date:
    cast[ptr UncheckedArray[int32]](v.data)[i] = toDatetime(val).days
  elif kt == DuckType.Time:
    cast[ptr UncheckedArray[int64]](v.data)[i] = toTime(val).micros
  elif kt == DuckType.Interval:
    cast[ptr UncheckedArray[duckdb_interval]](v.data)[i] = toInterval(val)
  elif kt == DuckType.HugeInt:
    cast[ptr UncheckedArray[duckdb_hugeint]](v.data)[i] = toHugeInt(val)
  elif kt == DuckType.UHugeInt:
    cast[ptr UncheckedArray[duckdb_uhugeint]](v.data)[i] = toUHugeInt(val)
  elif kt == DuckType.UUID:
    cast[ptr UncheckedArray[duckdb_hugeint]](v.data)[i] = toDuckUuid(val)
  elif kt == DuckType.TimestampS:
    cast[ptr UncheckedArray[int64]](v.data)[i] = toDuckTimestampS(val)
  elif kt == DuckType.TimestampMs:
    cast[ptr UncheckedArray[int64]](v.data)[i] = toDuckTimestampMs(val)
  elif kt == DuckType.TimestampNs:
    cast[ptr UncheckedArray[int64]](v.data)[i] = toDuckTimestampNs(val)
  elif kt == DuckType.TimeTz:
    cast[ptr UncheckedArray[int64]](v.data)[i] = toDuckTimeTz(val)
  elif kt == DuckType.TimestampTz:
    cast[ptr UncheckedArray[int64]](v.data)[i] = toDuckTimestampTz(val)
  elif kt == DuckType.Decimal:
    let huge = toHugeInt(toDuckDecimal(val, v.width, v.scale))
    if v.width <= 4:
      var s64: int64
      copyMem(addr s64, addr huge.lower, sizeof(int64))
      cast[ptr UncheckedArray[int16]](v.data)[i] = int16(s64)
    elif v.width <= 9:
      var s64: int64
      copyMem(addr s64, addr huge.lower, sizeof(int64))
      cast[ptr UncheckedArray[int32]](v.data)[i] = int32(s64)
    elif v.width <= 18:
      var s64: int64
      copyMem(addr s64, addr huge.lower, sizeof(int64))
      cast[ptr UncheckedArray[int64]](v.data)[i] = s64
    else:
      cast[ptr UncheckedArray[duckdb_hugeint]](v.data)[i] = huge
  elif kt == DuckType.Enum:
    case v.enumWidth
    of DuckType.UTinyInt:
      cast[ptr UncheckedArray[uint8]](v.data)[i] = uint8(val)
    of DuckType.USmallInt:
      cast[ptr UncheckedArray[uint16]](v.data)[i] = uint16(val)
    of DuckType.UInteger:
      cast[ptr UncheckedArray[uint32]](v.data)[i] = uint32(val)
    else:
      raise newException(ValueError, "enumWidth not supported for write: " & $v.enumWidth)
  elif kt in DuckComplexKind:
    {.error: "Vector[" & $kt & "] does not support `[]=`; use child writers.".}

proc setNull*[kt: static DuckType](v: var Vector[kt], i: int) {.inline.} =
  doAssert i >= 0 and i < v.length, "Vector index out of bounds: " & $i
  if v.validity.isNil:
    duckdb_vector_ensure_validity_writable(v.vec)
    v.validity = cast[ptr UncheckedArray[uint64]](duckdb_vector_get_validity(v.vec))
  duckdb_validity_set_row_invalid(cast[ptr uint64](v.validity), i.idx_t)

proc setValid*[kt: static DuckType](v: var Vector[kt], i: int) {.inline.} =
  doAssert i >= 0 and i < v.length, "Vector index out of bounds: " & $i
  if v.validity.isNil:
    duckdb_vector_ensure_validity_writable(v.vec)
    v.validity = cast[ptr UncheckedArray[uint64]](duckdb_vector_get_validity(v.vec))
  duckdb_validity_set_row_valid(cast[ptr uint64](v.validity), i.idx_t)

proc appendValues*[kt: static DuckType](
    v: var Vector[kt], values: openArray[nimOf(kt)], start = 0) =
  if values.len == 0:
    return
  doAssert start >= 0 and start + values.len <= v.length,
           "appendValues out of bounds: start=" & $start &
           " n=" & $values.len & " capacity=" & $v.length
  when kt in DuckPrimitiveKind:
    copyMem(
      cast[ptr UncheckedArray[nimOf(kt)]](v.data)[start].addr,
      values[0].unsafeAddr,
      values.len * sizeof(nimOf(kt)))
  elif kt == DuckType.Boolean:
    copyMem(
      cast[ptr UncheckedArray[uint8]](v.data)[start].addr,
      values[0].unsafeAddr,
      values.len)
  elif kt in DuckStringKind:
    for i in 0 ..< values.len:
      let s = values[i]
      duckdb_vector_assign_string_element_len(
        v.vec, (start + i).idx_t, s.cstring, s.len.idx_t)
  elif kt in DuckBlobKind:
    for i in 0 ..< values.len:
      let s = values[i]
      duckdb_vector_assign_string_element_len(
        v.vec, (start + i).idx_t,
        cast[cstring](if s.len > 0: cast[pointer](s[0].addr) else: nil),
        s.len.idx_t)
  elif kt == DuckType.Timestamp:
    let dst = cast[ptr UncheckedArray[int64]](v.data)
    for i in 0 ..< values.len: dst[start + i] = toTimestamp(values[i]).micros
  elif kt == DuckType.Date:
    let dst = cast[ptr UncheckedArray[int32]](v.data)
    for i in 0 ..< values.len: dst[start + i] = toDatetime(values[i]).days
  elif kt == DuckType.Time:
    let dst = cast[ptr UncheckedArray[int64]](v.data)
    for i in 0 ..< values.len: dst[start + i] = toTime(values[i]).micros
  elif kt == DuckType.Interval:
    let dst = cast[ptr UncheckedArray[duckdb_interval]](v.data)
    for i in 0 ..< values.len: dst[start + i] = toInterval(values[i])
  elif kt == DuckType.HugeInt:
    let dst = cast[ptr UncheckedArray[duckdb_hugeint]](v.data)
    for i in 0 ..< values.len: dst[start + i] = toHugeInt(values[i])
  elif kt == DuckType.UHugeInt:
    let dst = cast[ptr UncheckedArray[duckdb_uhugeint]](v.data)
    for i in 0 ..< values.len: dst[start + i] = toUHugeInt(values[i])
  elif kt == DuckType.UUID:
    let dst = cast[ptr UncheckedArray[duckdb_hugeint]](v.data)
    for i in 0 ..< values.len: dst[start + i] = toDuckUuid(values[i])
  elif kt == DuckType.TimestampS:
    let dst = cast[ptr UncheckedArray[int64]](v.data)
    for i in 0 ..< values.len: dst[start + i] = toDuckTimestampS(values[i])
  elif kt == DuckType.TimestampMs:
    let dst = cast[ptr UncheckedArray[int64]](v.data)
    for i in 0 ..< values.len: dst[start + i] = toDuckTimestampMs(values[i])
  elif kt == DuckType.TimestampNs:
    let dst = cast[ptr UncheckedArray[int64]](v.data)
    for i in 0 ..< values.len: dst[start + i] = toDuckTimestampNs(values[i])
  elif kt == DuckType.TimeTz:
    let dst = cast[ptr UncheckedArray[int64]](v.data)
    for i in 0 ..< values.len: dst[start + i] = toDuckTimeTz(values[i])
  elif kt == DuckType.TimestampTz:
    let dst = cast[ptr UncheckedArray[int64]](v.data)
    for i in 0 ..< values.len: dst[start + i] = toDuckTimestampTz(values[i])
  elif kt == DuckType.Decimal:
    for i in 0 ..< values.len:
      var tmp = v
      tmp[start + i] = values[i]
  elif kt == DuckType.Enum:
    for i in 0 ..< values.len:
      var tmp = v
      tmp[start + i] = values[i]
  elif kt in DuckComplexKind:
    {.error: "appendValues not supported for complex kinds; use child descent procs".}

# ---------------------------------------------------------------------------
# ChunkBuilder — column-oriented DataChunk construction
# ---------------------------------------------------------------------------

type
  ChunkBuilder* = object
    chunk: DataChunk
    colRows: seq[int]
    capacity: int

proc `=copy`*(dest: var ChunkBuilder, src: ChunkBuilder) {.error.}
proc `=dup`*(src: ChunkBuilder): ChunkBuilder {.error.}

proc newChunkBuilder*(columns: sink seq[Column]): ChunkBuilder =
  result.chunk = newDataChunk(columns)
  result.colRows = newSeq[int](columns.len)
  result.capacity = VECTOR_SIZE
  result.chunk.setSize(VECTOR_SIZE)

proc newChunkBuilder*(chunk: sink DataChunk): ChunkBuilder =
  result.chunk = chunk
  result.colRows = newSeq[int](chunk.columnCount)
  result.capacity = VECTOR_SIZE
  result.chunk.setSize(VECTOR_SIZE)

proc len*(b: ChunkBuilder): int {.inline.} =
  if b.colRows.len > 0: b.colRows[0] else: 0

proc appendedRows*(b: ChunkBuilder, col: int): int {.inline.} =
  doAssert col in 0 ..< b.colRows.len, "column out of range"
  b.colRows[col]

proc columnCount*(b: ChunkBuilder): int {.inline.} = b.colRows.len

proc append*[kt: static DuckType](
    b: var ChunkBuilder, col: int, val: sink nimOf(kt)) =
  doAssert col in 0 ..< b.colRows.len, "column out of range"
  doAssert b.colRows[col] < b.capacity, "chunk capacity exceeded"
  var w = b.chunk.bindAs(col, kt)
  w[b.colRows[col]] = val
  inc b.colRows[col]

proc appendNull*[kt: static DuckType](
    b: var ChunkBuilder, col: int) =
  doAssert col in 0 ..< b.colRows.len, "column out of range"
  doAssert b.colRows[col] < b.capacity, "chunk capacity exceeded"
  var w = b.chunk.bindAs(col, kt)
  w.setNull(b.colRows[col])
  inc b.colRows[col]

proc appendValues*[kt: static DuckType](
    b: var ChunkBuilder, col: int,
    values: openArray[nimOf(kt)]) =
  doAssert col in 0 ..< b.colRows.len, "column out of range"
  doAssert b.colRows[col] + values.len <= b.capacity, "chunk capacity exceeded"
  var w = b.chunk.bindAs(col, kt)
  w.appendValues(values, start = b.colRows[col])
  b.colRows[col] += values.len

proc appendNulls*[kt: static DuckType](
    b: var ChunkBuilder, col: int, n: int) =
  for _ in 0 ..< n: appendNull[kt](b, col)

proc finish*(b: var ChunkBuilder): DataChunk =
  doAssert b.chunk != nil, "ChunkBuilder already finished"
  let n = b.colRows[0]
  for i in 1 ..< b.colRows.len:
    if b.colRows[i] != n:
      raise newException(ValueError,
        "column length mismatch: col 0 has " & $n & " rows, col " & $i &
        " has " & $b.colRows[i])
  b.chunk.setSize(n)
  result = move(b.chunk)

# ---------------------------------------------------------------------------
# Seq constructors — single-column and multi-column DataChunk creation
# ---------------------------------------------------------------------------

proc newDataChunk*[T](name: string, values: sink seq[T]): DataChunk =
  result = newDataChunk(@[newColumn(name, newLogicalType(colDuckTypeOf(T)))])
  result.setSize(values.len)
  if values.len > 0:
    var w = result.bindAs(0, colDuckTypeOf(T))
    w.appendValues(values)

macro newChunk*(pairs: varargs[typed]): untyped =
  proc ktNode(elemType: NimNode): NimNode =
    let n = repr(elemType)
    let dt = ident"DuckType"
    if n == "bool": newDotExpr(dt, ident"Boolean")
    elif n == "int8": newDotExpr(dt, ident"TinyInt")
    elif n == "int16": newDotExpr(dt, ident"SmallInt")
    elif n == "int32": newDotExpr(dt, ident"Integer")
    elif n == "int64" or n == "int": newDotExpr(dt, ident"BigInt")
    elif n == "uint8" or n == "byte": newDotExpr(dt, ident"UTinyInt")
    elif n == "uint16": newDotExpr(dt, ident"USmallInt")
    elif n == "uint32": newDotExpr(dt, ident"UInteger")
    elif n == "uint64" or n == "uint": newDotExpr(dt, ident"UBigInt")
    elif n == "float32": newDotExpr(dt, ident"Float")
    elif n == "float64": newDotExpr(dt, ident"Double")
    elif n == "string": newDotExpr(dt, ident"Varchar")
    elif n == "seq[byte]": newDotExpr(dt, ident"Blob")
    elif n == "Timestamp" or n == "DateTime": newDotExpr(dt, ident"Timestamp")
    elif n == "Time": newDotExpr(dt, ident"Time")
    elif n == "TimeInterval": newDotExpr(dt, ident"Interval")
    elif n == "Int128": newDotExpr(dt, ident"HugeInt")
    elif n == "UInt128": newDotExpr(dt, ident"UHugeInt")
    elif n == "Uuid": newDotExpr(dt, ident"UUID")
    else: error "unsupported element type: " & n, elemType
  if pairs.len < 1:
    error "newChunk needs at least one (name, seq) pair"
  let chunkL = genSym(nskVar, "chunkL")
  let nL = genSym(nskLet, "nL")
  var
    colDefs = newNimNode(nnkBracket)
    lenChecks = newNimNode(nnkStmtList)
    fills = newNimNode(nnkStmtList)
    firstSeq: NimNode = nil
  for i, pair in pairs:
    if pair.kind != nnkTupleConstr or pair.len != 2:
      error "each argument must be a (name, seq) tuple", pair
    let
      nameAst = pair[0]
      seqAst = pair[1]
    if firstSeq.isNil: firstSeq = seqAst
    let seqType = seqAst.getTypeInst
    let elemType =
      if seqType.kind == nnkBracketExpr and seqType.len == 2: seqType[1]
      else: error "expected seq[T], got " & $seqType, seqAst
    let kt = ktNode(elemType)
    colDefs.add(newCall(bindSym"newColumn", nameAst,
                        newCall(bindSym"newLogicalType", kt)))
    if i > 0:
      lenChecks.add(newCall(bindSym"doAssert",
        infix(newDotExpr(seqAst, ident"len"), "==", newDotExpr(firstSeq, ident"len")),
        newStrLitNode("column length mismatch in newChunk")))
    let wI = genSym(nskVar, "w" & $i)
    fills.add(newVarStmt(wI, newCall(bindSym"bindAs", chunkL, newLit i, kt)))
    fills.add(newCall(bindSym"appendValues", wI, seqAst))
  result = newStmtList()
  result.add(newVarStmt(chunkL,
    newCall(bindSym"newDataChunk", prefix(colDefs, "@"))))
  result.add(newLetStmt(nL, newDotExpr(firstSeq, ident"len")))
  result.add(lenChecks)
  result.add(newCall(newDotExpr(chunkL, ident"setSize"), nL))
  result.add(fills)
  result.add(chunkL)

# ---------------------------------------------------------------------------
# borrow() — non-allocating view for VARCHAR / Bit / Blob
# ---------------------------------------------------------------------------

proc borrow*[kt: static DuckType](v: Vector[kt], i: int): DuckStringRef {.inline.} =
  when kt in DuckStringKind or kt in DuckBlobKind:
    borrow(addr cast[ptr UncheckedArray[duckdb_string_t]](v.data)[i])
  else:
    {.error: "borrow() only defined for string/blob kinds; got " & $kt.}

# ---------------------------------------------------------------------------
# Zero-copy descent procs — complex child kinds
# ---------------------------------------------------------------------------

proc listChild*(v: Vector[DuckType.List]): ColumnView {.inline.} =
  let childVec = duckdb_list_vector_get_child(v.vec)
  let childLtype = newLogicalType(duckdb_list_type_child_type(v.ltype.handle))
  makeColumnView(childVec, childLtype, v.chunk,
    duckdb_list_vector_get_size(v.vec).int, -1)

proc listEntry*(v: Vector[DuckType.List], i: int): (uint64, uint64) {.inline.} =
  let entry = cast[ptr UncheckedArray[duckdb_list_entry]](v.data)[i]
  (entry.offset, entry.length)

proc arrayChild*(v: Vector[DuckType.Array]): ColumnView {.inline.} =
  let childVec = duckdb_array_vector_get_child(v.vec)
  let childLtype = newLogicalType(duckdb_array_type_child_type(v.ltype.handle))
  let arraySize = duckdb_array_type_array_size(v.ltype.handle).int
  makeColumnView(childVec, childLtype, v.chunk, v.length * arraySize, -1)

proc arraySize*(v: Vector[DuckType.Array]): int {.inline.} =
  duckdb_array_type_array_size(v.ltype.handle).int

proc structChildCount*(v: Vector[DuckType.Struct]): int {.inline.} =
  duckdb_struct_type_child_count(v.ltype.handle).int

proc duckStr(s: cstring): string {.inline.} =
  ## Copies a DuckDB-allocated cstring into a Nim string and frees the backing buffer.
  if s.isNil: return ""
  result = $s
  duckdb_free(cast[pointer](s))

proc structChildName*(v: Vector[DuckType.Struct], j: int): string {.inline.} =
  duckStr(duckdb_struct_type_child_name(v.ltype.handle, j.idx_t))

proc structChild*(v: Vector[DuckType.Struct], j: int): ColumnView {.inline.} =
  let childVec = duckdb_struct_vector_get_child(v.vec, j.idx_t)
  let childLtype = newLogicalType(duckdb_struct_type_child_type(v.ltype.handle, j.idx_t))
  makeColumnView(childVec, childLtype, v.chunk, v.length, -1)

proc structChild*(v: Vector[DuckType.Struct], name: string): ColumnView {.inline.} =
  for j in 0 ..< v.structChildCount:
    if v.structChildName(j) == name:
      return v.structChild(j)
  raise newException(KeyError, "struct has no child named: " & name)

proc mapKeyType*(v: Vector[DuckType.Map]): LogicalType {.inline.} =
  newLogicalType(duckdb_map_type_key_type(v.ltype.handle))

proc mapValueType*(v: Vector[DuckType.Map]): LogicalType {.inline.} =
  newLogicalType(duckdb_map_type_value_type(v.ltype.handle))

proc mapEntriesChild*(v: Vector[DuckType.Map]): ColumnView {.inline.} =
  let entriesVec = duckdb_list_vector_get_child(v.vec)
  let entryLtype = newLogicalType(duckdb_list_type_child_type(v.ltype.handle))
  makeColumnView(entriesVec, entryLtype, v.chunk,
    duckdb_list_vector_get_size(v.vec).int, -1)

proc unionMemberCount*(v: Vector[DuckType.Union]): int {.inline.} =
  duckdb_union_type_member_count(v.ltype.handle).int

proc unionMemberName*(v: Vector[DuckType.Union], j: int): string {.inline.} =
  duckStr(duckdb_union_type_member_name(v.ltype.handle, j.idx_t))

proc unionMemberChild*(v: Vector[DuckType.Union], j: int): ColumnView {.inline.} =
  let memberType = newLogicalType(duckdb_union_type_member_type(v.ltype.handle, j.idx_t))
  let memberVec = duckdb_struct_vector_get_child(v.vec, (j + 1).idx_t)
  makeColumnView(memberVec, memberType, v.chunk, v.length, -1)

proc unionTag*(v: Vector[DuckType.Union], i: int): int {.inline.} =
  let tagVec = duckdb_struct_vector_get_child(v.vec, 0)
  let tagData = duckdb_vector_get_data(tagVec)
  let tagValidity = cast[ptr UncheckedArray[uint64]](duckdb_vector_get_validity(tagVec))
  if tagValidity != nil and
      (tagValidity[i shr 6] and (1'u64 shl (i and 63))) == 0:
    return -1
  cast[ptr UncheckedArray[uint8]](tagData)[i].int

proc mapEntry*(v: Vector[DuckType.Map], i: int): (uint64, uint64) {.inline.} =
  let entry = cast[ptr UncheckedArray[duckdb_list_entry]](v.data)[i]
  (entry.offset, entry.length)

# ---------------------------------------------------------------------------
# items iterator — yields Nim equivalents per row, honouring validity
# ---------------------------------------------------------------------------

iterator items*[kt: static DuckType](v: Vector[kt]): nimOf(kt) =
  let n = v.length
  for i in 0 ..< n:
    if v.valid(i): yield v[i]
    else: yield default(nimOf(kt))


# ---------------------------------------------------------------------------
# toSeq — explicit bulk materialise for any kind
# ---------------------------------------------------------------------------

proc toSeq*[kt: static DuckType](v: Vector[kt]): seq[nimOf(kt)] =
  result = newSeq[nimOf(kt)](v.length)
  for i in 0 ..< v.length:
    if v.valid(i): result[i] = v[i] else: result[i] = default(nimOf(kt))

# ---------------------------------------------------------------------------
# Preview / display helpers for QResult[Materialized]
# ---------------------------------------------------------------------------

const
  previewMaxRows = 20
  clipWidth = 20

proc len*(q: QResult[Materialized]): int {.inline.} =
  q.meta.rlen

proc clipStr(str: string, at: int): string =
  if len(str) > at:
    result = str[0 .. at] & "..."
  else:
    result = str

proc renderCell*(cv: ColumnView, i: int): string =
  if not cv.valid(i):
    return "NULL"
  case cv.kind
  of DuckType.Boolean:
    let v = cv.bindAs(DuckType.Boolean)
    result = $v[i]
  of DuckType.TinyInt:
    let v = cv.bindAs(DuckType.TinyInt)
    result = $v[i]
  of DuckType.SmallInt:
    let v = cv.bindAs(DuckType.SmallInt)
    result = $v[i]
  of DuckType.Integer:
    let v = cv.bindAs(DuckType.Integer)
    result = $v[i]
  of DuckType.BigInt:
    let v = cv.bindAs(DuckType.BigInt)
    result = $v[i]
  of DuckType.UTinyInt:
    let v = cv.bindAs(DuckType.UTinyInt)
    result = $v[i]
  of DuckType.USmallInt:
    let v = cv.bindAs(DuckType.USmallInt)
    result = $v[i]
  of DuckType.UInteger:
    let v = cv.bindAs(DuckType.UInteger)
    result = $v[i]
  of DuckType.UBigInt:
    let v = cv.bindAs(DuckType.UBigInt)
    result = $v[i]
  of DuckType.Float:
    let v = cv.bindAs(DuckType.Float)
    result = $v[i]
  of DuckType.Double:
    let v = cv.bindAs(DuckType.Double)
    result = $v[i]
  of DuckType.Varchar, DuckType.Bit:
    let v = cv.bindAs(DuckType.Varchar)
    result = v[i]
  of DuckType.HugeInt:
    let v = cv.bindAs(DuckType.HugeInt)
    result = $v[i]
  of DuckType.UHugeInt:
    let v = cv.bindAs(DuckType.UHugeInt)
    result = $v[i]
  of DuckType.Decimal:
    result = $(cv.bindAs(DuckType.Decimal))[i]
  of DuckType.UUID:
    result = $(cv.bindAs(DuckType.UUID))[i]
  else:
    result = "<" & $cv.kind & ">"

proc `$`*(q: QResult[Materialized]): string =
  let colCount = q.columnCount
  if colCount == 0:
    return ""

  var headerStrs = newSeq[string](colCount)
  for i in 0 ..< colCount:
    headerStrs[i] = clipStr(q.meta.columns[i].name, clipWidth)

  var t = newUnicodeTable()
  t.setHeaders(headerStrs.mapIt(newCell(it, pad = 5)))
  t.separateRows = false

  var rowCount = 0
  block outer:
    for chunk in q:
      let chunkLen = chunk.len
      var cvs = newSeq[ColumnView](colCount)
      for ci in 0 ..< colCount:
        cvs[ci] = chunk.vector(ci)
      for ri in 0 ..< chunkLen:
        if rowCount >= previewMaxRows:
          break outer
        var row = newSeq[string](colCount)
        for ci in 0 ..< colCount:
          row[ci] = renderCell(cvs[ci], ri)
        t.addRow(row)
        inc rowCount

  if q.meta.rlen > previewMaxRows:
    t.addRow(newSeq[string](colCount))
  result = t.render()

# ---------------------------------------------------------------------------
# materialize — drain a streaming result into a materialized one
# ---------------------------------------------------------------------------

proc materialize*(q: sink QResult[Streaming]): QResult[Materialized] =
  ## Drain all remaining chunks from a streaming result and return a
  ## fully materialized `QResult[Materialized]`.
  result.meta = q.meta
  result.chunks = @[]
  result.meta.rlen = 0
  while true:
    let raw = duckdb_fetch_chunk(q.handle.raw)
    if raw == nil:
      break
    let c = newDataChunk(raw, result.meta)
    result.chunks.add(c)
    result.meta.rlen += c.len
  duckdb_destroy_result(q.handle.raw.addr)
  q.handle.raw.internal_data = nil

when defined(features.nimdrake.arrow):
  import narrow

  type
    ArrowSchema* = object
      format*: cstring
      name*: cstring
      metadata*: cstring
      flags*: int64
      n_children*: int64
      children*: ptr ptr ArrowSchema
      dictionary*: ptr ArrowSchema
      release*: proc(schema: ptr ArrowSchema) {.cdecl.}
      private_data*: pointer

    ArrowArray* = object
      length*: int64
      null_count*: int64
      offset*: int64
      n_buffers*: int64
      n_children*: int64
      buffers*: ptr pointer
      children*: ptr ptr ArrowArray
      dictionary*: ptr ArrowArray
      release*: proc(array: ptr ArrowArray) {.cdecl.}
      private_data*: pointer

    ArrowOptions* = object
      handle: duckdb_arrow_options

  proc `=destroy`(opt: ArrowOptions) =
    if opt.handle != nil:
      duckdb_destroy_arrow_options(opt.handle.addr)

  proc `=wasMoved`(opt: var ArrowOptions) =
    opt.handle = nil

  proc `=copy`(dest: var ArrowOptions, source: ArrowOptions) {.error.}
  proc `=dup`(opt: ArrowOptions): ArrowOptions {.error.}

  proc `=destroy`(arr: ArrowArray) {.raises: [].} =
    if not isNil(arr.release):
      try:
        arr.release(arr.addr)
      except Exception:
        discard

  proc `=destroy`(schema: ArrowSchema) {.raises: [].} =
    if not isNil(schema.release):
      schema.release(schema.addr)

  proc newArrowOptions*(res: ptr duckdb_result): ArrowOptions =
    result.handle = duckdb_result_get_arrow_options(res)

  proc newArrowArray(opt: ArrowOptions, chunk: DataChunk): ArrowArray {.raises: [OperationError]} =
    let err = duckdb_data_chunk_to_arrow(
      opt.handle, chunk.handle, cast[ptr struct_ArrowArray](result.addr)
    )
    if duckdb_error_data_has_error(err).bool:
      let msg = $duckdb_error_data_message(err)
      duckdb_destroy_error_data(err.addr)
      raise newException(OperationError, msg)

  proc newArrowSchema(opt: ArrowOptions, cols: sink seq[Column]): ArrowSchema {.raises: [OperationError]} =
    var
      handles = newSeq[duckdbLogicalType](len(cols))
      names = newSeq[cstring](len(cols))
    for i in 0 ..< cols.len:
      handles[i] = cols[i].ltype.handle
      names[i] = cols[i].name.cstring
    let err = duckdb_to_arrow_schema(
      opt.handle,
      cast[ptr duckdbLogicalType](handles[0].addr),
      cast[ptr cstring](names[0].addr),
      len(cols).idx_t,
      cast[ptr struct_ArrowSchema](result.addr),
    )
    if not isNil(err):
      raise newException(OperationError, $duckdb_error_data_message(err))

  iterator toArrowStream*(
      qrs: QResult[Streaming]; options: ArrowOptions; gSchema: Schema
  ): RecordBatch =
    while true:
      let raw = duckdb_fetch_chunk(qrs.handle.raw)
      if raw == nil: break
      let chunk = newDataChunk(raw, qrs.meta)
      let aArray = newArrowArray(options, chunk)
      yield newRecordBatch(aArray.addr, gSchema)

  iterator toArrowStream*(qrs: QResult[Streaming]): RecordBatch =
    let options = newArrowOptions(qrs.handle.raw.addr)
    let schema  = newArrowSchema(options, qrs.meta.columns)
    let gSchema = newSchema(cast[pointer](schema.addr))
    for batch in toArrowStream(qrs, options, gSchema):
      yield batch

  proc toArrowTable*(qrs: QResult[Streaming]): ArrowTable =
    var recordBatches = newSeq[RecordBatch]()
    let options = newArrowOptions(qrs.handle.raw.addr)
    let schema  = newArrowSchema(options, qrs.meta.columns)
    let gSchema = newSchema(cast[pointer](schema.addr))
    for batch in qrs.toArrowStream(options, gSchema):
      recordBatches.add(batch)
    result = newArrowTable(gSchema, recordBatches)
