## Arrow C Data Interface integration for NimDrake.
##
## Provides `toArrowStream` and `toArrowTable` to convert a streaming
## `QResult[Streaming]` into `narrow` `RecordBatch` / `ArrowTable` values.
##
## This module is only compiled under `-d:features.nimdrake.arrow`.
##
## `ArrowSchema` and `ArrowArray` are hand-rolled to match the Arrow C Data
## Interface ABI because Futhark emits DuckDB's forward-declared `struct
## ArrowArray` / `struct ArrowSchema` as empty opaque objects (the headers
## only forward-declare them — the layout is defined by the Arrow ABI spec,
## not by DuckDB). The generated `struct_ArrowArray` / `struct_ArrowSchema`
## from `generated.nim` are used purely as opaque pointer targets at the FFI
## boundary via `cast[ptr struct_ArrowArray](result.addr)`.

when not defined(features.nimdrake.arrow):
  {.error: "arrow.nim requires -d:features.nimdrake.arrow".}

import narrow
import /[ffi, types, qresult]

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
    opt.handle, chunk.rawHandle, cast[ptr struct_ArrowArray](result.addr)
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
