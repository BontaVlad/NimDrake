import unittest2
import ../../src/[database, query, query_result, arrow]
import narrow/tabular/table
import narrow/column/primitive

{.warning[Deprecated]: off.}

suite "Test Arrow query result":
  test "fetchAsArrow returns a valid ArrowTable":
    echo "connecting"
    let conn = newDatabase().connect()
    # let arrowTable = conn.execute("""
    #     SELECT
    #         *,
    #         COUNT(*) OVER () AS row_count,
    #         AVG(range) OVER () AS avg_value,
    #         MIN(range) OVER () AS min_value,
    #         MAX(range) OVER () AS max_value
    #     FROM range(3000);
    # """).fetchAsArrow()
    # echo arrowTable
    # check nRows(arrowTable) == 3000'i64
    # let colData = getColumnData[int64](arrowTable, 0)
    # check len(colData) == 3000
    # check colData[0] == 0
    # check colData[2999] == 2999
