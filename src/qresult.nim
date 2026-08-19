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
## use `borrow()` (or the `borrowItems` iterator) for a true zero-copy pointer
## view into the duckdb buffer.  UUID `[]` copies a 16-byte value; Decimal `[`
## **allocates an intermediate string** — for hot decimal paths prefer
## `borrowDecimal`, which returns the raw `(Int128, width, scale)` triple with no
## allocation, and `borrowUuid` for the raw 128-bit UUID.  `toSeq`, `items`,
## `toSeqOpt`, and `itemsOpt` are explicit bulk operations; `items`/`toSeq` copy
## (NULL rows become `default(T)`), while the `Opt` variants preserve null-ness
## via `Option[T]` at no per-row allocation cost for primitive kinds. Repeated
## owned scans can use `toSeqInto` and `toSeqOptInto` to reuse destination
## capacity.
##
## A `ColumnView` is the *type-erased* intermediate you get from
## `chunk.vector(i)` or `chunk["name"]`; it carries a runtime `kind` and
## exists only so the caller can introspect before `bindAs`-ing.
##
## Complex child kinds are exposed two ways:
##
## **Typed bound container views** — `bindAs(Table[K,V])` /
## `bindAs(OrderedTable[K,V])` mints a `MapView`, `bindAs(seq[T])` mints a
## `ListView`, `bindAsArray(kt)` mints an `ArrayView`. Each carries the child
## kind(s) statically and offers Nim-native table/seq-like row access:
## `mv[i]` returns `OrderedTable[K,V]`; `mv.borrowMap(i)` returns a zero-copy
## `MapRowView` with `[]`, `getOrDefault`, `contains`, `pairs`/`keys`/`values`
## that read straight out of the DuckDB buffer. `lv[i]` returns `seq[T]`;
## `lv.borrowList(i)` returns a zero-copy `SliceView`. Array has the same shape
## with a fixed `arraySize`. Construction is zero-copy: it caches the bound
## child vectors once, eliminating the manual `mapEntriesChild` /
## `structChild(0)` / `structChild(1)` chain callers used to write per call.
##
## **Zero-copy descent procs** — the lower-level `listChild`, `listEntry`,
## `arrayChild`, `arraySize`, `structChild`, `structChildCount`,
## `structChildName`, `mapEntriesChild`, `mapKeyType`, `mapValueType`,
## `unionMemberChild`, `unionMemberCount`, `unionMemberName` remain exported
## and are what the typed views build on. Cached static-kind overloads
## (`structChild(j, kt)`, `structChild(name, kt)`, `unionMemberChild(j, kt)`)
## return a `Vector[kt]` directly, mirroring `bindAs` on a `ColumnView`.
## `Vector[kt].[]` does not exist for complex kinds — use the typed container
## views or the descent procs.

import std/[tables, math, times, strformat, macros, locks, options]
import nint128
import uuid4

import /[ffi, types, codec]
import /compatibility/decimal_compat
import /tools/wrench

# ---------------------------------------------------------------------------
# Cardinality — variant: known count or unknown. No sentinel magic.
# ---------------------------------------------------------------------------

type
  CardinalityKind* = enum ## Whether a scan knows its row count up front.
    ckKnown
    ckUnknown

  Cardinality* = object ## Row-count hint passed to DuckDB at bind time.
    case kind*: CardinalityKind
    of ckKnown:
      count*: int
      isExact*: bool
    of ckUnknown:
      discard

  FillFn* = proc(chunk: duckdb_data_chunk): int {.closure, gcsafe.} ## Writes
    ## rows into a DuckDB chunk and returns how many were written; 0 ends the
    ## scan.

  ProjectedFillFactory* = proc(projectedIds: seq[int]): FillFn {.closure, gcsafe.} ## Builds a filler for the requested source columns.

proc knownCardinality*(count: int, isExact = true): Cardinality {.inline.} =
  ## A `Cardinality` stating the scan yields exactly (or approximately, with
  ## `isExact = false`) `count` rows.
  Cardinality(kind: ckKnown, count: count, isExact: isExact)

proc unknownCardinality*(): Cardinality {.inline.} =
  ## A `Cardinality` stating the scan's row count is not known in advance.
  Cardinality(kind: ckUnknown)

type
  QResultType* = enum ## The two result storage strategies.
    Streaming = 0       ## Rows fetched lazily, chunk by chunk.
    Materialized = 1    ## All rows drained eagerly at execution time.

  Column* = object ## Schema metadata for one result column.
    idx*: int
    name*: string
    kind*: DuckType
    ltype*: LogicalType
    scale*: int8          ## valid iff kind == Decimal
    width*: int8          ## valid iff kind == Decimal
    enumWidth*: DuckType  ## valid iff kind == Enum

  ChunkMeta* = ref object ## Shared column metadata for every chunk of a result.
    columns*: seq[Column]
    nameIndex*: Table[string, int]

  # --- owning ref: ARC-managed via =destroy on the underlying object ---

  DataChunkObj = object of RootObj
    nonOwning: bool
    handle: duckdb_data_chunk
    meta: ChunkMeta
    size: int

  DataChunk* = ref DataChunkObj ## One DuckDB chunk: a fixed-size block of
                                ## columnar rows sharing `ChunkMeta`.

  # --- wrapper that gives =destroy/=/=wasMoved to raw duckdb_result ---

  DuckdbResultHandle* = object ## Owns a raw `duckdb_result`, freed on
                               ## destruction exactly once.
    raw*: duckdb_result

  # --- QResult variants ---

  QResult*[T: static QResultType] = object ## Query result. `Materialized`
    ## holds every chunk; `Streaming` fetches lazily via iteration.
    meta*: ChunkMeta
    when T == Streaming:
      handle*: DuckdbResultHandle
    when T == Materialized:
      chunks*: seq[DataChunk]
      rlen*: int               ## Total row count across `chunks`. Lives on the
                               ## QResult (not on ChunkMeta) because it is the
                               ## result's property and is mutated while the
                               ## immutable `columns`/`nameIndex` payload is
                               ## shared by reference with the source.
      rowsChanged*: int        ## Rows changed/affected by the statement, from
                               ## `duckdb_rows_changed`. 0 for SELECT.

  # --- views: non-owning, carry a DataChunk back-ref for ARC safety ---

  Vector*[kt: static DuckType] = object ## Typed, zero-copy column view into
    ## one chunk. `kt` is a static `DuckType`, so `[]`/`toSeq` dispatch at
    ## compile time and the buffer is never copied.
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

  ColumnView* = object ## Type-erased column view: introspect `kind` before
                       ## `bindAs`-ing to a typed `Vector[kt]`.
    kind*: DuckType
    vec: duckdb_vector
    ltype*: LogicalType
    data*: pointer
    length*: int
    validity*: ptr UncheckedArray[uint64]
    chunk: DataChunk
    scale*: int8
    width*: int8
    enumWidth*: DuckType

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

proc `=destroy`(d: DataChunkObj) =
  if d.handle != nil and not d.nonOwning:
    duckdb_destroy_data_chunk(d.handle.addr)
  `=destroy`(d.meta)

proc rawHandle*(d: DataChunk): duckdb_data_chunk {.inline.} =
  ## Underlying DuckDB chunk handle; FFI forwarding.
  d.handle

proc wrapDataChunk*(handle: duckdb_data_chunk, meta: ChunkMeta): DataChunk =
  ## Wraps a DuckDB-owned `handle` without taking ownership; the caller keeps
  ## responsibility for freeing the underlying chunk.
  DataChunk(
    nonOwning: true, handle: handle, meta: meta,
    size: duckdb_data_chunk_get_size(handle).int)

proc `=destroy`(h: var DuckdbResultHandle) =
  if h.raw.internal_data != nil:
    duckdb_destroy_result(h.raw.addr)

proc `=wasMoved`(h: var DuckdbResultHandle) =
  h.raw.internal_data = nil

proc takeHandle*(q: sink QResult[Streaming]): DuckdbResultHandle =
  ## Moves the underlying duckdb_result handle out of `q`, neutering `q`'s
  ## `=destroy` so the handle is freed exactly once (by the returned handle).
  result.raw = q.handle.raw
  q.handle.raw.internal_data = nil

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------
proc newChunkMeta*(columns: sink seq[Column]): ChunkMeta =
  ## Builds shared column metadata (and the name→index map) from `columns`.
  new(result)
  result.columns = columns
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
    result.columns[i] = Column(
      idx: i, name: name, kind: kind, ltype: ltype,
      scale: if kind == DuckType.Decimal:
               int8(duckdb_decimal_scale(lhandle))
             else: 0'i8,
      width: if kind == DuckType.Decimal:
               int8(duckdb_decimal_width(lhandle))
             else: 0'i8,
      enumWidth: if kind == DuckType.Enum:
               cast[DuckType](duckdb_enum_internal_type(lhandle))
             else: DuckType.Invalid)
    result.nameIndex[name] = i

proc newDataChunk*(
    handle: duckdb_data_chunk, meta: ChunkMeta
  ): DataChunk =
  ## Wraps a DuckDB-owned chunk handle, taking ownership; the chunk is freed
  ## when the returned `DataChunk` is destroyed.
  DataChunk(
    handle: handle, meta: meta,
    size: duckdb_data_chunk_get_size(handle).int)

proc newDataChunk*(columns: sink seq[Column]): DataChunk =
  ## Creates an empty DuckDB chunk with the schema described by `columns`.
  ## Raises `ValueError` for an empty schema.
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
  result.handle = duckdb_create_data_chunk(
    cast[ptr duckdb_logical_type](ltypes[0].addr), ncols.idx_t)
  result.size = 0

proc newColumn*(name: string, ltype: LogicalType, idx = 0): Column =
  ## A `Column` descriptor capturing the logical type, its decimal scale/width,
  ## and enum storage width.
  let kind = toDuckType(ltype)
  Column(
    idx: idx, name: name, kind: kind, ltype: ltype,
    scale: if kind == DuckType.Decimal:
             int8(duckdb_decimal_scale(ltype.handle))
           else: 0'i8,
    width: if kind == DuckType.Decimal:
             int8(duckdb_decimal_width(ltype.handle))
           else: 0'i8,
    enumWidth: if kind == DuckType.Enum:
             cast[DuckType](duckdb_enum_internal_type(ltype.handle))
           else: DuckType.Invalid)

proc drainInto(q: var QResult[Materialized], raw: duckdb_result) =
  ## Fetches and stores every chunk of `raw` into `q`. Does not destroy `raw`
  ## — the caller owns the handle and destroys it (a copy here would leave the
  ## caller's `internal_data` dangling).
  while true:
    let chunkH = duckdb_fetch_chunk(raw)
    if chunkH == nil: break
    let c = newDataChunk(chunkH, q.meta)
    q.chunks.add(c)
    q.rlen += duckdb_data_chunk_get_size(chunkH).int

proc newQResult*(_: typedesc[QResult[Materialized]], raw: duckdb_result): QResult[Materialized] =
  ## Drains `raw` into memory, builds the materialized result, and destroys
  ## the DuckDB result handle. Use `execute` / `executeMaterialized` instead.
  result.meta = newChunkMeta(raw)
  result.rowsChanged = duckdb_rows_changed(raw.addr).int
  drainInto(result, raw)
  duckdb_destroy_result(raw.addr)

proc newQResult*(_: typedesc[QResult[Streaming]], raw: duckdb_result): QResult[Streaming] =
  ## Wraps a streaming `raw` result; chunks are fetched lazily by `items`.
  ## Use `executeStreaming` instead of calling this directly.
  result.meta = newChunkMeta(raw)
  doAssert duckdb_result_is_streaming(raw) == true,
    "QResult[Streaming] requires a streaming result"
  result.handle = DuckdbResultHandle(raw: raw)

# ---------------------------------------------------------------------------
# Iterators
# ---------------------------------------------------------------------------

iterator items*(res: QResult[Streaming]): DataChunk =
  ## Fetches chunks lazily from the streaming result. The underlying
  ## `duckdb_result` is released exactly once by `=destroy` on `res.handle`
  ## when `res` goes out of scope — this iterator does not destroy the handle
  ## itself, so early `break` is safe and there is no double-free risk.
  while true:
    let raw = duckdb_fetch_chunk(res.handle.raw)
    if raw == nil: break
    yield newDataChunk(raw, res.meta)

iterator items*(res: QResult[Materialized]): DataChunk =
  ## Yields every chunk; safe to `break` early.
  for c in res.chunks:
    yield c

# ---------------------------------------------------------------------------
# DataChunk operations
# ---------------------------------------------------------------------------

proc len*(c: DataChunk): int {.inline.} =
  ## Number of rows currently in this chunk (the last chunk may be partial).
  c.size

proc setSize*(c: DataChunk, n: int) {.inline.} =
  ## Truncates or declares the chunk to hold `n` rows (used when writing).
  duckdb_data_chunk_set_size(c.handle, n.idx_t)
  c.size = n

proc columnCount*(c: DataChunk): int {.inline.} = c.meta.columns.len

proc makeColumnView(
    vec: duckdb_vector, ltype: LogicalType, chunk: DataChunk, length: int
): ColumnView {.inline.} =
  ## Build a ColumnView from a raw vector + a freshly-minted LogicalType.
  ## Used by child descent procs (structChild, listChild, etc.) where there
  ## is no precomputed Column to draw from — scale/width/enumWidth are
  ## derived via FFI because the LogicalType is fresh and un-cached.
  result.kind = toDuckType(ltype)
  result.vec = vec
  result.ltype = ltype
  result.data = duckdb_vector_get_data(vec)
  result.length = length
  result.validity = cast[ptr UncheckedArray[uint64]](duckdb_vector_get_validity(vec))
  result.chunk = chunk
  if result.kind == DuckType.Decimal:
    result.scale = int8(duckdb_decimal_scale(ltype.handle))
    result.width = int8(duckdb_decimal_width(ltype.handle))
  elif result.kind == DuckType.Enum:
    result.enumWidth = cast[DuckType](duckdb_enum_internal_type(ltype.handle))

proc newColumnView(c: DataChunk, i: int): ColumnView {.inline.} =
  ## Fix #2: Use cached Column fields (kind, scale, width, enumWidth)
  ## instead of re-deriving them via FFI on every chunk.vector(i) call.
  ## These are invariant for the life of the QResult.
  let vec = duckdb_data_chunk_get_vector(c.handle, i.idx_t)
  result.kind = c.meta.columns[i].kind
  result.vec = vec
  result.ltype = c.meta.columns[i].ltype
  result.data = duckdb_vector_get_data(vec)
  result.length = c.len
  result.validity = cast[ptr UncheckedArray[uint64]](duckdb_vector_get_validity(vec))
  result.chunk = c
  result.scale = c.meta.columns[i].scale
  result.width = c.meta.columns[i].width
  result.enumWidth = c.meta.columns[i].enumWidth

proc newBoundVector[kt: static DuckType](c: DataChunk, i: int): Vector[kt] {.inline.} =
  ## Build a typed vector directly from a chunk column. This is the fast path
  ## for `DataChunk.bindAs`; it avoids materializing an intermediate
  ## type-erased `ColumnView` after the runtime kind check has succeeded.
  # Profiling hot path: each call performs one vector lookup plus data and
  # validity lookups. Keep this constructor inline and bind once per chunk.
  let vec = duckdb_data_chunk_get_vector(c.handle, i.idx_t)
  result.vec = vec
  result.data = duckdb_vector_get_data(vec)
  result.length = c.len
  result.validity = cast[ptr UncheckedArray[uint64]](duckdb_vector_get_validity(vec))
  result.chunk = c
  when kt == DuckType.Decimal:
    result.scale = c.meta.columns[i].scale
    result.width = c.meta.columns[i].width
  elif kt == DuckType.Enum:
    result.enumWidth = c.meta.columns[i].enumWidth
  when kt in DuckComplexKind:
    result.ltype = c.meta.columns[i].ltype

proc vector*(c: DataChunk, i: int): ColumnView {.inline.} =
  ## The type-erased view of column `i`; raises `ValueError` out of range.
  if i < 0 or i >= c.meta.columns.len:
    raise newException(ValueError, "column index out of range: " & $i)
  newColumnView(c, i)

proc vector*(c: DataChunk, name: string): ColumnView {.inline.} =
  ## The type-erased view of the named column; raises `KeyError` if absent.
  let i = c.meta.nameIndex.getOrDefault(name, -1)
  if i < 0:
    raise newException(KeyError, "no such column: " & name)
  c.vector(i)

proc `[]`*(c: DataChunk, name: string): ColumnView {.inline.} =
  ## Shortcut for `vector(name)`.
  c.vector(name)

# ---------------------------------------------------------------------------
# QResult metadata
# ---------------------------------------------------------------------------

proc columnCount*(q: QResult): int {.inline.} =
  ## Number of columns in the result.
  q.meta.columns.len
proc column*(q: QResult, i: int): Column {.inline.} =
  ## Schema metadata for column `i`.
  q.meta.columns[i]
proc column*(q: QResult, name: string): Column {.inline.} =
  ## Schema metadata for the named column.
  q.meta.columns[q.meta.nameIndex[name]]

proc columnIndex*(q: QResult, name: string): int {.inline.} =
  ## Index of the named column.
  q.meta.nameIndex[name]

proc columnName*(q: QResult, i: int): string {.inline.} =
  ## Name of column `i`.
  q.meta.columns[i].name
proc columnKind*(q: QResult, i: int): DuckType {.inline.} =
  ## `DuckType` of column `i`.
  q.meta.columns[i].kind

proc columns*(q: QResult): seq[Column] =
  ## All column descriptors, in order.
  q.meta.columns

proc cardinality*(q: QResult[Materialized]): Cardinality =
  ## Exact row count as an exact `Cardinality`.
  knownCardinality(q.rlen, true)

proc cardinality*(q: QResult[Streaming]): Cardinality =
  ## Streaming results report an unknown `Cardinality`.
  unknownCardinality()

iterator columnItems*(q: QResult): Column =
  ## Yields each column descriptor in column order.
  for c in q.meta.columns:
    yield c

proc `$`*(c: Column): string =
  ## Formats a column descriptor, e.g. `Column(idx=0, name=id, kind=BigInt)`.
  fmt("Column(idx={c.idx}, name={c.name}, kind={c.kind})")

proc `$`*(q: QResult[Streaming]): string =
  ## Formats the result header, e.g. `QResult(streaming, cols=3)`.
  fmt("QResult(streaming, cols={q.meta.columns.len})")

# ---------------------------------------------------------------------------
# ColumnView / Vector[kt] — binding & validity
# ---------------------------------------------------------------------------

template validBit*(validity: ptr UncheckedArray[uint64], i: int): bool =
  ## Single source of truth for the DuckDB validity bit test.
  (validity[i shr 6] and (1'u64 shl (i and 63))) != 0

proc valid*(v: ColumnView, i: int): bool {.inline.} =
  ## Whether row `i` is non-NULL (true when the validity mask is absent).
  v.validity.isNil or validBit(v.validity, i)

template validAt*(v: untyped, i: untyped): bool =
  ## Checks validity without copying a Vector view.
  v.validity.isNil or validBit(v.validity, i)

proc valid*[kt: static DuckType](v: Vector[kt], i: int): bool {.inline.} =
  ## Whether row `i` is non-NULL.
  validAt(v, i)

proc setNullBit*(v: var ColumnView, i: int) {.inline.} =
  ## Marks row `i` as NULL, ensuring the validity mask is writable first.
  if v.validity.isNil:
    duckdb_vector_ensure_validity_writable(v.vec)
    v.validity = cast[ptr UncheckedArray[uint64]](duckdb_vector_get_validity(v.vec))
  duckdb_validity_set_row_invalid(cast[ptr uint64](v.validity), i.idx_t)

proc len*(v: ColumnView): int {.inline.} =
  ## Row count in this view.
  v.length
proc len*[kt: static DuckType](v: Vector[kt]): int {.inline.} =
  ## Row count in this view.
  v.length

proc bindAs*(cv: ColumnView, kt: static DuckType): Vector[kt] {.inline.} =
  ## Binds a type-erased `ColumnView` to a typed `Vector[kt]`. Raises
  ## `ValueError` if the column's runtime kind differs from `kt`.
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

proc bindAs*(c: DataChunk, i: int, kt: static DuckType): Vector[kt] {.inline.} =
  ## Binds column `i` of a chunk to a typed `Vector[kt]`; see `bindAs(ColumnView)`.
  if i < 0 or i >= c.meta.columns.len:
    raise newException(ValueError, "column index out of range: " & $i)
  if c.meta.columns[i].kind != kt:
    raise newException(
      ValueError,
      "Vector kind mismatch: column is " & $c.meta.columns[i].kind &
        ", requested " & $kt,
    )
  newBoundVector[kt](c, i)

proc bindAs*(c: DataChunk, name: string, kt: static DuckType): Vector[kt] {.inline.} =
  ## Binds the named column of a chunk to a typed `Vector[kt]`.
  let i = c.meta.nameIndex.getOrDefault(name, -1)
  if i < 0:
    raise newException(KeyError, "no such column: " & name)
  c.bindAs(i, kt)

# ---------------------------------------------------------------------------
# Raw-handle vector construction — for scalar UDF wrappers.
# The returned Vector carries NO DataChunk back-ref (chunk stays nil); it is
# safe only for the duration of the raw duckdb_vector's lifetime. No current
# Vector[kt] operation dereferences `chunk`, so this is sound for short-lived
# scalar-function input/output binding.
# ---------------------------------------------------------------------------

proc initVector*[kt: static DuckType](
    vec: duckdb_vector, length: int
  ): Vector[kt] {.inline.} =
  ## A typed `Vector[kt]` over a raw DuckDB vector; used by the scalar UDF
  ## wrappers. The view carries no chunk back-ref, so it is valid only for the
  ## lifetime of the raw vector's data (safe within a scalar call).
  result.data = duckdb_vector_get_data(vec)
  result.length = length
  result.validity = cast[ptr UncheckedArray[uint64]](duckdb_vector_get_validity(vec))
  result.vec = vec

proc vector*[kt: static DuckType](
    chunk: duckdb_data_chunk, i: int, length: int = VECTOR_SIZE
  ): Vector[kt] {.inline.} =
  ## A typed `Vector[kt]` over column `i` of a raw chunk, for FFI-side code.
  initVector[kt](duckdb_data_chunk_get_vector(chunk, i.idx_t), length)

# ---------------------------------------------------------------------------
# Per-kind Nim type mapping
# ---------------------------------------------------------------------------

template nimOf*(kt: static DuckType): typedesc =
  ## The Nim scalar type a `Vector[kt]` element reads/writes as, e.g.
  ## `nimOf(DuckType.BigInt) is int64`. Complex kinds map to `void`; use the
  ## typed container views from the `complex` module instead.
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

template valueTypeOf*(kt: static DuckType): typedesc =
  ## Public name for the decoded scalar type used by `Vector[kt]`.
  nimOf(kt)

template rawVectorTypeOf*(kt: static DuckType): typedesc =
  ## Raw DuckDB storage type used by the vector read/write paths.
  when kt == DuckType.Boolean:
    uint8
  elif kt in DuckPrimitiveKind:
    nimOf(kt)
  elif kt in DuckStringKind or kt in DuckBlobKind:
    duckdb_string_t
  elif kt in {DuckType.Timestamp, DuckType.TimestampS, DuckType.TimestampMs,
              DuckType.TimestampNs, DuckType.Time, DuckType.TimeTz,
              DuckType.TimestampTz}:
    int64
  elif kt == DuckType.Date:
    int32
  elif kt == DuckType.HugeInt or kt == DuckType.UUID:
    duckdb_hugeint
  elif kt == DuckType.UHugeInt:
    duckdb_uhugeint
  elif kt == DuckType.Interval:
    duckdb_interval
  elif kt == DuckType.TimeNs:
    int64
  else:
    void

template colDuckTypeOf*(T: typedesc): static DuckType =
  ## The inverse of `nimOf`: the `DuckType` a Nim element type logically maps
  ## to (`colDuckTypeOf(int) is DuckType.BigInt`). Raises a compile-time error
  ## for types with no unambiguous mapping (decimal, `ZonedTime`).
  when T is DecimalType:
    {.error: "Decimal columns need explicit width/scale; use newLogicalType(duckdb_create_decimal_type(w, s)) + ChunkBuilder".}
  elif T is ZonedTime:
    {.error: "ZonedTime is ambiguous (TimeTz vs TimestampTz); use an explicit LogicalType".}
  else:
    const mapped = toDuckType(T)
    when mapped == DuckType.Invalid:
      {.error: "colDuckTypeOf: unsupported element type".}
    elif mapped in DuckComplexKind:
      {.error: "colDuckTypeOf: complex columns need an explicit nested view".}
    else:
      mapped

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

proc decodeDuckString*(s: ptr duckdb_string_t): string {.inline.} =
  ## Decodes a DuckDB string slot, handling inline and external storage, into a
  ## Nim `string` (copies the bytes).
  let (src, ln) = rawStringView(s)
  if ln <= 0:
    return ""
  result = newString(ln)
  copyMem(addr result[0], src, ln)

proc decodeDuckBlob*(s: ptr duckdb_string_t): seq[byte] {.inline.} =
  ## Decodes a DuckDB blob slot into a Nim `seq[byte]` (copies the bytes).
  let (src, ln) = rawStringView(s)
  if ln <= 0:
    return @[]
  result = newSeq[byte](ln)
  copyMem(addr result[0], src, ln)

proc takeDuckVarchar*(s: cstring): string {.inline.} =
  ## Copies and releases a DuckDB-owned C string.
  result = $s
  duckdb_free(cast[pointer](s))

type
  DuckStringRef* = object ## Non-owning view of a VARCHAR/BLOB cell's buffer.
    ## `data` points into the DuckDB-managed vector and is only valid for the
    ## lifetime of the chunk.
    data: pointer
    length: int
    valid*: bool

proc len*(r: DuckStringRef): int {.inline.} =
  ## Bytes in the referenced buffer.
  r.length
proc data*(r: DuckStringRef): pointer {.inline.} =
  ## Pointer to the referenced buffer.
  r.data

proc isNull*(r: DuckStringRef): bool {.inline.} =
  ## Whether the referenced cell is NULL. Empty non-NULL values remain valid.
  not r.valid

proc toString*(r: DuckStringRef): string =
  ## Copies the referenced buffer into a Nim `string` (does allocate).
  if r.length <= 0:
    return ""
  result = newString(r.length)
  copyMem(addr result[0], r.data, r.length)

proc toBytes*(r: DuckStringRef): seq[byte] =
  ## Copies the referenced buffer into a Nim `seq[byte]` (does allocate).
  if r.length <= 0:
    return @[]
  result = newSeq[byte](r.length)
  copyMem(addr result[0], r.data, r.length)

proc borrow*(s: ptr duckdb_string_t): DuckStringRef {.inline.} =
  ## Zero-copy `DuckStringRef` over a raw DuckDB string slot; valid for the
  ## lifetime of the underlying chunk.
  let (src, ln) = rawStringView(s)
  result = DuckStringRef(data: src, length: ln, valid: true)

proc `==`*(a, b: DuckStringRef): bool {.inline.} =
  ## Length-aware byte equality without creating either payload as a string.
  if a.valid != b.valid or a.length != b.length:
    return false
  if not a.valid or a.length == 0:
    return true
  equalMem(a.data, b.data, a.length)

# ---------------------------------------------------------------------------
# Vector[kt] indexing — compile-time dispatch
# ---------------------------------------------------------------------------
#
# Zero-copy (no allocation, no copy) for primitive/temporal/hugeint/enum/interval
# kinds.  VARCHAR/BIT/BLOB and UUID return value types built by copying the
# cell's bytes.  DECIMAL goes through an intermediate string allocation — for
# hot decimal columns use `borrowDecimal` to read the raw `(Int128, width,
# scale)` triple without allocating.

proc readAt*[kt: static DuckType](v: ptr Vector[kt], i: int): nimOf(kt) {.inline.} =
  ## Element access: zero-copy for primitive/temporal/hugeint/enum/interval kinds
  ## (returns value types built from the raw buffer); VARCHAR/BIT/BLOB allocate
  ## and copy per row unless you use `borrow`. NULL rows yield
  ## `default(nimOf(kt))` / empty string / empty blob.
  doAssert i >= 0 and i < v[].length, "Vector index out of bounds: " & $i
  when kt in DuckStringKind or kt in DuckBlobKind:
    # DuckDB does not initialize the string_t cell of NULL rows; its length and
    # pointer fields are garbage. Dereferencing them wild-reads arbitrary
    # memory (crash under ASan). Read NULLs as empty values.
    if not validAt(v[], i):
      return default(nimOf(kt))
  when kt in DuckPrimitiveKind:
    cast[ptr UncheckedArray[nimOf(kt)]](v[].data)[i]
  elif kt == DuckType.Boolean:
    bool(cast[ptr UncheckedArray[uint8]](v[].data)[i])
  elif kt in DuckStringKind:
    decodeDuckString(addr cast[ptr UncheckedArray[duckdb_string_t]](v[].data)[i])
  elif kt in DuckBlobKind:
    decodeDuckBlob(addr cast[ptr UncheckedArray[duckdb_string_t]](v[].data)[i])
  elif kt == DuckType.Timestamp:
    fromTimestamp(cast[ptr UncheckedArray[int64]](v[].data)[i])
  elif kt == DuckType.TimestampS:
    fromDuckTimestampS(cast[ptr UncheckedArray[int64]](v[].data)[i])
  elif kt == DuckType.TimestampMs:
    fromDuckTimestampMs(cast[ptr UncheckedArray[int64]](v[].data)[i])
  elif kt == DuckType.TimestampNs:
    fromDuckTimestampNs(cast[ptr UncheckedArray[int64]](v[].data)[i])
  elif kt == DuckType.Date:
    fromDuckDate(cast[ptr UncheckedArray[int32]](v[].data)[i])
  elif kt == DuckType.Time:
    fromDuckTime(cast[ptr UncheckedArray[int64]](v[].data)[i])
  elif kt == DuckType.TimeTz:
    fromDuckTimeTz(cast[ptr UncheckedArray[int64]](v[].data)[i])
  elif kt == DuckType.TimestampTz:
    fromDuckTimestampTz(cast[ptr UncheckedArray[int64]](v[].data)[i])
  elif kt == DuckType.HugeInt:
    fromHugeInt(cast[ptr UncheckedArray[duckdb_hugeint]](v[].data)[i])
  elif kt == DuckType.UHugeInt:
    fromUHugeInt(cast[ptr UncheckedArray[duckdb_uhugeint]](v[].data)[i])
  elif kt == DuckType.UUID:
    fromDuckUuid(cast[ptr UncheckedArray[duckdb_hugeint]](v[].data)[i])
  elif kt == DuckType.Interval:
    fromInterval(cast[ptr UncheckedArray[duckdb_interval]](v[].data)[i])
  elif kt == DuckType.Decimal:
    fromDuckDecimal(v[].scale, v[].width, v[].data, i)
  elif kt == DuckType.Enum:
    fromDuckEnum(v[].data, i, v[].enumWidth)
  elif kt in DuckComplexKind:
    {.error: "Vector[" & $kt & "] does not support `[]`; use listChild/" &
            "structChild/mapEntriesChild/unionMemberChild descent procs".}

proc `[]`*[kt: static DuckType](v: Vector[kt], i: int): nimOf(kt) {.inline.} =
  ## Element access: zero-copy for primitive/temporal/hugeint/enum/interval kinds
  ## (returns value types constructed from the raw buffer); VARCHAR/BIT/BLOB
  ## allocate and copy per row unless `borrow` is used.
  readAt[kt](addr v, i)

# ---------------------------------------------------------------------------
# Vector[kt] `[]=` — compile-time dispatch, zero-copy for primitives
# ---------------------------------------------------------------------------

proc `[]=`*[kt: static DuckType](v: var Vector[kt], i: int, val: nimOf(kt)) {.inline.} =
  ## Element write: zero-copy for primitives, string/blob handled in-line by the
  ## vector, decimal/enum via the width-aware encoders. Complex kinds raise a
  ## compile-time error.
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
    # `huge.lower` is the low 64 bits of the (sign-extended) unscaled value;
    # the smaller column widths take their low bytes directly. Reinterpreting
    # the uint64 as int64 avoids a redundant copyMem per write.
    if v.width <= 4:
      cast[ptr UncheckedArray[int16]](v.data)[i] = int16(cast[int64](huge.lower))
    elif v.width <= 9:
      cast[ptr UncheckedArray[int32]](v.data)[i] = int32(cast[int64](huge.lower))
    elif v.width <= 18:
      cast[ptr UncheckedArray[int64]](v.data)[i] = cast[int64](huge.lower)
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

proc `[]=`*[kt: static DuckType](v: var Vector[kt], i: int, val: DuckStringRef) {.inline.} =
  ## Element write from a borrowed `DuckStringRef` (zero-copy for strings/blobs).
  doAssert i >= 0 and i < v.length, "Vector index out of bounds: " & $i
  when kt in DuckStringKind or kt in DuckBlobKind:
    duckdb_vector_assign_string_element_len(v.vec, i.idx_t,
      cast[cstring](val.data), val.length.idx_t)
  else:
    {.error: "DuckStringRef assignment only for string/blob kinds; got " & $kt.}

proc setNull*[kt: static DuckType](v: var Vector[kt], i: int) {.inline.} =
  ## Marks row `i` as NULL (for a vector being written to).
  doAssert i >= 0 and i < v.length, "Vector index out of bounds: " & $i
  if v.validity.isNil:
    duckdb_vector_ensure_validity_writable(v.vec)
    v.validity = cast[ptr UncheckedArray[uint64]](duckdb_vector_get_validity(v.vec))
  duckdb_validity_set_row_invalid(cast[ptr uint64](v.validity), i.idx_t)

proc setValid*[kt: static DuckType](v: var Vector[kt], i: int) {.inline.} =
  ## Marks row `i` as valid (non-NULL) for a vector being written to.
  doAssert i >= 0 and i < v.length, "Vector index out of bounds: " & $i
  if v.validity.isNil:
    duckdb_vector_ensure_validity_writable(v.vec)
    v.validity = cast[ptr UncheckedArray[uint64]](duckdb_vector_get_validity(v.vec))
  duckdb_validity_set_row_valid(cast[ptr uint64](v.validity), i.idx_t)

proc appendValues*[kt: static DuckType](
    v: var Vector[kt], values: openArray[nimOf(kt)], start = 0) =
  ## Bulk-writes `values` into the vector starting at row `start`; primitives
  ## use a single `copyMem`, others fall back to per-row `[]=`. Raises at
  ## compile time for complex kinds.
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
  elif kt in DuckComplexKind:
    {.error: "appendValues not supported for complex kinds; use child descent procs".}
  else:
    for i in 0 ..< values.len:
      v[start + i] = values[i]

# ---------------------------------------------------------------------------
# ChunkBuilder — column-oriented DataChunk construction
# ---------------------------------------------------------------------------

type
  ChunkBuilder* = object ## Column-oriented builder for a `DataChunk`: append
    ## values per column, then `finish` to produce the chunk. All columns must
    ## end up with the same row count.
    chunk: DataChunk
    colRows: seq[int]
    vectors: seq[ColumnView] ## Pre-built ColumnView per column, avoiding
                             ## per-append FFI calls to get_vector/get_data.
    capacity: int

## ChunkBuilder is move-only.
## ChunkBuilder is move-only.
proc `=copy`*(dest: var ChunkBuilder, src: ChunkBuilder) {.error.}
## ChunkBuilder is move-only.
proc `=dup`*(src: ChunkBuilder): ChunkBuilder {.error.}

proc newChunkBuilder*(columns: sink seq[Column]): ChunkBuilder =
  ## A builder over a new empty chunk with the given schema.
  result.chunk = newDataChunk(columns)
  result.colRows = newSeq[int](columns.len)
  result.capacity = VECTOR_SIZE
  result.chunk.setSize(VECTOR_SIZE)
  result.vectors = newSeq[ColumnView](columns.len)
  for i in 0 ..< columns.len:
    result.vectors[i] = result.chunk.vector(i)

proc newChunkBuilder*(chunk: sink DataChunk): ChunkBuilder =
  ## A builder over an existing chunk (e.g. from an appender's `newDataChunk`).
  result.chunk = chunk
  result.colRows = newSeq[int](chunk.columnCount)
  result.capacity = VECTOR_SIZE
  result.chunk.setSize(VECTOR_SIZE)
  result.vectors = newSeq[ColumnView](chunk.columnCount)
  for i in 0 ..< chunk.columnCount:
    result.vectors[i] = result.chunk.vector(i)

proc len*(b: ChunkBuilder): int {.inline.} =
  ## Rows appended so far in column 0 (the reference column).
  if b.colRows.len > 0: b.colRows[0] else: 0

proc rowsAppended*(b: ChunkBuilder, col: int): int {.inline.} =
  ## Rows appended so far in column `col`. Named `rowsAppended`, not
  ## `appendedRows`: a name too close to query.`appendRows` makes Nim's
  ## style-insensitive lookup drop one of the two symbols.
  doAssert col in 0 ..< b.colRows.len, "column out of range"
  b.colRows[col]

proc columnCount*(b: ChunkBuilder): int {.inline.} =
  ## Number of columns being built.
  b.colRows.len

proc append*[kt: static DuckType](
    b: var ChunkBuilder, col: int, val: sink nimOf(kt)) =
  ## Appends one value to column `col`; raises `AssertionDefect` if full.
  doAssert col in 0 ..< b.colRows.len, "column out of range"
  doAssert b.colRows[col] < b.capacity, "chunk capacity exceeded"
  let row = b.colRows[col]
  let cv = addr b.vectors[col]
  when kt in DuckPrimitiveKind:
    cast[ptr UncheckedArray[nimOf(kt)]](cv[].data)[row] = val
  elif kt == DuckType.Boolean:
    cast[ptr UncheckedArray[uint8]](cv[].data)[row] = uint8(val)
  elif kt in DuckStringKind or kt in DuckBlobKind:
    duckdb_vector_assign_string_element_len(
      cv[].vec, row.idx_t, val.cstring, val.len.idx_t)
  else:
    var w = cv[].bindAs(kt)
    w[row] = val
  inc b.colRows[col]

proc appendNull*[kt: static DuckType](
    b: var ChunkBuilder, col: int) =
  ## Appends a NULL to column `col`.
  doAssert col in 0 ..< b.colRows.len, "column out of range"
  doAssert b.colRows[col] < b.capacity, "chunk capacity exceeded"
  let row = b.colRows[col]
  b.vectors[col].setNullBit(row)
  inc b.colRows[col]

proc appendValues*[kt: static DuckType](
    b: var ChunkBuilder, col: int,
    values: openArray[nimOf(kt)]) =
  ## Bulk-appends `values` to column `col` (single `copyMem` for primitives).
  doAssert col in 0 ..< b.colRows.len, "column out of range"
  doAssert b.colRows[col] + values.len <= b.capacity, "chunk capacity exceeded"
  var w = b.vectors[col].bindAs(kt)
  w.appendValues(values, start = b.colRows[col])
  b.colRows[col] += values.len

proc appendNulls*[kt: static DuckType](
    b: var ChunkBuilder, col: int, n: int) =
  ## Appends `n` NULLs to column `col`.
  for _ in 0 ..< n: appendNull[kt](b, col)

proc finish*(b: var ChunkBuilder): DataChunk =
  ## Finalizes and returns the built chunk (size set to the appended row count).
  ## Raises `ValueError` if the columns disagree on row count. The builder is
  ## consumed (movable) and cannot be reused.
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
  ## A one-column chunk from a `seq` of values (type inferred).
  result = newDataChunk(@[newColumn(name, newLogicalType(colDuckTypeOf(T)))])
  result.setSize(values.len)
  if values.len > 0:
    var w = result.bindAs(0, colDuckTypeOf(T))
    w.appendValues(values)

## Builds a chunk from `(name, seq)` pairs — `newChunk(("a", @[1,2]), ("b", @[3,4]))`.
## All columns must have equal length; incompatible types raise at compile time.
macro newChunk*(pairs: varargs[typed]): untyped =
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
    let kt = duckTypeDotExpr(elemType)
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

proc borrowAt*[kt: static DuckType](v: ptr Vector[kt], i: int): DuckStringRef {.inline.} =
  ## Creates a borrowed string/blob view without copying a Vector.
  when kt in DuckStringKind or kt in DuckBlobKind:
    if not validAt(v[], i):
      return DuckStringRef(data: nil, length: 0)
    borrow(addr cast[ptr UncheckedArray[duckdb_string_t]](v[].data)[i])
  else:
    {.error: "borrow() only defined for string/blob kinds; got " & $kt.}

proc borrow*[kt: static DuckType](v: Vector[kt], i: int): DuckStringRef {.inline.} =
  ## Zero-copy view of a VARCHAR/BIT/BLOB cell; see `DuckStringRef`.
  borrowAt[kt](addr v, i)

iterator borrowItems*[kt: static DuckType](v: Vector[kt]): DuckStringRef =
  ## Zero-copy bulk iteration for VARCHAR/BIT/BLOB columns.  Yields a
  ## `DuckStringRef` view into each row's buffer (no per-row `string`/seq
  ## allocation).  NULL rows yield an empty (nil data, length 0) ref.
  when kt in DuckStringKind or kt in DuckBlobKind:
    for i in 0 ..< v.length:
      if v.valid(i):
        yield borrow(addr cast[ptr UncheckedArray[duckdb_string_t]](v.data)[i])
      else:
        yield DuckStringRef(data: nil, length: 0, valid: false)
  else:
    {.error: "borrowItems() only defined for string/blob kinds; got " & $kt.}

proc borrowDecimal*(v: Vector[DuckType.Decimal], i: int): (Int128, int8, int8) {.inline.} =
  ## Non-allocating raw view of a DECIMAL cell. Returns `(rawValue, width, scale)`
  ## where `rawValue` is the sign-extended Int128. Callers can format or construct
  ## `DecimalType` only when needed, avoiding the per-row string allocation of `[]`.
  var val: Int128
  if v.width <= 4:
    val = i128(cast[ptr UncheckedArray[int16]](v.data)[i])
  elif v.width <= 9:
    val = i128(cast[ptr UncheckedArray[int32]](v.data)[i])
  elif v.width <= 18:
    val = i128(cast[ptr UncheckedArray[int64]](v.data)[i])
  else:
    val = fromHugeInt(cast[ptr UncheckedArray[duckdb_hugeint]](v.data)[i])
  (val, v.width, v.scale)

proc setDecimalRaw*(v: var Vector[DuckType.Decimal], i: int,
                     raw: Int128) {.inline.} =
  ## Writes an already-unscaled DECIMAL value without stringify-and-parse.
  doAssert i >= 0 and i < v.length, "Vector index out of bounds: " & $i
  if v.width <= 4:
    cast[ptr UncheckedArray[int16]](v.data)[i] =
      int16(cast[int64](raw.lo))
  elif v.width <= 9:
    cast[ptr UncheckedArray[int32]](v.data)[i] =
      int32(cast[int64](raw.lo))
  elif v.width <= 18:
    cast[ptr UncheckedArray[int64]](v.data)[i] = cast[int64](raw.lo)
  else:
    cast[ptr UncheckedArray[duckdb_hugeint]](v.data)[i] = toHugeInt(raw)

proc borrowUuid*(v: Vector[DuckType.UUID], i: int): Int128 {.inline.} =
  ## Non-allocating raw view of a UUID cell. Returns the 128-bit value as Int128.
  ## Callers can convert to `Uuid` via `fromDuckUuid` only when needed.
  fromHugeInt(cast[ptr UncheckedArray[duckdb_hugeint]](v.data)[i])

# ---------------------------------------------------------------------------
# Zero-copy descent procs — complex child kinds
#
# .. note:: Each descent proc (listChild, structChild, arrayChild,
#   mapEntriesChild, unionMemberChild) mints a fresh `LogicalType` via FFI
#   on every call.  Call them **once per chunk-vector** (not per row) to
#   obtain the child `ColumnView`, then index that view by row.
# ---------------------------------------------------------------------------

proc listChild*(v: Vector[DuckType.List]): ColumnView {.inline.} =
  ## The child vector of a LIST column (all rows' elements concatenated).
  let childVec = duckdb_list_vector_get_child(v.vec)
  let childLtype =
    if v.ltype.childTypes != nil: v.ltype.childTypes[][0]
    else: newLogicalType(duckdb_list_type_child_type(v.ltype.handle))
  makeColumnView(childVec, childLtype, v.chunk,
    duckdb_list_vector_get_size(v.vec).int)

proc listEntry*(v: Vector[DuckType.List], i: int): (uint64, uint64) {.inline.} =
  ## The `(offset, length)` slice of `listChild` that belongs to row `i`.
  let entry = cast[ptr UncheckedArray[duckdb_list_entry]](v.data)[i]
  (entry.offset, entry.length)

proc arrayChild*(v: Vector[DuckType.Array]): ColumnView {.inline.} =
  ## The flattened child vector of an ARRAY column (all rows' elements stacked).
  let childVec = duckdb_array_vector_get_child(v.vec)
  let childLtype =
    if v.ltype.childTypes != nil: v.ltype.childTypes[][0]
    else: newLogicalType(duckdb_array_type_child_type(v.ltype.handle))
  let arraySize = duckdb_array_type_array_size(v.ltype.handle).int
  makeColumnView(childVec, childLtype, v.chunk, v.length * arraySize)

proc arraySize*(v: Vector[DuckType.Array]): int {.inline.} =
  ## The fixed element count of each row's array.
  duckdb_array_type_array_size(v.ltype.handle).int

proc structChildCount*(v: Vector[DuckType.Struct]): int {.inline.} =
  ## Number of children in a STRUCT column type.
  duckdb_struct_type_child_count(v.ltype.handle).int

proc structChildName*(v: Vector[DuckType.Struct], j: int): lent string =
  ## Returns the j-th struct child's name (borrowed, no copy). Names are
  ## populated eagerly at `LogicalType` construction (single-threaded), so
  ## this is a plain read — no FFI, no allocation, no lazy mutation of shared
  ## state.
  v.ltype.childNames[j]

proc structChild*(v: Vector[DuckType.Struct], j: int): ColumnView {.inline.} =
  ## The child vector for struct field `j`.
  let childVec = duckdb_struct_vector_get_child(v.vec, j.idx_t)
  let childLtype =
    if v.ltype.childTypes != nil: v.ltype.childTypes[][j]
    else: newLogicalType(duckdb_struct_type_child_type(v.ltype.handle, j.idx_t))
  makeColumnView(childVec, childLtype, v.chunk, v.length)

proc structChild*(v: Vector[DuckType.Struct], name: string): ColumnView {.inline.} =
  ## The child vector for struct field `name`; raises `KeyError` if absent.
  for j in 0 ..< v.structChildCount:
    if v.structChildName(j) == name:
      return v.structChild(j)
  raise newException(KeyError, "struct has no child named: " & name)

proc mapKeyType*(v: Vector[DuckType.Map]): LogicalType {.inline.} =
  ## The key column type of a MAP column type.
  if v.ltype.childTypes != nil: v.ltype.childTypes[][0]
  else: newLogicalType(duckdb_map_type_key_type(v.ltype.handle))

proc mapValueType*(v: Vector[DuckType.Map]): LogicalType {.inline.} =
  ## The value column type of a MAP column type.
  if v.ltype.childTypes != nil: v.ltype.childTypes[][1]
  else: newLogicalType(duckdb_map_type_value_type(v.ltype.handle))

proc mapEntriesChild*(v: Vector[DuckType.Map]): ColumnView {.inline.} =
  ## The flattened (key, value) struct vector of a MAP column.
  let entriesVec = duckdb_list_vector_get_child(v.vec)
  let entryLtype =
    if v.ltype.entryType != nil: v.ltype.entryType
    else: newLogicalType(duckdb_list_type_child_type(v.ltype.handle))
  makeColumnView(entriesVec, entryLtype, v.chunk,
    duckdb_list_vector_get_size(v.vec).int)

proc unionMemberCount*(v: Vector[DuckType.Union]): int {.inline.} =
  ## Number of members in a UNION column type.
  duckdb_union_type_member_count(v.ltype.handle).int

proc unionMemberName*(v: Vector[DuckType.Union], j: int): lent string =
  ## Returns the j-th union member's name (borrowed, no copy). Names are
  ## populated eagerly at `LogicalType` construction (single-threaded), so
  ## this is a plain read — no FFI, no allocation, no lazy mutation of shared
  ## state.
  v.ltype.childNames[j]

proc unionMemberChild*(v: Vector[DuckType.Union], j: int): ColumnView {.inline.} =
  ## The child vector for union member `j`.
  let memberType =
    if v.ltype.childTypes != nil: v.ltype.childTypes[][j]
    else: newLogicalType(duckdb_union_type_member_type(v.ltype.handle, j.idx_t))
  let memberVec = duckdb_struct_vector_get_child(v.vec, (j + 1).idx_t)
  makeColumnView(memberVec, memberType, v.chunk, v.length)

proc unionTag*(v: Vector[DuckType.Union], i: int): int {.inline.} =
  ## The tag of the active union member for row `i` (index into the member
  ## list), or `-1` for NULL.
  let tagVec = duckdb_struct_vector_get_child(v.vec, 0)
  let tagData = duckdb_vector_get_data(tagVec)
  let tagValidity = cast[ptr UncheckedArray[uint64]](duckdb_vector_get_validity(tagVec))
  if tagValidity != nil and
      (tagValidity[i shr 6] and (1'u64 shl (i and 63))) == 0:
    return -1
  cast[ptr UncheckedArray[uint8]](tagData)[i].int

proc unionTagView*(
    v: Vector[DuckType.Union]
): tuple[data: ptr UncheckedArray[uint8], validity: ptr UncheckedArray[uint64]] {.inline.} =
  ## One-shot view of the tag child vector for bulk per-row tag reads.
  ## Read the tag for row `i` with the same validity bit-test as `unionTag`:
  ## a NULL tag (or `-1`) means the union member is NULL.
  let tagVec = duckdb_struct_vector_get_child(v.vec, 0)
  (cast[ptr UncheckedArray[uint8]](duckdb_vector_get_data(tagVec)),
   cast[ptr UncheckedArray[uint64]](duckdb_vector_get_validity(tagVec)))

proc mapEntry*(v: Vector[DuckType.Map], i: int): (uint64, uint64) {.inline.} =
  ## The (key,value) list entry slice for MAP row `i` as `{offset, length)`.
  let entry = cast[ptr UncheckedArray[duckdb_list_entry]](v.data)[i]
  (entry.offset, entry.length)

# ---------------------------------------------------------------------------
# Cached static-kind descent overloads (mirror `bindAs` on a ColumnView)
# ---------------------------------------------------------------------------

proc structChild*(v: Vector[DuckType.Struct], j: int,
                  kt: static DuckType): Vector[kt] {.inline.} =
  ## Typed child view for struct field `j` (`kts` mirrors `bindAs`).
  v.structChild(j).bindAs(kt)

proc structChild*(v: Vector[DuckType.Struct], name: string,
                  kt: static DuckType): Vector[kt] {.inline.} =
  ## Typed child view for struct field `name`; raises `KeyError` if absent.
  v.structChild(name).bindAs(kt)

proc unionMemberChild*(v: Vector[DuckType.Union], j: int,
                        kt: static DuckType): Vector[kt] {.inline.} =
  ## Typed child view for union member `j` (`kts` mirrors `bindAs`).
  v.unionMemberChild(j).bindAs(kt)

# ---------------------------------------------------------------------------
# Bound container views — Map / List / Array
#
# Each typed view caches the bound child vectors once (zero-copy: buffer
# pointers + chunk back-ref), so caller code no longer chains
# `mapEntriesChild` / `structChild(0)` / `structChild(1)` per call. Row
# access (`mv[i]`, `lv[i]`, `av[i]`) allocates a Nim container per row. The
# `borrowMap(i)` / `borrowList(i)` / `borrowArray(i)` variants return a
# zero-copy `MapRowView` / `SliceView` that reads straight out of the DuckDB
# buffer with no per-row allocation.
# ---------------------------------------------------------------------------

type
  SliceView*[kt: static DuckType] = object ## Zero-copy window over a slice
    ## of a child vector; valid while the parent view remains alive.
    vec: ptr Vector[kt]
    offset*: int
    length*: int

  MapRowView*[ktKey, ktVal: static DuckType] = object ## Zero-copy row view of
    ## a MAP cell: keys/values read straight out of the DuckDB buffers.
    keys: Vector[ktKey]
    vals: Vector[ktVal]
    offset*: int
    length*: int

  MapView*[ktKey, ktVal: static DuckType] = object ## Typed view of a MAP
    ## column; `mv[i]` yields a Nim table, `borrowMap(i)` a zero-copy
    ## `MapRowView`.
    parent: Vector[DuckType.Map]
    keys: Vector[ktKey]
    vals: Vector[ktVal]
    length*: int

  ListView*[kt: static DuckType] = object ## Typed view of a LIST column.
    parent: Vector[DuckType.List]
    child: Vector[kt]
    length*: int

  ArrayView*[kt: static DuckType] = object ## Typed view of an ARRAY column.
    parent: Vector[DuckType.Array]
    child: Vector[kt]
    length*: int
    arraySize*: int

proc len*(mv: MapView): int {.inline.} =
  ## Row count of the view.
  mv.length
proc len*(lv: ListView): int {.inline.} =
  ## Row count of the view.
  lv.length
proc len*(av: ArrayView): int {.inline.} =
  ## Row count of the view.
  av.length
proc len*(sv: SliceView): int {.inline.} =
  ## Number of elements in the slice.
  sv.length
proc len*[ktKey, ktVal: static DuckType](rv: MapRowView[ktKey, ktVal]): int {.inline.} =
  ## Number of key/value pairs in the row.
  rv.length

proc valid*[ktKey, ktVal: static DuckType](
    mv: MapView[ktKey, ktVal], i: int): bool {.inline.} =
  ## Whether MAP row `i` is non-NULL.
  mv.parent.valid(i)

proc valid*(lv: ListView, i: int): bool {.inline.} =
  ## Whether LIST row `i` is non-NULL.
  lv.parent.valid(i)
proc valid*(av: ArrayView, i: int): bool {.inline.} =
  ## Whether ARRAY row `i` is non-NULL.
  av.parent.valid(i)

# ---------------------------------------------------------------------------
# SliceView — `[offset, offset+length)` window over a bound `Vector[kt]`
# ---------------------------------------------------------------------------

proc `[]`*[kt: static DuckType](sv: SliceView[kt], j: int): nimOf(kt) {.inline.} =
  ## Element `j` of the slice with the containing vector's `[]` semantics.
  doAssert j >= 0 and j < sv.length, "SliceView index out of bounds: " & $j
  readAt[kt](sv.vec, sv.offset + j)

proc valid*[kt: static DuckType](sv: SliceView[kt], j: int): bool {.inline.} =
  ## Whether slice element `j` is non-NULL.
  validAt(sv.vec[], sv.offset + j)

iterator items*[kt: static DuckType](sv: SliceView[kt]): nimOf(kt) =
  ## Iterates slice elements; NULLs yield `default(nimOf(kt))`.
  let off = sv.offset
  let n = sv.length
  for j in 0 ..< n:
    if sv.vec[].validity.isNil or validAt(sv.vec[], off + j):
      yield readAt[kt](sv.vec, off + j)
    else:
      yield default(nimOf(kt))

iterator borrowItems*[kt: static DuckType](sv: SliceView[kt]): DuckStringRef =
  ## Zero-copy iteration over slice elements for string/blob kinds; NULLs yield
  ## an empty `DuckStringRef`.
  when kt in DuckStringKind or kt in DuckBlobKind:
    let off = sv.offset
    let n = sv.length
    for j in 0 ..< n:
      if sv.vec[].validity.isNil or validAt(sv.vec[], off + j):
        yield borrow(addr cast[ptr UncheckedArray[duckdb_string_t]](sv.vec[].data)[off + j])
      else:
        yield DuckStringRef(data: nil, length: 0)
  else:
    {.error: "borrowItems() only defined for string/blob kinds; got " & $kt.}

proc toSeqInto*[kt: static DuckType](
    sv: SliceView[kt], dest: var seq[nimOf(kt)]) =
  ## Reuses `dest` storage to materialize the slice; NULLs become defaults.
  dest.setLen(sv.length)
  let off = sv.offset
  when kt in DuckPrimitiveKind:
    if sv.vec[].validity.isNil and sv.length > 0:
      copyMem(addr dest[0],
        cast[ptr UncheckedArray[nimOf(kt)]](sv.vec[].data)[off].addr,
        sv.length * sizeof(nimOf(kt)))
      return
  elif kt == DuckType.Boolean:
    if sv.vec[].validity.isNil and sv.length > 0:
      copyMem(addr dest[0],
        cast[ptr UncheckedArray[uint8]](sv.vec[].data)[off].addr,
        sv.length)
      return
  for j in 0 ..< sv.length:
    if sv.vec[].validity.isNil or validAt(sv.vec[], off + j):
      dest[j] = readAt[kt](sv.vec, off + j)
    else:
      dest[j] = default(nimOf(kt))

proc toSeq*[kt: static DuckType](sv: SliceView[kt]): seq[nimOf(kt)] =
  ## Materializes the slice; NULLs become `default(nimOf(kt))`.
  result = newSeq[nimOf(kt)](sv.length)
  sv.toSeqInto(result)

# ---------------------------------------------------------------------------
# MapView / MapRowView — typed MAP column view + zero-copy row slice
# ---------------------------------------------------------------------------

proc initMapView*[ktKey, ktVal: static DuckType](
    cv: ColumnView
  ): MapView[ktKey, ktVal] {.inline.} =
  ## Binds a MAP column `ColumnView` to a typed `MapView`; raises `ValueError`
  ## if the column is not a MAP. Zero-copy: caches the key/value child vectors.
  if cv.kind != DuckType.Map:
    raise newException(ValueError,
      "bindAs(Table/OrderedTable[K,V]) requires a Map column; got " & $cv.kind)
  let vm = cv.bindAs(DuckType.Map)
  let entryStruct = vm.mapEntriesChild.bindAs(DuckType.Struct)
  result.parent = vm
  result.keys = entryStruct.structChild(0).bindAs(ktKey)
  result.vals = entryStruct.structChild(1).bindAs(ktVal)
  result.length = cv.length

proc initMapViewFromVector*[ktKey, ktVal: static DuckType](
    v: Vector[DuckType.Map]
  ): MapView[ktKey, ktVal] {.inline.} =
  ## Build a `MapView` directly from an already-bound `Vector[DuckType.Map]`.
  ## Used by `complex.toMap` to delegate without going back through a
  ## `ColumnView`. Sibling to `initMapView` (which takes a `ColumnView`).
  let entryStruct = v.mapEntriesChild.bindAs(DuckType.Struct)
  result.parent = v
  result.keys = entryStruct.structChild(0).bindAs(ktKey)
  result.vals = entryStruct.structChild(1).bindAs(ktVal)
  result.length = v.length

proc bindAs*[K, V](cv: ColumnView, _: typedesc[Table[K, V]]):
    MapView[colDuckTypeOf(K), colDuckTypeOf(V)] {.inline.} =
  ## Binds a MAP column as a `MapView[K, V]` — `mv[i]` gives a Nim `Table`.
  initMapView[colDuckTypeOf(K), colDuckTypeOf(V)](cv)

proc bindAs*[K, V](cv: ColumnView, _: typedesc[OrderedTable[K, V]]):
    MapView[colDuckTypeOf(K), colDuckTypeOf(V)] {.inline.} =
  ## Binds a MAP column as a `MapView[K, V]` — `mv[i]` gives an `OrderedTable`.
  initMapView[colDuckTypeOf(K), colDuckTypeOf(V)](cv)

proc bindAs*[K, V](c: DataChunk, i: int, T: typedesc[Table[K, V]]):
    MapView[colDuckTypeOf(K), colDuckTypeOf(V)] {.inline.} =
  ## Convenience for `c.vector(i).bindAs(Table[K, V])`.
  c.vector(i).bindAs(T)

proc bindAs*[K, V](c: DataChunk, i: int, T: typedesc[OrderedTable[K, V]]):
    MapView[colDuckTypeOf(K), colDuckTypeOf(V)] {.inline.} =
  ## Convenience for `c.vector(i).bindAs(OrderedTable[K, V])`.
  c.vector(i).bindAs(T)

iterator pairs*[ktKey, ktVal: static DuckType](
    rv: MapRowView[ktKey, ktVal]): (nimOf(ktKey), nimOf(ktVal)) =
  ## Yields each (key, value) pair of a MAP row; NULLs become defaults.
  let off = rv.offset
  let n = rv.length
  for j in 0 ..< n:
    let idx = off + j
    let k = if rv.keys.validity.isNil or rv.keys.valid(idx):
              rv.keys[idx] else: default(nimOf(ktKey))
    let v = if rv.vals.validity.isNil or rv.vals.valid(idx):
              rv.vals[idx] else: default(nimOf(ktVal))
    yield (k, v)

iterator borrowPairs*[ktKey, ktVal: static DuckType](
    rv: MapRowView[ktKey, ktVal]): (DuckStringRef, DuckStringRef) =
  ## Yields borrowed string/blob pairs without materializing payloads.
  when (ktKey in DuckStringKind or ktKey in DuckBlobKind) and
       (ktVal in DuckStringKind or ktVal in DuckBlobKind):
    let off = rv.offset
    for j in 0 ..< rv.length:
      let idx = off + j
      yield (rv.keys.borrow(idx), rv.vals.borrow(idx))
  else:
    {.error: "borrowPairs() requires string/blob key and value kinds".}

iterator borrowKeys*[ktKey, ktVal: static DuckType](
    rv: MapRowView[ktKey, ktVal]): DuckStringRef =
  ## Yields borrowed string/blob keys without materializing payloads.
  when ktKey in DuckStringKind or ktKey in DuckBlobKind:
    let off = rv.offset
    for j in 0 ..< rv.length:
      yield rv.keys.borrow(off + j)
  else:
    {.error: "borrowKeys() requires a string/blob key kind".}

iterator borrowValues*[ktKey, ktVal: static DuckType](
    rv: MapRowView[ktKey, ktVal]): DuckStringRef =
  ## Yields borrowed string/blob values without materializing payloads.
  when ktVal in DuckStringKind or ktVal in DuckBlobKind:
    let off = rv.offset
    for j in 0 ..< rv.length:
      yield rv.vals.borrow(off + j)
  else:
    {.error: "borrowValues() requires a string/blob value kind".}

proc borrowedMapKeyMatches[ktKey: static DuckType](
    candidate: DuckStringRef, key: nimOf(ktKey)): bool {.inline.} =
  ## Compares a borrowed MAP key with an owned Nim key without decoding the
  ## DuckDB candidate into a temporary string/blob.
  when ktKey in DuckStringKind or ktKey in DuckBlobKind:
    if not candidate.valid or candidate.length != key.len:
      return false
    if key.len == 0:
      return true
    when ktKey in DuckStringKind:
      equalMem(candidate.data, cast[pointer](key.cstring), key.len)
    else:
      equalMem(candidate.data, key[0].unsafeAddr, key.len)
  else:
    false

proc borrowLookup*[ktKey, ktVal: static DuckType](
    rv: MapRowView[ktKey, ktVal], key: DuckStringRef):
    tuple[value: DuckStringRef, found: bool] {.inline.} =
  ## Looks up a string/blob key without allocating a candidate key string.
  when (ktKey in DuckStringKind or ktKey in DuckBlobKind) and
       (ktVal in DuckStringKind or ktVal in DuckBlobKind):
    if not key.valid:
      return (DuckStringRef(data: nil, length: 0, valid: false), false)
    for candidateKey, candidateValue in rv.borrowPairs:
      if candidateKey.valid and candidateKey == key:
        return (candidateValue, true)
    return (DuckStringRef(data: nil, length: 0, valid: false), false)
  else:
    {.error: "borrowLookup() requires string/blob key and value kinds".}

iterator keys*[ktKey, ktVal: static DuckType](
    rv: MapRowView[ktKey, ktVal]): nimOf(ktKey) =
  ## Yields the keys of a MAP row; NULL keys yield `default(nimOf(ktKey))`.
  let off = rv.offset
  let n = rv.length
  for j in 0 ..< n:
    let idx = off + j
    if rv.keys.validity.isNil or rv.keys.valid(idx):
      yield rv.keys[idx]
    else:
      yield default(nimOf(ktKey))

iterator values*[ktKey, ktVal: static DuckType](
    rv: MapRowView[ktKey, ktVal]): nimOf(ktVal) =
  ## Yields the values of a MAP row; NULL values yield `default(nimOf(ktVal))`.
  let off = rv.offset
  let n = rv.length
  for j in 0 ..< n:
    let idx = off + j
    if rv.vals.validity.isNil or rv.vals.valid(idx):
      yield rv.vals[idx]
    else:
      yield default(nimOf(ktVal))

proc contains*[ktKey, ktVal: static DuckType](
    rv: MapRowView[ktKey, ktVal], key: nimOf(ktKey)): bool {.inline.} =
  ## Whether the MAP row contains `key`.
  let off = rv.offset
  let n = rv.length
  when ktKey in DuckStringKind or ktKey in DuckBlobKind:
    for j in 0 ..< n:
      if borrowedMapKeyMatches[ktKey](rv.keys.borrow(off + j), key):
        return true
  else:
    for j in 0 ..< n:
      let idx = off + j
      if (rv.keys.validity.isNil or rv.keys.valid(idx)) and rv.keys[idx] == key:
        return true

proc `[]`*[ktKey, ktVal: static DuckType](
    rv: MapRowView[ktKey, ktVal], key: nimOf(ktKey)): nimOf(ktVal) {.inline.} =
  ## Value for `key` in the MAP row; raises `KeyError` if the key is absent.
  let off = rv.offset
  let n = rv.length
  when ktKey in DuckStringKind or ktKey in DuckBlobKind:
    for j in 0 ..< n:
      let idx = off + j
      if borrowedMapKeyMatches[ktKey](rv.keys.borrow(idx), key):
        if rv.vals.validity.isNil or rv.vals.valid(idx):
          return rv.vals[idx]
        return default(nimOf(ktVal))
  else:
    for j in 0 ..< n:
      let idx = off + j
      if (rv.keys.validity.isNil or rv.keys.valid(idx)) and rv.keys[idx] == key:
        if rv.vals.validity.isNil or rv.vals.valid(idx):
          return rv.vals[idx]
        return default(nimOf(ktVal))
  raise newException(KeyError, "key not found: " & $key)

proc getOrDefault*[ktKey, ktVal: static DuckType](
    rv: MapRowView[ktKey, ktVal], key: nimOf(ktKey)): nimOf(ktVal) {.inline.} =
  ## Value for `key` in the MAP row, or `default(nimOf(ktVal))` if absent.
  let off = rv.offset
  let n = rv.length
  when ktKey in DuckStringKind or ktKey in DuckBlobKind:
    for j in 0 ..< n:
      let idx = off + j
      if borrowedMapKeyMatches[ktKey](rv.keys.borrow(idx), key):
        if rv.vals.validity.isNil or rv.vals.valid(idx):
          return rv.vals[idx]
        return default(nimOf(ktVal))
  else:
    for j in 0 ..< n:
      let idx = off + j
      if (rv.keys.validity.isNil or rv.keys.valid(idx)) and rv.keys[idx] == key:
        if rv.vals.validity.isNil or rv.vals.valid(idx):
          return rv.vals[idx]
        return default(nimOf(ktVal))
  return default(nimOf(ktVal))

proc getOrDefault*[ktKey, ktVal: static DuckType](
    rv: MapRowView[ktKey, ktVal], key: nimOf(ktKey),
    fallback: nimOf(ktVal)): nimOf(ktVal) {.inline.} =
  ## Value for `key` in the MAP row, or `fallback` if absent.
  let off = rv.offset
  let n = rv.length
  when ktKey in DuckStringKind or ktKey in DuckBlobKind:
    for j in 0 ..< n:
      let idx = off + j
      if borrowedMapKeyMatches[ktKey](rv.keys.borrow(idx), key):
        if rv.vals.validity.isNil or rv.vals.valid(idx):
          return rv.vals[idx]
        return fallback
  else:
    for j in 0 ..< n:
      let idx = off + j
      if (rv.keys.validity.isNil or rv.keys.valid(idx)) and rv.keys[idx] == key:
        if rv.vals.validity.isNil or rv.vals.valid(idx):
          return rv.vals[idx]
        return fallback
  return fallback

proc borrowMap*[ktKey, ktVal: static DuckType](
    mv: MapView[ktKey, ktVal], i: int): MapRowView[ktKey, ktVal] {.inline.} =
  ## Zero-copy view of MAP row `i` as a `MapRowView` — no per-row allocation.
  doAssert i >= 0 and i < mv.length, "MapView index out of bounds: " & $i
  let (off, ln) = mv.parent.mapEntry(i)
  result.keys = mv.keys
  result.vals = mv.vals
  result.offset = int(off)
  result.length = int(ln)

proc `[]`*[ktKey, ktVal: static DuckType](
    mv: MapView[ktKey, ktVal], i: int): OrderedTable[nimOf(ktKey), nimOf(ktVal)] =
  ## MAP row `i` as an `OrderedTable` (allocates per row); NULL rows yield an
  ## empty table. Use `borrowMap` for zero-copy row access.
  # bench_map/owning_lookup confirms one table and owned key/value payloads per
  # row. Use borrowMap for repeated scans and lookups.
  if not mv.valid(i):
    return initOrderedTable[nimOf(ktKey), nimOf(ktVal)](0)
  let row = mv.borrowMap(i)
  result = initOrderedTable[nimOf(ktKey), nimOf(ktVal)](row.length)
  for k, v in row.pairs:
    result[k] = v

iterator items*[ktKey, ktVal: static DuckType](
    mv: MapView[ktKey, ktVal]): OrderedTable[nimOf(ktKey), nimOf(ktVal)] =
  ## Yields each MAP row as an `OrderedTable`.
  for i in 0 ..< mv.length:
    yield mv[i]

proc toSeq*[ktKey, ktVal: static DuckType](
    mv: MapView[ktKey, ktVal]): seq[OrderedTable[nimOf(ktKey), nimOf(ktVal)]] =
  ## Materializes the whole MAP column as `OrderedTable`s.
  result = newSeq[OrderedTable[nimOf(ktKey), nimOf(ktVal)]](mv.length)
  for i in 0 ..< mv.length:
    result[i] = mv[i]

# ---------------------------------------------------------------------------
# ListView — typed LIST column view + zero-copy per-row slice
# ---------------------------------------------------------------------------

proc initListView*[kt: static DuckType](
    cv: ColumnView
  ): ListView[kt] {.inline.} =
  ## Binds a LIST column `ColumnView` to a typed `ListView`; raises `ValueError`
  ## if the column is not a LIST.
  if cv.kind != DuckType.List:
    raise newException(ValueError,
      "bindAs(seq[T]) requires a List column; got " & $cv.kind)
  let vl = cv.bindAs(DuckType.List)
  result.parent = vl
  result.child = vl.listChild.bindAs(kt)
  result.length = cv.length

proc initListViewFromVector*[kt: static DuckType](
    v: Vector[DuckType.List]
  ): ListView[kt] {.inline.} =
  ## `ListView` from an already-bound `Vector[DuckType.List]`;
  ## sibling to `initListView`.
  result.parent = v
  result.child = v.listChild.bindAs(kt)
  result.length = v.length

proc bindAs*[T](cv: ColumnView, _: typedesc[seq[T]]): ListView[colDuckTypeOf(T)] {.inline.} =
  ## Binds a LIST column as a `ListView[T]` (`lv[i]` gives a `seq[T]`).
  initListView[colDuckTypeOf(T)](cv)

proc bindAs*[T](c: DataChunk, i: int, U: typedesc[seq[T]]): ListView[colDuckTypeOf(T)] {.inline.} =
  ## Convenience for `c.vector(i).bindAs(seq[T])`.
  c.vector(i).bindAs(U)

proc borrowList*[kt: static DuckType](
    lv: ptr ListView[kt], i: int): SliceView[kt] {.inline.} =
  ## Zero-copy view of LIST row `i` as a `SliceView` — no per-row allocation.
  # This is the allocation-free path measured by
  # bench_data_paths/nested_borrowed. The returned view borrows lv[].child.
  doAssert i >= 0 and i < lv[].length, "ListView index out of bounds: " & $i
  let (off, ln) = lv[].parent.listEntry(i)
  result.vec = addr lv[].child
  result.offset = int(off)
  result.length = int(ln)

template borrowList*[kt: static DuckType](
    lv: ListView[kt], i: int): SliceView[kt] =
  ## Borrows a list row from the caller-owned `ListView`.
  borrowList[kt](addr lv, i)

proc `[]`*[kt: static DuckType](lv: ListView[kt], i: int): seq[nimOf(kt)] =
  ## The list at row `i` as a `seq`; NULL rows yield an empty `seq`.
  # Profiling hot path: this allocates one seq per valid row. Use borrowList
  # when the caller can consume the child values before the chunk is released.
  if not lv.valid(i):
    return newSeq[nimOf(kt)](0)
  let slice = lv.borrowList(i)
  slice.toSeq

iterator items*[kt: static DuckType](lv: ListView[kt]): seq[nimOf(kt)] =
  ## Yields each row's list as a `seq`.
  for i in 0 ..< lv.length:
    yield lv[i]

proc toSeq*[kt: static DuckType](lv: ListView[kt]): seq[seq[nimOf(kt)]] =
  ## Materializes the whole LIST column as `seq`s.
  result = newSeq[seq[nimOf(kt)]](lv.length)
  for i in 0 ..< lv.length:
    result[i] = lv[i]

# ---------------------------------------------------------------------------
# ArrayView — typed ARRAY column view + zero-copy per-row slice
# ---------------------------------------------------------------------------

proc initArrayView*[kt: static DuckType](
    cv: ColumnView
  ): ArrayView[kt] {.inline.} =
  ## Binds an ARRAY column `ColumnView` to a typed `ArrayView`; raises
  ## `ValueError` if the column is not an ARRAY.
  if cv.kind != DuckType.Array:
    raise newException(ValueError,
      "bindAsArray(kt) requires an Array column; got " & $cv.kind)
  let va = cv.bindAs(DuckType.Array)
  result.parent = va
  result.arraySize = va.arraySize
  result.child = va.arrayChild.bindAs(kt)
  result.length = cv.length

proc initArrayViewFromVector*[kt: static DuckType](
    v: Vector[DuckType.Array]
  ): ArrayView[kt] {.inline.} =
  ## `ArrayView` from an already-bound `Vector[DuckType.Array]`; sibling to
  ## `initArrayView`.
  result.parent = v
  result.arraySize = v.arraySize
  result.child = v.arrayChild.bindAs(kt)
  result.length = v.length

proc bindAsArray*(cv: ColumnView, kt: static DuckType): ArrayView[kt] {.inline.} =
  ## Binds an ARRAY column with a known child kind to a typed `ArrayView`.
  initArrayView[kt](cv)

proc bindAsArray*(c: DataChunk, i: int, kt: static DuckType): ArrayView[kt] {.inline.} =
  ## Convenience for `c.vector(i).bindAsArray(kt)`.
  c.vector(i).bindAsArray(kt)

proc borrowArray*[kt: static DuckType](
    av: ptr ArrayView[kt], i: int): SliceView[kt] {.inline.} =
  ## Zero-copy view of the array element at row `i` as a fixed-width slice.
  doAssert i >= 0 and i < av[].length, "ArrayView index out of bounds: " & $i
  result.vec = addr av[].child
  result.offset = i * av[].arraySize
  result.length = av[].arraySize

template borrowArray*[kt: static DuckType](
    av: ArrayView[kt], i: int): SliceView[kt] =
  ## Borrows an array row from the caller-owned `ArrayView`.
  borrowArray[kt](addr av, i)

proc `[]`*[kt: static DuckType](av: ArrayView[kt], i: int): seq[nimOf(kt)] =
  ## The array at row `i` as a `seq`; NULL rows yield an empty `seq`.
  if not av.valid(i):
    return newSeq[nimOf(kt)](0)
  let slice = av.borrowArray(i)
  slice.toSeq

iterator items*[kt: static DuckType](av: ArrayView[kt]): seq[nimOf(kt)] =
  ## Yields each row's array as a `seq`; NULL rows yield empty `seq`s.
  for i in 0 ..< av.length:
    yield av[i]

proc toSeq*[kt: static DuckType](av: ArrayView[kt]): seq[seq[nimOf(kt)]] =
  ## Materializes the whole column as a `seq` of `seq`s.
  result = newSeq[seq[nimOf(kt)]](av.length)
  for i in 0 ..< av.length:
    result[i] = av[i]

# ---------------------------------------------------------------------------
# items iterator — yields Nim equivalents per row, honouring validity
# ---------------------------------------------------------------------------

iterator items*[kt: static DuckType](v: Vector[kt]): nimOf(kt) =
  ## Iterates over all rows, yielding `nimOf(kt)` for valid rows and
  ## `default(nimOf(kt))` for NULL rows.
  ##
  ## .. warning:: NULL rows yield `default(T)` and are **indistinguishable** from
  ##   a real zero/empty value (e.g. `0` for integers, `""` for strings). To
  ##   preserve null-ness, check `valid(i) <`` `v[i]` individually, or use
  ##   `complex.toNimValue` which returns `NimValue(kind: nvNull)` for nulls.
  let n = v.length
  if v.validity.isNil:
    # Fully-valid column: branchless fast path, no per-row validity load.
    for i in 0 ..< n:
      yield v[i]
  else:
    for i in 0 ..< n:
      if v.valid(i): yield v[i]
      else: yield default(nimOf(kt))


# ---------------------------------------------------------------------------
# toSeq — explicit bulk materialise for any kind
# ---------------------------------------------------------------------------

proc toSeq*[kt: static DuckType](v: Vector[kt]): seq[nimOf(kt)] =
  ## Materialises all rows into a `seq`. NULL rows are filled with
  ## `default(nimOf(kt))`.
  ##
  ## .. warning:: NULL rows yield `default(T)` and are **indistinguishable** from
  ##   a real zero/empty value (e.g. `0` for integers, `""` for strings). To
  ##   preserve null-ness, check `valid(i) <`` `v[i]` individually, or use
  ##   `complex.toNimValues` which returns `NimValue(kind: nvNull)` for nulls.
  result = newSeq[nimOf(kt)](v.length)
  if v.validity.isNil:
    when kt in DuckPrimitiveKind:
      if v.length > 0:
        copyMem(addr result[0], v.data, v.length * sizeof(nimOf(kt)))
    elif kt == DuckType.Boolean:
      if v.length > 0:
        copyMem(addr result[0], v.data, v.length)
    else:
      for i in 0 ..< v.length:
        result[i] = v[i]
  else:
    for i in 0 ..< v.length:
      if v.valid(i): result[i] = v[i] else: result[i] = default(nimOf(kt))

# ---------------------------------------------------------------------------
# itemsOpt / toSeqOpt — null-preserving variants
# ---------------------------------------------------------------------------
#
# Unlike `items`/`toSeq`, these yield `Option[nimOf(kt)]` (or `none` for NULL
# rows) so null-ness is preserved with no allocation for primitive kinds.  Prefer
# these when the result may contain NULLs and you need to distinguish them from
# a real zero/empty value.

iterator itemsOpt*[kt: static DuckType](v: Vector[kt]): Option[nimOf(kt)] =
  ## Null-preserving `items`: yields `some(v)` for valid rows and `none` for
  ## NULL rows, at no per-row allocation cost for primitive kinds.
  # bench_data_paths/nullable_items is the allocation-free nullable scan.
  let n = v.length
  if v.validity.isNil:
    for i in 0 ..< n:
      yield some(v[i])
  else:
    for i in 0 ..< n:
      if v.valid(i): yield some(v[i]) else: yield none(nimOf(kt))

proc toSeqOpt*[kt: static DuckType](v: Vector[kt]): seq[Option[nimOf(kt)]] =
  ## Null-preserving `toSeq`: NULL rows become `none(nimOf(kt))`.
  # Profiling hot path: this allocates one result seq per bound chunk. Use
  # itemsOpt when the caller does not need owned random-access storage.
  result = newSeq[Option[nimOf(kt)]](v.length)
  v.toSeqOptInto(result)

proc toSeqOptInto*[kt: static DuckType](
    v: Vector[kt], dest: var seq[Option[nimOf(kt)]]) =
  ## Reuses `dest` storage for a null-preserving materialization.
  dest.setLen(v.length)
  when kt in DuckPrimitiveKind:
    let data = cast[ptr UncheckedArray[nimOf(kt)]](v.data)
    let validity = v.validity
    if validity.isNil:
      for i in 0 ..< v.length:
        dest[i] = some(data[i])
    else:
      var word = 0'u64
      for i in 0 ..< v.length:
        if (i and 63) == 0:
          word = validity[i shr 6]
        if (word and (1'u64 shl (i and 63))) != 0:
          dest[i] = some(data[i])
        else:
          dest[i] = none(nimOf(kt))
  elif kt == DuckType.Boolean:
    let data = cast[ptr UncheckedArray[uint8]](v.data)
    let validity = v.validity
    if validity.isNil:
      for i in 0 ..< v.length:
        dest[i] = some(bool(data[i]))
    else:
      var word = 0'u64
      for i in 0 ..< v.length:
        if (i and 63) == 0:
          word = validity[i shr 6]
        if (word and (1'u64 shl (i and 63))) != 0:
          dest[i] = some(bool(data[i]))
        else:
          dest[i] = none(bool)
  else:
    if v.validity.isNil:
      for i in 0 ..< v.length:
        dest[i] = some(v[i])
    else:
      for i in 0 ..< v.length:
        if v.valid(i): dest[i] = some(v[i]) else: dest[i] = none(nimOf(kt))

# ---------------------------------------------------------------------------
# materialize — drain a streaming result into a materialized one
# ---------------------------------------------------------------------------

proc len*(q: QResult[Materialized]): int {.inline.} =
  ## Total rows in a materialized result.
  q.rlen

proc materialize*(q: sink QResult[Streaming]): QResult[Materialized] =
  ## Drain all remaining chunks from a streaming result and return a
  ## fully materialized `QResult[Materialized]`.
  ##
  ## `meta` (its immutable `columns`/`nameIndex` payload) is shared by
  ## reference with the source; only `rlen` — the result's own property — is
  ## accumulated locally, so no fresh `ChunkMeta` ref is needed.
  result.meta = q.meta
  result.chunks = @[]
  result.rlen = 0
  let h = takeHandle(q)
  result.rowsChanged = duckdb_rows_changed(h.raw.addr).int
  drainInto(result, h.raw)
  duckdb_destroy_result(h.raw.addr)

# ---------------------------------------------------------------------------
# newFiller — QResult[Materialized] → FillFn (zero-copy)
#
# Each source chunk is *referenced* into the scan output chunk via
# `duckdb_vector_reference_vector` — the output vector shares ownership of the
# source vector's buffers and no data is moved or copied, exactly like the
# Arrow path's `newMaterialized` filler.  This removes the per-column
# `ColumnCopier`/`copyMem` pass entirely.
#
# The source `DataChunk`s live in `q.chunks` and stay ARC-alive for the life of
# the filler closure (the closure captures `chunks` by ref), so the referenced
# buffers remain valid for the duration of the scan.
# ---------------------------------------------------------------------------

proc newFiller*(q: QResult[Materialized]): FillFn =
  ## A `FillFn` that replays a materialized result's chunks zero-copy, by
  ## referencing the source vectors (`duckdb_vector_reference_vector`) instead of
  ## copying. Used by `table_scan` and the Arrow export paths.
  let chunks = q.chunks
  let nCols = q.meta.columns.len
  var sourceVectors = newSeq[seq[duckdb_vector]](chunks.len)
  var sourceLengths = newSeq[int](chunks.len)
  for si, src in chunks:
    sourceVectors[si] = newSeq[duckdb_vector](nCols)
    sourceLengths[si] = src.len
    for ci in 0 ..< nCols:
      sourceVectors[si][ci] = duckdb_data_chunk_get_vector(
        src.rawHandle, ci.idx_t)
  var idx = 0
  result = proc(chunk: duckdb_data_chunk): int {.closure, gcsafe.} =
    if idx >= chunks.len: return 0
    let vectors = sourceVectors[idx]
    let n = sourceLengths[idx]
    inc idx
    for ci in 0 ..< nCols:
      duckdb_vector_reference_vector(
        duckdb_data_chunk_get_vector(chunk, ci.idx_t),
        vectors[ci])
    return n

proc newProjectedFiller*(q: QResult[Materialized], projectedIds: seq[int]): FillFn =
  ## Replays only the source vectors requested by a projected table scan.
  ## Output positions follow `projectedIds`, while source positions remain in
  ## the materialized result. A zero-column projection still returns rows.
  let chunks = q.chunks
  for sourceIndex in projectedIds:
    doAssert sourceIndex >= 0 and sourceIndex < q.meta.columns.len,
      "projected source column out of range"
  var sourceVectors = newSeq[seq[duckdb_vector]](chunks.len)
  var sourceLengths = newSeq[int](chunks.len)
  for si, src in chunks:
    sourceVectors[si] = newSeq[duckdb_vector](projectedIds.len)
    sourceLengths[si] = src.len
    for pi, sourceIndex in projectedIds:
      sourceVectors[si][pi] = duckdb_data_chunk_get_vector(
        src.rawHandle, sourceIndex.idx_t)
  var idx = 0
  result = proc(chunk: duckdb_data_chunk): int {.closure, gcsafe.} =
    if idx >= chunks.len:
      return 0
    let vectors = sourceVectors[idx]
    let n = sourceLengths[idx]
    inc idx
    for pi in 0 ..< projectedIds.len:
      duckdb_vector_reference_vector(
        duckdb_data_chunk_get_vector(chunk, pi.idx_t), vectors[pi])
    n
