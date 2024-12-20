import std/[strformat]
import /[api, types, vector]

proc len*(chunk: DataChunk): int =
  result = duckdb_data_chunk_get_size(chunk.handle).int

proc `len=`*(chunk: DataChunk, sz: int) =
  duckdb_data_chunk_set_size(chunk.handle, sz.idx_t)

template `[]=`*[T: SomeNumber](vec: duckdb_vector, i: int, val: T) =
  var raw = duckdb_vector_get_data(vec)
  when T is int:
    cast[ptr UncheckedArray[cint]](raw)[i] = cint(val)
  else:
    cast[ptr UncheckedArray[T]](raw)[i] = val

template `[]=`*(vec: duckdb_vector, i: int, val: bool) =
  var raw = duckdb_vector_get_data(vec)
  cast[ptr UncheckedArray[uint8]](raw)[i] = val.uint8

proc `[]=`*[T](chunk: var DataChunk, colIdx: int, values: seq[T]) =
  let
    col = chunk.columns[colIdx]
    vec = duckdb_data_chunk_get_vector(chunk, colIdx.idx_t)
  for i, e in values:
    vec[i] = e

  if chunk.len != 0 and chunk.len != len(values):
    raise newException(
      ValueError,
      fmt"Chunk size is inconsistent, new size of {len(values)} is different from {chunk.len}",
    )
  chunk.len = len(values)

proc `[]=`*(vec: duckdb_vector, i: int, val: string) =
  duckdb_vector_assign_string_element(vec, i.idx_t, val.cstring)

proc `[]=`*(chunk: var DataChunk, colIdx: int, values: seq[string]) =
  let col = chunk.columns[colIdx]
  var vec = duckdb_data_chunk_get_vector(chunk, colIdx.idx_t)
  if col.kind != DuckType.Varchar:
    raise newException(ValueError, "Column is not of type VarChar")
  for i, e in values:
    vec[i] = e

  if chunk.len != 0 and chunk.len != len(values):
    raise newException(
      ValueError,
      fmt"Chunk size is inconsistent, new size of {len(values)} is different from {chunk.len}",
    )
  chunk.len = len(values)

proc `[]`*(chunk: DataChunk, colIdx: int): Vector =
  let
    col = chunk.columns[colIdx]
    vec = duckdb_data_chunk_get_vector(chunk.handle, col.idx.idx_t)
  result = newVector(vec, 0, chunk.len, col.kind, col.logicalType)
