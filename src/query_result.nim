import std/[math, tables]

import /[api, dataframe, types, vector]

proc isStreaming(qresult: QueryResult): bool =
  result = duckdb_result_is_streaming(qresult)

proc newColumn*(
    idx: int, name: string, logicalType: LogicalType, kind: DuckType
): Column =
  result = Column(idx: idx, name: name, logicalType: logicalType, kind: kind)

proc newColumn*(idx: int, name: string, kind: DuckType): Column =
  result = Column(idx: idx, name: name, logicalType: newLogicalType(kind), kind: kind)

proc newColumn(qresult: QueryResult, idx: idxt): Column =
  result = newColumn(
    idx = idx.int,
    name = $duckdb_column_name(qresult.addr, idx),
    logicalType = newLogicalType(duckdb_column_logical_type(qresult.addr, idx)),
    kind = newDuckType(duckdb_column_type(qresult.addr, idx)),
  )

# TODO: find out why if I make this an iterator it breaks with a double free, maybe a copy=?
proc columns(qresult: QueryResult): seq[Column] =
  let count = duckdb_column_count(qresult.addr)
  var cols = newSeq[Column](count)
  for i in 0 ..< count:
    cols[i] = newColumn(qresult, i)
  return cols

proc fetchChunk(qresult: QueryResult, idx: idx_t): seq[Vector] {.inline.} =
  let
    columns = qresult.columns
    chunk =
      if qresult.isStreaming:
        newDataChunk(qresult, columns)
      else:
        newDataChunk(qresult, idx, columns) # TODO: should check for empty

  var vectors = newSeq[Vector](len(columns))
  for col in columns:
    let
      vec = duckdb_data_chunk_get_vector(chunk.handle, col.idx.idx_t)
      chunk_size = duckdb_data_chunk_get_size(chunk.handle).int
    vectors[col.idx] = newVector(vec, 0, chunk_size, col.kind, col.logicalType)
  return vectors

# TODO: not great
proc fetchOne*(qresult: QueryResult): seq[Value] {.inline.} =
  result = newSeq[Value]()
  for column_vector in fetchChunk(qresult, 0):
    result.add(column_vector[0])

iterator chunks*(qresult: QueryResult): seq[Vector] =
  for i in 0 ..< duckdb_result_chunk_count(qresult):
    yield fetchChunk(qresult, i)

iterator rows*(qresult: QueryResult): seq[Value] =
  for chunk in qresult.chunks:
    let
      numColumns = len(chunk)
      numRows = len(chunk[0])

    for rowIdx in 0 ..< numRows:
      var row = newSeq[Value](numColumns)
      for colIdx in 0 ..< numColumns:
        row[colIdx] = chunk[colIdx][rowIdx]
      yield row

# TODO: api not definitive
proc fetchOneNamed*(qresult: QueryResult): Table[string, Value] =
  result = Table[string, Value]()
  let values = fetchOne((qresult))
  for col in qresult.columns:
    result[col.name] = values[col.idx]

# TODO: api not definitive
proc fetchAll*(qresult: QueryResult): seq[Vector] =
  let columns = qresult.columns

  result = newSeq[Vector](len(columns))
  for column in columns:
    result[column.idx] = newVector(column.kind)

  for chunk in qresult.chunks:
    for column in columns:
      result[column.idx] &= chunk[column.idx]

# TODO: api not definitive
proc fetchAllNamed*(qresult: QueryResult): Table[string, Vector] =
  let
    columns = qresult.columns
    data = fetchAll(qresult)

  result = initTable[string, Vector]()
  for i, column in columns:
    result[column.name] = data[i]

proc df*(qresult: QueryResult): DataFrame =
  result = newDataFrame(qresult.fetchAllNamed())

proc error*(qresult: QueryResult): string =
  result = $duckdb_result_error(qresult.addr)

proc `$`*(qresult: QueryResult): string =
  result = $qresult.df()
