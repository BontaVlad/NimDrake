import std/[math, tables, sequtils]

import /[api, exceptions, datachunk, dataframe, types, vector]

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

proc newPendingResult*(statement: Statement): PendingQueryResult =
  result = PendingQueryResult(nil)
  check(
    duckdbPendingPrepared(statement, result.addr),
    "Failed to execute the pending prepared statement",
    `=destroy`(result)
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

proc fetchOne*(qresult: QueryResult): seq[Value] {.inline.} =
  var theOne = newSeq[Value]()
  for chunk in qresult.chunks:
    if chunk:
      for i in 0 .. len(chunk):
        theOne.add(chunk[i][0])
    break
  return theOne

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

# TODO: api not definitive
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

proc error*(pqresult: PendingQueryResult): string =
  return $duckdbPendingError(pqresult)

proc `$`*(qresult: QueryResult): string =
  return $qresult.df()
