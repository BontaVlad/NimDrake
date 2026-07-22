import unittest2

when defined(features.nimdrake.arrow):
  import narrow
  import ../../src/[database, query, arrow, display, narrow_table_scan]

  suite "QResult — Arrow toArrowStream":
    test "basic streaming converts int column correctly":
      let conn = newDatabase().connect()
      var stmt = conn.newStatement(
        "SELECT seq FROM generate_series(1, 100) AS t(seq)"
      )
      var qrs = conn.execute(stmt)
      var totalRows = 0'i64
      var values: seq[int64] = @[]
      for batch in toArrowStream(qrs):
        totalRows += batch.nRows
        let arr = batch[0, int64]
        values.add arr.toSeq
      check totalRows == 100
      var expected = newSeq[int64](100)
      for i in 0 ..< 100: expected[i] = int64(i + 1)
      check values == expected

    test "schema has correct column count":
      let conn = newDatabase().connect()
      var stmt = conn.newStatement(
        "SELECT 1::BIGINT AS i, 'x'::VARCHAR AS s, true AS b"
      )
      var qrs = conn.execute(stmt)
      for batch in toArrowStream(qrs):
        let s = batch.schema
        check s.nFields == 3
        check batch.nColumns == 3
        check batch[0, int64][0] == 1'i64
        check batch[1, string][0] == "x"
        check batch[2, bool][0] == true

    test "multiple data types decode correctly":
      let conn = newDatabase().connect()
      var stmt = conn.newStatement("""
        SELECT
          42::BIGINT   AS bigint_col,
          'hello'      AS varchar_col,
          1.5::DOUBLE  AS double_col,
          true         AS bool_col
      """)
      var qrs = conn.execute(stmt)
      for batch in toArrowStream(qrs):
        check batch.nRows == 1
        check batch[0, int64][0] == 42'i64
        check batch[1, string][0] == "hello"
        check batch[2, float64][0] == 1.5
        check batch[3, bool][0] == true

    test "null handling":
      let conn = newDatabase().connect()
      var stmt = conn.newStatement("""
        SELECT
          CASE WHEN seq % 2 = 0 THEN seq ELSE NULL END AS maybe_int
        FROM generate_series(1, 10) AS t(seq)
      """)
      var qrs = conn.execute(stmt)
      for batch in toArrowStream(qrs):
        let arr = batch[0, int64]
        check arr.nNulls == 5
        var nullCount, okCount = 0
        for i in 0 ..< arr.len:
          if arr.isNull(i): inc nullCount
          else: inc okCount
        check nullCount == 5
        check okCount == 5
        check arr.isNull(0)  == true   # seq=1 is odd → NULL
        check arr.isNull(1)  == false  # seq=2 is even → 2
        check arr[1]         == 2

    test "multi-batch streaming spans many rows":
      let conn = newDatabase().connect()
      var stmt = conn.newStatement(
        "SELECT seq FROM generate_series(1, 6000) AS t(seq)"
      )
      var qrs = conn.execute(stmt)
      var totalRows = 0'i64
      var batchCount = 0
      var firstVal, lastVal: int64
      var seenFirst = false
      for batch in toArrowStream(qrs):
        inc batchCount
        totalRows += batch.nRows
        let arr = batch[0, int64]
        if not seenFirst:
          firstVal = arr[0]
          seenFirst = true
        lastVal = arr[arr.len - 1]
      check batchCount >= 2
      check totalRows == 6000
      check firstVal == 1
      check lastVal == 6000

    test "empty result set produces no batches":
      let conn = newDatabase().connect()
      var stmt = conn.newStatement(
        "SELECT 1 AS i WHERE false"
      )
      var qrs = conn.execute(stmt)
      var batchCount = 0
      for batch in toArrowStream(qrs):
        inc batchCount
      check batchCount == 0

    test "varchar columns decode correctly":
      let conn = newDatabase().connect()
      var stmt = conn.newStatement(
        "SELECT 'item_' || seq::VARCHAR AS label FROM generate_series(1, 3) AS t(seq)"
      )
      var qrs = conn.execute(stmt)
      for batch in toArrowStream(qrs):
        let arr = batch[0, string]
        check arr.toSeq == @["item_1", "item_2", "item_3"]

    test "double and float columns decode correctly":
      let conn = newDatabase().connect()
      var stmt = conn.newStatement("""
        SELECT
          1.5::DOUBLE AS d,
          2.5::FLOAT  AS f
      """)
      var qrs = conn.execute(stmt)
      for batch in toArrowStream(qrs):
        check batch[0, float64][0] == 1.5
        check batch[1, float32][0] == 2.5'f32

    test "schema column names match DuckDB metadata":
      let conn = newDatabase().connect()
      var stmt = conn.newStatement(
        "SELECT 1::BIGINT AS first_col, 'x'::VARCHAR AS middle_col, true AS last_col"
      )
      var qrs = conn.execute(stmt)
      for batch in toArrowStream(qrs):
        let s = batch.schema
        check s.nFields == 3
        check s[0].name == "first_col"
        check s[1].name == "middle_col"
        check s[2].name == "last_col"
        check batch.getColumnName(0) == "first_col"
        check batch.getColumnName(1) == "middle_col"
        check batch.getColumnName(2) == "last_col"

    test "boolean columns decode correctly":
      let conn = newDatabase().connect()
      var stmt = conn.newStatement(
        "SELECT seq % 2 = 0 AS is_even FROM generate_series(1, 4) AS t(seq)"
      )
      var qrs = conn.execute(stmt)
      for batch in toArrowStream(qrs):
        let arr = batch[0, bool]
        check arr.toSeq == @[false, true, false, true]

    test "materialized: basic integer streaming via macro":
      let conn = newDatabase().connect()
      conn.execute("CREATE TABLE tm (n BIGINT)")
      for i in 1..5:
        conn.execute("INSERT INTO tm VALUES (" & $i & ")")
      var batchCount = 0
      let stmt = conn.newStatement("SELECT * FROM tm ORDER BY n")
      for batch in conn.execute(stmt).toArrowStream():
        let arr = batch[0, int64]
        check arr.toSeq == @[1'i64, 2, 3, 4, 5]
        inc batchCount
      check batchCount == 1

    test "materialized: multi-batch large result":
      let conn = newDatabase().connect()
      var batchCount = 0
      var total = 0
      let stmt = conn.newStatement("SELECT generate_series::BIGINT AS n FROM generate_series(1, 6000)")
      for batch in conn.execute(stmt).toArrowStream():
        total += batch[0, int64].len
        inc batchCount
      check total == 6000
      check batchCount >= 2

    test "materialized: schema column names":
      let conn = newDatabase().connect()
      let stmt = conn.newStatement("SELECT 1::BIGINT AS first_col, 'x'::VARCHAR AS middle_col, true AS last_col")
      for batch in conn.execute(stmt).toArrowStream():
        let s = batch.schema
        check s.nFields == 3
        check s[0].name == "first_col"
        check s[1].name == "middle_col"
        check s[2].name == "last_col"

    test "materialized: varchar and double decode":
      let conn = newDatabase().connect()
      conn.execute("CREATE TABLE tv (label VARCHAR, val DOUBLE)")
      conn.execute("INSERT INTO tv VALUES ('alpha', 1.5), ('beta', 2.5)")
      let stmt = conn.newStatement("SELECT * FROM tv ORDER BY label")
      for batch in conn.execute(stmt).toArrowStream():
        check batch[0, string].toSeq == @["alpha", "beta"]
        check batch[1, float64].toSeq == @[1.5, 2.5]

    test "materialized: empty result":
      let conn = newDatabase().connect()
      var batchCount = 0
      let stmt = conn.newStatement("SELECT 1 AS i WHERE false")
      for batch in conn.execute(stmt).toArrowStream():
        inc batchCount
      check batchCount == 0

    test "ToArrowTable: primitive and complex types":
      let query = """
        SELECT * FROM (
            VALUES
                (1::BIGINT, 'hello'::VARCHAR, 3.14::DOUBLE, true, [1,2,3]::INTEGER[], {'x':1,'y':2}::STRUCT(x INTEGER, y INTEGER), MAP {'a':1,'b':2}),
                (2::BIGINT, 'world'::VARCHAR, 2.71::DOUBLE, false, [4,5]::INTEGER[], {'x':3,'y':4}::STRUCT(x INTEGER, y INTEGER), MAP {'c':3})
        ) AS t(id, name, score, active, tags, point, attrs)
      """
      let conn = newDatabase().connect()
      let stmt = conn.newStatement(query)
      echo "/n"
      echo conn.execute(stmt).toArrowTable().newMaterialized(conn)
