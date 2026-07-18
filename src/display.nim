## Preview / display helpers for `QResult[Materialized]`.
##
## Provides `renderCell` and `$` (pretty-printed table preview) for query
## results. Separated from the core `qresult` module to isolate the
## `terminaltables` / `sequtils` display dependencies from the zero-copy
## view/query logic.

import std/[sequtils]
import terminaltables
import nint128
import uuid4

import /[ffi, qresult, types, codec]

const
  previewMaxRows = 20
  clipWidth = 20

proc clipStr(str: string, at: int): string =
  if len(str) > at:
    result = str[0 .. at] & "..."
  else:
    result = str

proc renderCell*(cv: ColumnView, i: int): string =
  ## Renders a single cell for display. Reads directly from `ColumnView`'s raw
  ## `data`/`validity`/`scale`/`width`/`enumWidth` fields without calling
  ## `bindAs`, avoiding per-cell field copies and ARC traffic on `chunk`.
  if not cv.valid(i):
    return "NULL"
  case cv.kind
  of DuckType.Boolean:
    result = $bool(cast[ptr UncheckedArray[uint8]](cv.data)[i])
  of DuckType.TinyInt:
    result = $cast[ptr UncheckedArray[int8]](cv.data)[i]
  of DuckType.SmallInt:
    result = $cast[ptr UncheckedArray[int16]](cv.data)[i]
  of DuckType.Integer:
    result = $cast[ptr UncheckedArray[int32]](cv.data)[i]
  of DuckType.BigInt:
    result = $cast[ptr UncheckedArray[int64]](cv.data)[i]
  of DuckType.UTinyInt:
    result = $cast[ptr UncheckedArray[uint8]](cv.data)[i]
  of DuckType.USmallInt:
    result = $cast[ptr UncheckedArray[uint16]](cv.data)[i]
  of DuckType.UInteger:
    result = $cast[ptr UncheckedArray[uint32]](cv.data)[i]
  of DuckType.UBigInt:
    result = $cast[ptr UncheckedArray[uint64]](cv.data)[i]
  of DuckType.Float:
    result = $cast[ptr UncheckedArray[float32]](cv.data)[i]
  of DuckType.Double:
    result = $cast[ptr UncheckedArray[float64]](cv.data)[i]
  of DuckType.Varchar, DuckType.Bit:
    result = decodeDuckString(addr cast[ptr UncheckedArray[duckdb_string_t]](cv.data)[i])
  of DuckType.HugeInt:
    result = $fromHugeInt(cast[ptr UncheckedArray[duckdb_hugeint]](cv.data)[i])
  of DuckType.UHugeInt:
    result = $fromUHugeInt(cast[ptr UncheckedArray[duckdb_uhugeint]](cv.data)[i])
  of DuckType.Decimal:
    result = $fromDuckDecimal(cv.scale, cv.width, cv.data, i)
  of DuckType.UUID:
    result = $fromDuckUuid(cast[ptr UncheckedArray[duckdb_hugeint]](cv.data)[i])
  else:
    result = "<" & $cv.kind & ">"

proc `$`*(q: QResult[Materialized]): string =
  let colCount = q.columnCount
  if colCount == 0:
    return ""

  var headerStrs = newSeq[string](colCount)
  for i in 0 ..< colCount:
    headerStrs[i] = clipStr(q.meta.columns[i].name, clipWidth)

  var t = newUnicodeTable()
  t.setHeaders(headerStrs.mapIt(newCell(it, pad = 5)))
  t.separateRows = false

  var rowCount = 0
  block outer:
    for chunk in q:
      let chunkLen = chunk.len
      var cvs = newSeq[ColumnView](colCount)
      for ci in 0 ..< colCount:
        cvs[ci] = chunk.vector(ci)
      for ri in 0 ..< chunkLen:
        if rowCount >= previewMaxRows:
          break outer
        var row = newSeq[string](colCount)
        for ci in 0 ..< colCount:
          row[ci] = renderCell(cvs[ci], ri)
        t.addRow(row)
        inc rowCount

  if q.rlen > previewMaxRows:
    t.addRow(newSeq[string](colCount))
  result = t.render()
