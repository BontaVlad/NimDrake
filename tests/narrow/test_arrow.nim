import unittest2
import ../../src/[ffi, database, query, query_result, arrow]

{.warning[Deprecated]: off.}

suite "Test Arrow query result":
  test "Test basic query this name should change":
    let conn = newDatabase().connect()
    let arrowTable = conn.execute("""
        SELECT
            *,
            COUNT(*) OVER () AS row_count,
            AVG(range) OVER () AS avg_value,
            MIN(range) OVER () AS min_value,
            MAX(range) OVER () AS max_value
        FROM range(3000);
    """).fetchAsArrow()
    # echo arrowTable
    # echo arrowTable.schema
    echo arrowTable.getColumnData(1)
    echo arrowTable[1]
    echo arrowTable["avg_value"]
    for k in arrowTable.keys:
      echo k
