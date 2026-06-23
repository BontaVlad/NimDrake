import std/[math, tables, sequtils]

import /[ffi, exceptions, database, datachunk, dataframe, types, vector]

when defined(features.nimdrake.arrow):
  import std/macros
  import narrow/column/metadata
  import narrow/tabular/[table, batch]

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

  DuckError* = object
    handle: duckdb_error_data

proc `=destroy`(opt: ArrowOptions) =
  if opt.handle != nil:
    duckdb_destroy_arrow_options(opt.handle.addr)

proc `=destroy`(arr: ArrowArray) {.raises: [].} =
  if not isNil(arr.release):
    try:
      arr.release(arr.addr)
    except Exception:
      discard

proc `=destroy`(err: DuckError) =
  if not isNil(err.handle):
    duckdb_destroy_error_data(err.handle.addr)

proc `=destroy`(schema: ArrowSchema) {.raises: [].} =
  if not isNil(schema.release):
    try:
      schema.release(schema.addr)
    except Exception:
      discard

converter toBool*(e: DuckError): bool =
  duckdb_error_data_has_error(e.handle).bool

proc message(e: DuckError): string =
  return $duckdb_error_data_message(e.handle)

proc `$`(e: DuckError): string =
  return e.message

proc newDuckError(err: duckdb_error_data): DuckError =
  DuckError(handle: err)

proc newArrowOptions(conn: Connection): ArrowOptions =
  duckdb_connection_get_arrow_options(conn.handle, result.handle.addr)

proc newArrowArray(opt: ArrowOptions, chunk: DataChunk): ArrowArray {.raises: [OperationError]} =
  let err = newDuckError(
    duckdb_data_chunk_to_arrow(
      opt.handle, chunk.handle, cast[ptr struct_ArrowArray](result.addr)
    )
  )
  if err:
    raise newException(OperationError, $err)

proc newArrowSchema(opt: ArrowOptions, cols: sink seq[Column]): ArrowSchema {.raises: [OperationError]} =
  var
    tps = newSeq[LogicalType](len(cols))
    tpsHandels = newSeq[duckdbLogicalType](len(cols))
    names = newSeq[cstring](len(cols))

  for i, col in cols:
    let lT = newLogicalType(col.kind)
    GC_ref(lT)
    tps[i] = lT
    tpsHandels[i] = lT.handle
    names[i] = col.name.cstring

  let err = duckdb_to_arrow_schema(
    opt.handle,
    cast[ptr duckdbLogicalType](tpsHandels[0].addr),
    cast[ptr cstring](names[0].addr),
    len(cols).idx_t,
    cast[ptr struct_ArrowSchema](result.addr),
  )

  for t in tps:
    GC_unref(t)

  if not isNil(err):
    raise newException(OperationError, $duckdb_error_data_message(err))

proc isStreaming*(qresult: QueryResult): bool =
  ## Checks if a query result is in streaming mode.
  ##
  ## Streaming mode allows processing of large result sets that don't fit in memory
  ## by fetching data in chunks rather than materializing the entire result set.
  return duckdbResultIsStreaming(qresult)

proc newColumn*(idx: int, name: string, kind: DuckType): Column =
  ## Creates a new Column with the specified index, name, and data type.
  ##
  ## Columns represent the schema information for a single column in a result set,
  ## including its position, name, and data type.
  ##
  ## **Example:**
  ## ```nim
  ## let col = newColumn(0, "user_id", DuckType.Integer)
  ## ```
  result = Column(idx: idx, name: name, kind: kind)

proc newColumn(qresult: QueryResult, idx: int): Column =
  ## Creates a new Column by extracting metadata from a query result at the specified index.
  ##
  ## This internal procedure reads column information directly from the DuckDB result
  ## to construct a Column object with the appropriate name and type.
  result = newColumn(
    idx = idx,
    name = $duckdbColumnName(qresult.addr, idx.idx_t),
    kind = newDuckType(duckdbColumnType(qresult.addr, idx.idx_t)),
  )

proc newPendingResult*(statement: Statement): PendingQueryResult =
  ## Executes the prepared statement with the given bound parameters, and returns a pending result.
  ##
  ## The pending result represents an intermediate structure for a query that is not yet fully executed.
  ## The pending result can be used to incrementally execute a query, returning control to the client between tasks.
  result = PendingQueryResult(nil)
  check(
    duckdbPendingPrepared(statement, result.addr),
    "Failed to execute the pending prepared statement",
    `=destroy`(result),
  )

proc newPendingStreamingResult*(
    statement: Statement
): PendingQueryResult {.
    deprecated: "This method is scheduled for removal in a future release"
.} =
  ## Executes the prepared statement with the given bound parameters, and returns a pending result.
  ##
  ## This pending result will create a streaming result when executed.
  ## The pending result represents an intermediate structure for a query that is not yet fully executed.
  result = PendingQueryResult(nil)
  check(
    duckdbPendingPreparedStreaming(statement, result.addr),
    "Failed to execute the pending prepared streaming statement",
    `=destroy`(result),
  )

proc columnCount*(
    qresult: QueryResult
): int {.
    inline, deprecated: "This method is scheduled for removal in a future release"
.} =
  ## Returns the number of columns present in a the result object
  return duckdbColumnCount(qresult.addr).int

proc rowCount*(
    qresult: QueryResult
): int {.
    inline, deprecated: "This method is scheduled for removal in a future release"
.} =
  ## Returns the number of rows present in a the result object
  return duckdbRowCount(qresult.addr).int

proc chunkCount*(
    qresult: QueryResult
): int {.
    inline, deprecated: "This method is scheduled for removal in a future release"
.} =
  ## Returns the number of chunks present in a the result object
  return duckdbResultChunkCount(qresult).int

iterator columns*(qresult: QueryResult): Column =
  ## Iterates over all columns in a query result.
  for i in 0 ..< duckdbColumnCount(qresult.addr).int:
    yield newColumn(qresult, i)

iterator chunks*(qresult: QueryResult): DataChunk {.inline.} =
  ## Iterates over data chunks in a query result.
  ##
  ## The iterator fetches chunks sequentially, handling both streaming
  ## and materialized results.
  ## Each chunk contains a portion of the result set with all columns.
  let streaming = qresult.isStreaming
  var chunk: duckdbDataChunk
  while true:
    chunk = if streaming: duckdbStreamFetchChunk(qresult) else: duckdbFetchChunk(qresult)
    if chunk == nil:
      break
    yield newDataChunk(chunk)

proc fetchOne*(qresult: QueryResult): seq[Value] {.inline.} =
  ## Fetches the first row from a query result.
  ## **Note:**
  ## API is not yet finalized and may change in future versions
  for chunk in qresult.chunks:
    if chunk and chunk.len > 0:
      for i in 0 ..< len(chunk):
        result.add(chunk[i][0])
      break

proc fetchOneNamed*(qresult: QueryResult): Table[string, Value] =
  ## Fetches the first row from a query result as a named table.
  ## **Note:**
  ## API is not yet finalized and may change in future versions
  result = Table[string, Value]()
  let values = fetchOne((qresult))
  for col in qresult.columns:
    result[col.name] = values[col.idx]

iterator rows*(qresult: QueryResult): seq[Value] =
  ## Iterates over all rows in a query result.
  ##
  ## Processes the result set row by row, yielding each row as a sequence of Values.
  for chunk in qresult.chunks:
    let
      numColumns = len(chunk)
      numRows = len(chunk[0])

    for rowIdx in 0 ..< numRows:
      var row = newSeq[Value](numColumns)
      for colIdx in 0 ..< numColumns:
        row[colIdx] = chunk[colIdx][rowIdx]
      yield row

proc fetchAll*(qresult: QueryResult): seq[Vector] =
  ## Fetches all data from a query result as column vectors.
  ##
  ## **Warning:**
  ## This materializes the entire result set in memory. Use with caution for large datasets.
  ##
  ## **Note:**
  ## API is not yet finalized and may change in future versions
  let columns = qresult.columns.toSeq()

  var
    chunkVectors: seq[seq[Vector]] = @[]
    emptyQresult = true

  for chunk in qresult.chunks:
    emptyQresult = false
    var colVectors = newSeq[Vector](len(columns))
    for column in columns:
      colVectors[column.idx] = chunk[column.idx]
    chunkVectors.add(colVectors)

  if emptyQresult:
    result = newSeq[Vector](len(columns))
    for column in columns:
      result[column.idx] = newVector(column.kind, 0)
    return

  result = newSeq[Vector](len(columns))
  for column in columns:
    if chunkVectors.len == 1:
      result[column.idx] = chunkVectors[0][column.idx]
    else:
      result[column.idx] = chunkVectors[0][column.idx]
      for i in 1 ..< chunkVectors.len:
        result[column.idx] &= chunkVectors[i][column.idx]

when defined(features.nimdrake.arrow):
  proc fetchAsArrow*(conn: Connection, qresult: QueryResult): ArrowTable =
    let columns = qresult.columns.toSeq()

    let
      options = newArrowOptions(conn)
      schema = newArrowSchema(options, columns)
      gSchema = newSchema(cast[pointer](schema.addr))

    var recordBatches = newSeq[RecordBatch]()
    for chunk in qresult.chunks:
      let aArray = newArrowArray(options, chunk)
      recordBatches.add(newRecordBatch(aArray.addr, gSchema))
    result = newArrowTable(gSchema, recordBatches)

  macro fetchAsArrow*(call: untyped): untyped =
    # Expect the call to be in the form: conn.execute(...).fetchAsArrow()
    # We need to extract 'conn' from the execute call

    expectKind(call, nnkCall)

    let executeCall = call[0]
    expectKind(executeCall, nnkSym)

    let conn = call[1]

    let qresultSym = genSym(nskLet, "qresult")

    # Generate:
    # let qresult = conn.execute(...)
    # fetchAsArrow(conn, qresult)
    result = newStmtList(
      newLetStmt(qresultSym, call), newCall(ident("fetchAsArrow"), conn, qresultSym)
    )

proc fetchAllNamed*(qresult: QueryResult): OrderedTable[string, Vector] =
  ## Fetches all data from a query result as named column vectors.
  ##
  ## **Example:**
  ## ```nim
  ## let data = qresult.fetchAllNamed()
  ## echo "User IDs: ", data["user_id"]
  ## echo "Names: ", data["name"]
  ## ```
  ##
  ## **Warning:**
  ## This materializes the entire result set in memory. Use with caution for large datasets.
  ##
  ## **Note:**
  ## API is not yet finalized and may change in future versions
  let
    columns = qresult.columns.toSeq()
    data = fetchAll(qresult)

  for i, column in columns:
    result[column.name] = data[i]

proc df*(qresult: QueryResult): DataFrame =
  ## Converts a query result to a DataFrame.
  ##
  ## Creates a DataFrame object that provides a convinient way to plot
  ## the query result, mainly used for debugging
  ##
  ## **Warning:**
  ## This materializes the entire result set in memory.
  return newDataFrame(qresult.fetchAllNamed())

proc error*(qresult: QueryResult): string =
  ## Retrieves the error message from a query result.
  ##
  ## If a query execution failed, this procedure returns the error message
  ## describing what went wrong during execution.
  return $duckdbResultError(qresult.addr)

proc error*(pqresult: PendingQueryResult): string =
  ## Retrieves the error message from a pending query result.
  ##
  ## If a pending query execution failed, this procedure returns the error message
  ## describing what went wrong during execution.
  return $duckdbPendingError(pqresult)

proc `$`*(qresult: QueryResult): string =
  ## Converts a query result to its string representation.
  ##
  ## Provides a human-readable string representation of the query result
  ## Most used for debugging
  return $qresult.df()
