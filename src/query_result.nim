import std/[math, tables, sequtils]

import /[api, datachunk, dataframe, types, vector]

proc isStreaming(qresult: QueryResult): bool =
  return duckdbResultIsStreaming(qresult)

proc newColumn*(idx: int, name: string, kind: DuckType): Column =
  result = Column(idx: idx, name: name, kind: kind)

proc newColumn(qresult: QueryResult, idx: int): Column =
  result = newColumn(
    idx = idx,
    name = $duckdbColumnName(qresult.addr, idx.idx_t),
    kind = newDuckType(duckdbColumnType(qresult.addr, idx.idx_t)),
  )

iterator columns(qresult: QueryResult): Column =
  for i in 0 ..< duckdbColumnCount(qresult.addr).int:
    yield newColumn(qresult, i)

iterator chunks(qresult: QueryResult): DataChunk {.inline.} =
  var chunk: duckdbDataChunk
  while true:
    if qresult.isStreaming:
      chunk = duckdbStreamFetchChunk(qresult)
    else:
      chunk = duckdbFetchChunk(qresult)
    if chunk == nil:
      break
    yield newDataChunk(chunk)

  # var vectors = newSeq[Vector](len(columns))
  # for col in columns:
  #   let
  #     vec = duckdbDataChunkGetVector(chunk.handle, col.idx.idx_t)
  #     chunkSize = duckdbDataChunkGetSize(chunk.handle).int
  #     logicalType = newLogicalType(duckdbColumnLogicalType(chunk.handle, col.idx.idx_t))
  #   vectors[col.idx] = newVector(vec, 0, chunkSize, col.kind, logicalType)
  # return vectors

# TODO: not great
# proc fetchOne*(qresult: QueryResult): seq[Value] {.inline.} =
#   result = newSeq[Value]()
#   for columnVector in fetchChunk(qresult, 0):
#     result.add(columnVector[0])

# iterator chunks*(qresult: QueryResult): seq[Vector] {.inline.} =
#   for i in 0 ..< duckdbResultChunkCount(qresult):
#     yield fetchChunk(qresult, i)

# iterator rows*(qresult: QueryResult): seq[Value] =
#   for chunk in qresult.chunks:
#     let
#       numColumns = len(chunk)
#       numRows = len(chunk[0])

#     for rowIdx in 0 ..< numRows:
#       var row = newSeq[Value](numColumns)
#       for colIdx in 0 ..< numColumns:
#         row[colIdx] = chunk[colIdx][rowIdx]
#       yield row

# # TODO: api not definitive
# proc fetchOneNamed*(qresult: QueryResult): Table[string, Value] =
#   result = Table[string, Value]()
#   let values = fetchOne((qresult))
#   for col in qresult.columns:
#     result[col.name] = values[col.idx]

# # TODO: api not definitive
proc fetchAll*(qresult: QueryResult): seq[Vector] =
  let columns = qresult.columns.toSeq()

  var all = newSeq[Vector](len(columns))
  for column in columns:
    all[column.idx] = newVector(column.kind)

  for chunk in qresult.chunks:
    for column in columns:
      all[column.idx] &= chunk[column.idx]
  return all

# # TODO: api not definitive
proc fetchAllNamed*(qresult: QueryResult): Table[string, Vector] =
  let
    columns = qresult.columns.toSeq()
    data = fetchAll(qresult)

  result = initTable[string, Vector]()
  for i, column in columns:
    result[column.name] = data[i]

proc df*(qresult: QueryResult): DataFrame =
  return newDataFrame(qresult.fetchAllNamed())

proc error*(qresult: QueryResult): string =
  return $duckdbResultError(qresult.addr)

proc `$`*(qresult: QueryResult): string =
  return $qresult.df()
