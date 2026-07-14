## Cross-chunk random-access Table API.
##
## Built on a `QResult[Materialized]`, builds a single `offsets` seq once
## so per-row lookup is O(log(numChunks)) via binary search.
##
## The `TableVector[kt]` is the typed view, analogous to the per-chunk
## `Vector[kt]` but spanning all chunks.

import std/strformat
import /[types, qresult]

type
  Table* = object
    q: QResult[Materialized]
    offsets: seq[int]

  TableVector*[kt: static DuckType] = object
    t: Table
    colIdx: int

proc initTable*(q: sink QResult[Materialized]): Table =
  result.q = q
  result.offsets = newSeq[int](q.chunks.len + 1)
  for ci in 0 ..< q.chunks.len:
    result.offsets[ci + 1] = result.offsets[ci] + q.chunks[ci].len

proc initTable*(q: sink QResult[Streaming]): Table {.inline.} =
  initTable(q.materialize())

proc len*(t: Table): int {.inline.} =
  t.offsets[^1]

proc chunkFor*(t: Table, i: int): (DataChunk, int) {.inline.} =
  if i < 0 or i >= t.len:
    raise newException(IndexDefect, "row index out of range: " & $i)
  var lo = 0
  var hi = t.q.chunks.len
  while hi - lo > 1:
    let mid = (lo + hi) shr 1
    if i < t.offsets[mid]:
      hi = mid
    else:
      lo = mid
  result = (t.q.chunks[lo], i - t.offsets[lo])

proc bindAs*(t: Table, idx: int, kt: static DuckType): TableVector[kt] {.inline.} =
  if idx < 0 or idx >= t.q.meta.columns.len:
    raise newException(ValueError, "column index out of range: " & $idx)
  let colKind = t.q.meta.columns[idx].kind
  if colKind != kt:
    raise newException(ValueError, "column " & $idx & " is " & $colKind & ", requested " & $kt)
  TableVector[kt](t: t, colIdx: idx)

proc bindAs*(t: Table, name: string, kt: static DuckType): TableVector[kt] {.inline.} =
  let idx = t.q.meta.nameIndex[name]
  let colKind = t.q.meta.columns[idx].kind
  if colKind != kt:
    raise newException(ValueError, "column " & name & " is " & $colKind & ", requested " & $kt)
  bindAs(t, idx, kt)

proc len*(v: TableVector): int {.inline.} =
  v.t.len

proc `[]`*[kt: static DuckType](v: TableVector[kt], i: int): nimOf(kt) {.inline.} =
  let (chunk, off) = chunkFor(v.t, i)
  chunk.bindAs(v.colIdx, kt)[off]

iterator items*[kt: static DuckType](v: TableVector[kt]): nimOf(kt) =
  for ci in 0 ..< v.t.q.chunks.len:
    let vec = v.t.q.chunks[ci].bindAs(v.colIdx, kt)
    for j in 0 ..< vec.len:
      if vec.valid(j): yield vec[j]
      else: yield default(nimOf(kt))

proc toSeq*[kt: static DuckType](v: TableVector[kt]): seq[nimOf(kt)] =
  result = newSeqOfCap[nimOf(kt)](v.len)
  for ci in 0 ..< v.t.q.chunks.len:
    let vec = v.t.q.chunks[ci].bindAs(v.colIdx, kt)
    for li in 0 ..< vec.len:
      if vec.valid(li): result.add vec[li]
      else: result.add default(nimOf(kt))

proc borrow*[kt: static DuckType](v: TableVector[kt], i: int): DuckStringRef {.inline.} =
  let (chunk, off) = chunkFor(v.t, i)
  chunk.bindAs(v.colIdx, kt).borrow(off)

proc valid*[kt: static DuckType](v: TableVector[kt], i: int): bool {.inline.} =
  let (chunk, off) = chunkFor(v.t, i)
  chunk.vector(v.colIdx).valid(off)
