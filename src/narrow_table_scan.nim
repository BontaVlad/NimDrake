## Register Arrow data (narrow `RecordBatch` / `ArrowTable`) as DuckDB views.
##
## Zero-copy version.  The data path during a scan is:
##
##   RecordBatch
##     --(1) narrow `slice` (offset/length window, buffers shared)-->
##     --(2) exportRecordBatch -> ArrowArray/ArrowSchema C structs-->
##     --(3) duckdb_data_chunk_from_arrow (ownership of the Arrow buffers is
##           transferred to the DuckDB DataChunk — no copy is made) -->
##     --(4) duckdb_vector_reference_vector per column at scan time
##           (the output vector references the converted vector; no data
##           is moved) -->
##   table-function output chunk
##
## Step (4) aliases the output vector to the converted vector via
## `duckdb_vector_reference_vector` instead of calling `copyMem`, removing the
## per-scan `ColumnCopier` pass entirely.
##
## Ownership notes:
##   * Per DuckDB's contract (`duckdb_data_chunk_from_arrow`), the resulting
##     DataChunk **retains ownership of the underlying Arrow data** — the
##     ArrowArray's buffers are not copied and are not released by us.  The
##     exported ArrowArray C struct must therefore NOT be released after
##     conversion: doing so would free buffers the DuckDB chunk still owns
##     (use-after-free / double-free).  DuckDB takes over the ArrowArray's
##     release responsibility.
##   * The exported ArrowSchema, by contrast, is consumed by
##     `duckdb_schema_from_arrow` to build the converted schema and is not the
##     buffer owner, so it is safe (and correct) to release it once
##     `convertSchema` returns.
##   * The small struct wrappers heap-allocated by GLib for the export are
##     leaked for simplicity (~50 bytes each); this is benign and the ArrowArray
##     one is intentionally left for DuckDB to clean up via its own release.

when not defined(features.nimdrake.arrow):
  {.error: "narrow_table_scan.nim requires -d:features.nimdrake.arrow".}

import narrow
import /[database, ffi, types, qresult, arrow]
import narrow/interop/cdata

# ---------------------------------------------------------------------------
# Conversion primitives
#
# DuckDB's C API receives `struct ArrowSchema*` / `struct ArrowArray*` which
# DuckDB only forward-declares; the real layout is defined by the Arrow C Data
# Interface ABI.  In Nim the forward-declared types are `struct_ArrowSchema`
# and `struct_ArrowArray` (opaque objects in generated.nim).  We use the
# hand-rolled `ArrowSchema`/`ArrowArray` from arrow.nim (which match the ABI)
# for accessing `release` fields, and cast to the opaque types when calling
# the DuckDB FFI.
# ---------------------------------------------------------------------------

proc convertSchema(
    conn: duckdb_connection, cAbiSchema: pointer
): duckdb_arrow_converted_schema =
  let err = duckdb_schema_from_arrow(
    conn, cast[ptr struct_ArrowSchema](cAbiSchema), result.addr)
  if duckdbErrorDataHasError(err).bool:
    let msg = $duckdb_error_data_message(err)
    duckdb_destroy_error_data(err.addr)
    raise newException(OperationError, "duckdb_schema_from_arrow: " & msg)

proc convertChunk(
    conn: duckdb_connection, cAbiArray: pointer,
    convSchema: duckdb_arrow_converted_schema
): duckdb_data_chunk =
  let err = duckdb_data_chunk_from_arrow(
    conn, cast[ptr struct_ArrowArray](cAbiArray), convSchema, result.addr)
  if duckdbErrorDataHasError(err).bool:
    let msg = $duckdb_error_data_message(err)
    duckdb_destroy_error_data(err.addr)
    raise newException(OperationError, "duckdb_data_chunk_from_arrow: " & msg)

proc logicalTypeOf(vec: duckdb_vector): LogicalType =
  newLogicalType(duckdb_vector_get_column_type(vec))

proc buildChunkMeta(schema: Schema, chunk: duckdb_data_chunk): ChunkMeta =
  ## Derive a `ChunkMeta` (columns + name index) from the converted chunk's
  ## DuckDB vectors, using the narrow `Schema` for column names.  Called once
  ## per source; the meta is then shared by every window chunk.
  let n = schema.nFields
  var cols = newSeq[Column](n)
  for i in 0 ..< n:
    let vec = duckdb_data_chunk_get_vector(chunk, i.idx_t)
    cols[i] = newColumn(schema[i].name, logicalTypeOf(vec), i)
  result = newChunkMeta(cols)

# ---------------------------------------------------------------------------
# Batch conversion — windowed at STANDARD_VECTOR_SIZE rows
# ---------------------------------------------------------------------------
#
# Table-function output chunks hold at most `duckdb_vector_size()` rows, but an
# Arrow record batch can be arbitrarily large.  Each batch is therefore cut
# into windows with narrow's zero-copy `slice` (offset/length only — buffers
# are shared) and every window is converted into its own chunk.  The scan then
# serves one window per call without any slicing or copying at fill time.

proc releaseSchema(cAbiSchema: pointer) =
  ## Call the release callback on an exported ArrowSchema.
  ## Uses the hand-rolled ArrowSchema type to access the release field.
  ## Safe to call after `duckdb_schema_from_arrow` because the exported schema
  ## is not the Arrow buffer owner.
  var s = cast[ptr ArrowSchema](cAbiSchema)[]
  if not s.release.isNil:
    s.release(s.addr)

proc convertWindow(
    conn: duckdb_connection, batch: RecordBatch,
    convSchema: duckdb_arrow_converted_schema
): duckdb_data_chunk =
  ## Exports one (window of a) RecordBatch and converts it.  Per DuckDB's
  ## contract the resulting DataChunk takes ownership of the Arrow buffers, so
  ## the exported ArrowArray must NOT be released here — DuckDB owns it now.
  let (cAbiArray, cAbiSchema) = exportRecordBatch(batch)

  # The exported ArrowSchema is consumed by convertSchema (already done by the
  # caller) and is not the buffer owner, so it is safe to release.  The array
  # is intentionally left for DuckDB to clean up.
  releaseSchema(cAbiSchema)

  result = convertChunk(conn, cAbiArray, convSchema)

proc convertBatchInto(
    q: var QResult[Materialized], conn: duckdb_connection, batch: RecordBatch
) =
  ## Convert one RecordBatch (windowed at STANDARD_VECTOR_SIZE) and append the
  ## resulting DuckDB-owned DataChunks to `q`.  Column metadata is derived once
  ## from the first window and stored on `q.meta`; it is shared by every chunk.
  let vecSize = duckdb_vector_size().int64
  let nRows = batch.nRows.int64

  # One converted schema per batch; identical for all of its windows.
  let cSchema = exportSchema(batch.schema)
  let convSchema = convertSchema(conn, cSchema)
  defer: duckdb_destroy_arrow_converted_schema(convSchema.addr)

  # Release the exported schema — it is no longer needed after conversion.
  releaseSchema(cSchema)

  var haveCols = q.meta != nil and q.meta.columns.len > 0

  if nRows == 0:
    # Preserve column definitions (and EOF behaviour) for empty input.
    let rawChunk = convertWindow(conn, batch, convSchema)
    if not haveCols:
      q.meta = buildChunkMeta(batch.schema, rawChunk)
    q.chunks.add newDataChunk(rawChunk, q.meta)
    return

  var off = 0'i64
  while off < nRows:
    let n = min(vecSize, nRows - off)
    let win =
      if off == 0 and n == nRows: batch
      else: batch.slice(off, n)
    let rawChunk = convertWindow(conn, win, convSchema)
    if not haveCols:
      q.meta = buildChunkMeta(batch.schema, rawChunk)
      haveCols = true
    q.chunks.add newDataChunk(rawChunk, q.meta)
    off += n

# ---------------------------------------------------------------------------
# Constructors
# ---------------------------------------------------------------------------

proc newMaterialized*(batch: RecordBatch, conn: Connection): QResult[Materialized] =
  ## Convert a single RecordBatch into a materialized DuckDB result.  The
  ## returned `QResult[Materialized]` satisfies the `TableSource` concept, so
  ## it can be registered directly: `conn.register(batch.newMaterialized(conn),
  ## name = "v")`.  No data is copied at scan time (see module header).
  convertBatchInto(result, conn.rawHandle, batch)
  result.meta.rlen = batch.nRows.int

proc newMaterialized*(table: ArrowTable, conn: Connection): QResult[Materialized] =
  ## Convert an ArrowTable (one or more RecordBatches) into a materialized
  ## DuckDB result.  See `newMaterialized(RecordBatch, Connection)`.
  let reader = newRecordBatchReader(table)
  var totalRows = 0
  for batch in reader.batches:
    convertBatchInto(result, conn.rawHandle, batch)
    totalRows += batch.nRows.int
  if result.meta == nil:
    result.meta = newChunkMeta(newSeq[Column]())
  result.meta.rlen = totalRows

