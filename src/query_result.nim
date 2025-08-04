import std/[math, tables, sequtils]

import /[api, exceptions, datachunk, dataframe, types, vector]

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
  var chunk: duckdbDataChunk
  # this evaluates chunk types to many times, could
  # be a performance improvement
  while true:
    if qresult.isStreaming:
      chunk = duckdbStreamFetchChunk(qresult)
    else:
      chunk = duckdbFetchChunk(qresult)
    if chunk == nil:
      break
    yield newDataChunk(chunk)

proc fetchOne*(qresult: QueryResult): seq[Value] {.inline.} =
  ## Fetches the first row from a query result.
  ## **Note:**
  ## API is not yet finalized and may change in future versions
  var theOne = newSeq[Value]()
  for chunk in qresult.chunks:
    if chunk:
      for i in 0 .. len(chunk):
        theOne.add(chunk[i][0])
    break
  return theOne

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
  ## **Warning:**
  ## This materializes the entire result set in memory. Use with caution for large datasets.
  ##
  ## **Note:**
  ## API is not yet finalized and may change in future versions
  let columns = qresult.columns.toSeq()

  var
    all = newSeq[Vector](len(columns))
    emptyQresult = true

  for chunk in qresult.chunks:
    emptyQresult = false
    for column in columns:
      if isNil(all[column.idx]):
        all[column.idx] = chunk[column.idx]
      else:
        all[column.idx] &= chunk[column.idx]

  if emptyQresult:
    for column in columns:
      all[column.idx] = newVector(column.kind, 0)

  return all

proc fetchAllNamed*(qresult: QueryResult): OrderedTable[string, Vector] =
  ## Fetches all data from a query result as named column vectors.
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
