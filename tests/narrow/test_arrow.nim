import std/sequtils
import unittest2

when defined(features.nimdrake.arrow):
  import ../../src/[database, query, qresult, arrow]
  import narrow/tabular/table
  import narrow/column/primitive

  {.warning[Deprecated]: off.}

  suite "Test Arrow query result":
    test "toArrow returns a valid ArrowTable":
      echo "connecting"
      let conn = newDatabase().connect()
      let qr = conn.execute("""
          SELECT
              *,
              COUNT(*) OVER () AS row_count,
              AVG(range) OVER () AS avg_value,
              MIN(range) OVER () AS min_value,
              MAX(range) OVER () AS max_value
          FROM range(3000);
      """)
      let arrowTable = toArrow(conn, qr)
      check nRows(arrowTable) == 3000'i64
      let colData = getColumnData[int64](arrowTable, 0)
      check len(colData) == 3000
      check colData[0] == 0
      check colData[2999] == 2999

      check @(arrowTable["row_count", int64]) == newSeqWith(3000, 3000'i64)
