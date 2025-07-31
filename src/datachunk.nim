import std/[strformat, options]
import /[api, types, vector, exceptions]

type
  DataChunkBase = object of RootObj
    handle*: duckdbDataChunk
    types: seq[LogicalType] # only here for lifetime tracking, maybe I can avoid this
    shouldDestroy: bool # in some cases duckdb takes care of the cleaning

  DataChunk* = ref object of DataChunkBase

converter toC*(d: DataChunk): duckdbdatachunk =
  d.handle

converter toBool*(d: DataChunk): bool =
  not isNil(d) or duckdbdatachunkgetsize(d).int > 0

proc `=destroy`(d: DataChunkBase) =
  if d.handle != nil and d.shouldDestroy:
    # cleanup LogicalTypes and the duckdb pointer
    `=destroy`(d.types)
    duckdb_destroy_datachunk(d.handle.addr)
  elif d.handle != nil:
    # cleanup will be done by duckdb but the
    # logical types we need to cleanup ourselfs
    `=destroy`(d.types)

proc columnCount*(chunk: DataChunk): int =
  return duckdbDataChunkGetColumnCount(chunk.handle).int

proc newDataChunk*(
    handle: duckdbDataChunk, types: seq[DuckType], shouldDestroy: bool = true
): DataChunk =
  let columnCount = len(types)
  var logicalTypes = newSeq[LogicalType](columnCount)

  for i, tp in types:
    logicalTypes[i] = newLogicalType(tp)

  return DataChunk(handle: handle, types: logicalTypes, shouldDestroy: shouldDestroy)

proc newDataChunk*(types: seq[DuckType], shouldDestroy: bool = true): DataChunk =
  let columnCount = len(types)
  var logicalTypes = newSeq[LogicalType](columnCount)
  var duckLogicalTypes = newSeq[duckdbLogicalType](columnCount)

  for i, tp in types:
    logicalTypes[i] = newLogicalType(tp)
    duckLogicalTypes[i] = logicalTypes[i].handle

  let chunk = duckdb_create_data_chunk(
    cast[ptr duckdb_logical_type](duckLogicalTypes[0].addr), len(types).idx_t
  )

  if chunk == nil:
    raise newException(OperationError, "Failed to create data chunk")

  return DataChunk(handle: chunk, types: logicalTypes, shouldDestroy: shouldDestroy)

proc newDataChunk*(handle: duckdb_data_chunk, shouldDestroy: bool = true): DataChunk =
  let columnCount = duckdbDataChunkGetColumnCount(handle).int
  var types = newSeq[LogicalType](columnCount)

  for i in 0 ..< columnCount:
    let vec = duckdbDataChunkGetVector(handle, i.idx_t)
    let kind = duckdbVectorGetColumnType(vec)
    types[i] = newLogicalType(kind)

  return DataChunk(handle: handle, types: types, shouldDestroy: shouldDestroy)

proc len*(chunk: DataChunk): int =
  result = duckdbDataChunkGetSize(chunk.handle).int

proc setLen*(chunk: DataChunk, sz: int) =
  duckdbDataChunkSetSize(chunk.handle, sz.idx_t)

proc `[]=`*[T](chunk: var DataChunk, colIdx: int, values: seq[T]) =
  if chunk.len != 0 and chunk.len != len(values):
    raise newException(
      ValueError,
      fmt"Chunk size is inconsistent, new size of {len(values)} is different from {chunk.len}",
    )
  elif len(values) > VECTOR_SIZE:
    raise newException(
      ValueError, fmt"Chunk size is bigger than the allowed vector size: {VECTOR_SIZE}"
    )

  var vec = duckdbDataChunkGetVector(chunk, colIdx.idx_t)
  for i, e in values:
    vec[i] = e

  chunk.setLen(len(values))

proc `[]=`*[T](chunk: var DataChunk, colIdx: int, values: seq[Option[T]]) =
  if chunk.len != 0 and chunk.len != len(values):
    raise newException(
      ValueError,
      fmt"Chunk size is inconsistent, new size of {len(values)} is different from {chunk.len}",
    )
  elif len(values) > VECTOR_SIZE:
    raise newException(
      ValueError, fmt"Chunk size is bigger than the allowed vector size: {VECTOR_SIZE}"
    )

  var
    vec = duckdbDataChunkGetVector(chunk, colIdx.idx_t)
    validityMask = newValidityMask(vec, len(values), isWritable=true)
  for i, e in values:
    if e.isSome():
      vec[i] = e.get()
      validityMask.setValidity(i, true)
    else:
      # vec[i] = nil
      validityMask.setValidity(i, false)

  chunk.setLen(len(values))

proc `[]`*(chunk: DataChunk, colIdx: int): Vector =
  let vec = duckdbDataChunkGetVector(chunk.handle, colIdx.idx_t)
  return newVector(vec, chunk.len)
