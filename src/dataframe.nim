import std/[os, tables, strutils, sequtils, sugar, strformat, enumerate]
import terminaltables
import /[types, vector, value]

type DataFrame* = ref object
  columns*: seq[Column]
  values*: seq[Vector]

proc newDataFrame*(data: Table[string, Vector]): DataFrame =
  let
    values = data.values.toSeq
    firstLength = values[0].len

  for child in values:
    if child.len != firstLength:
      raise newException(ValueError, "Value Vectors must have same lenght")

  var columns = newSeq[Column]()
  for idx, key in enumerate(data.keys):
    columns.add(
      Column(
        idx: idx,
        name: key,
        kind: values[idx].kind,
        logicalType: newLogicalType(values[idx].kind),
      )
    )
  result = DataFrame(columns: columns, values: values)

proc len*(df: DataFrame): int =
  result = len(df.values[0])

proc columnNames*(df: DataFrame): seq[string] =
  result = df.columns.map(c => c.name)

# TODO: temporary
iterator rows*(df: DataFrame): seq[Value] =
  let
    numColumns = len(df.columns)
    numRows = len(df)

  for rowIdx in 0 ..< numRows:
    var row = newSeq[Value](numColumns)
    for colIdx in 0 ..< numColumns:
      row[colIdx] = df.values[colIdx][rowIdx]
    yield row

proc clipString(str: string, at: int = 20): string =
  if len(str) > at:
    result = fmt"{str[0..at]}..."
  else:
    result = str

proc `[]`*(df: DataFrame, colIdx: int): Vector =
  result = df.values[colIdx]

proc `[]`*(df: DataFrame, colName: string): Vector =
  let colIdx = df.columns.filter(c => c.name == colName).map(c => c.idx)
  if len(colIdx) == 0:
    let validColumnNames = df.columns.map(c => c.name)
    raise newException(
      ValueError,
      fmt"Column with name {colName} does not exist, valid ones are {validColumnNames}",
    )
  result = df.values[colIdx[0]]

proc `$`*(df: DataFrame): string =
  var rows = df.rows.toSeq
  let
    showIndex = getEnv("display_show_index", "true").parseBool
    maxRows = getEnv("display_max_rows", "20").parseInt
    maxCols = min(getEnv("display_max_columns", "100").parseInt, len(df.columns))
    clipColName = getEnv("display_clip_column_name", "20").parseInt
    t = newUnicodeTable()

  var headers = df.columns[0 ..< maxCols].map(
    c => newCell(clipString(c.name, clipColName), pad = 5)
  )
  if showIndex:
    headers.insert(newCell("#", pad = 2), 0)
    for i, row in rows.mpairs:
      row.insert(newValue(i), 0)

  if len(rows) > maxRows:
    let
      middleIdx = len(rows) div 2
      padding = min(middleIdx div 2, 5)
      middleRow = newSeqWith(len(headers), newValue("..."))
    rows = rows[0 ..< padding] & middleRow & rows[len(rows) - padding .. ^1]

  t.setHeaders(headers)
  t.separateRows = false
  t.addRows(rows.toSeq.map(row => row.map(e => $e)))
  result = t.render()
