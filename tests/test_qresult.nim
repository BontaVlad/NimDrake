import unittest2
import std/[strutils, tables]
import decimal
import ../src/[database, query, qresult, codec, table, types]

suite "QResult zero-copy API":
  test "construction + metadata":
    let duck = newDatabase().connect()
    let r = duck.execute(
      """ SELECT seq AS int_col,
                'Value_' || seq::VARCHAR AS varchar_col
         FROM generate_series(1, 293200) AS t(seq) """
    )
    var totalRows = 0
    for chunk in r:
      totalRows += chunk.len
    check totalRows == 293200
    check r.columnCount == 2
    check r.columnName(0) == "int_col"
    check r.columnKind(1) == DuckType.Varchar
    check r.columnIndex("int_col") == 0
    check r.columnIndex("varchar_col") == 1
    check r.column("varchar_col").kind == DuckType.Varchar
    var seen = 0
    for c in r.columns:
      inc seen
    check seen == 2

  test "chunk iteration + zero-copy scalar access (BigInt)":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT seq FROM generate_series(1, 10) AS t(seq)"
    )
    var collected: seq[int64] = @[]
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.BigInt
      doAssert v.len == chunk.len
      for i in 0 ..< v.len:
        collected.add v[i]
    check collected == @[1'i64, 2, 3, 4, 5, 6, 7, 8, 9, 10]

  test "bindAs convenience on DataChunk":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT seq FROM generate_series(1, 5) AS t(seq)"
    )
    var collected: seq[int64] = @[]
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.BigInt)
      for i in 0 ..< v.len:
        collected.add v[i]
    check collected == @[1'i64, 2, 3, 4, 5]

  test "bindAs by name":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT seq AS id, seq * 10 AS ten FROM generate_series(1, 3) AS t(seq)"
    )
    for chunk in r:
      let ten = chunk.bindAs("ten", DuckType.BigInt)
      check ten[0] == 10
      check ten[1] == 20
      check ten[2] == 30

  test "chunk[string] syntactic sugar":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT seq AS id FROM generate_series(1, 3) AS t(seq)"
    )
    for chunk in r:
      let v = chunk["id"].bindAs DuckType.BigInt
      check v[0] == 1
      check v[1] == 2
      check v[2] == 3

  test "QResult[Streaming] to Q[Materialized]":
    let duck = newDatabase().connect()
    let stream = duck.execute(newStatement(duck,
      "SELECT seq AS id FROM generate_series(1, 3) AS t(seq)"
    ))
    let q = stream.materialize()
    let table = initTable(q)
    check table.bindAs("id", DuckType.BigInt).toSeq() == @[1'i64, 2, 3]

  test "varchar bulk decode via toSeq":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT 'V' || seq::VARCHAR FROM generate_series(1, 5) AS t(seq)"
    )
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Varchar
      let strs = v.toSeq
      check strs == @["V1", "V2", "V3", "V4", "V5"]

  test "borrow() avoids allocation":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT 'hello' AS s, 'world!' AS t"
    )
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Varchar
      let b = v.borrow(0)
      check b.len == 5
      check b.toString() == "hello"
      let v2 = chunk.vector(1).bindAs DuckType.Varchar
      check v2.borrow(0).toString() == "world!"

  test "validity mask handles nulls":
    let duck = newDatabase().connect()
    let r = duck.execute("""
      SELECT
        CASE WHEN seq % 2 = 0 THEN seq ELSE NULL END AS maybe_int,
        seq
      FROM generate_series(1, 10) AS t(seq)
    """)
    var
      nullCount = 0
      okCount = 0
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.BigInt
      for i in 0 ..< v.len:
        if v.valid(i):
          inc okCount
        else:
          inc nullCount
    check nullCount == 5
    check okCount == 5

  test "validity default-fill on toSeq":
    let duck = newDatabase().connect()
    let r = duck.execute("""
      SELECT CASE WHEN seq % 2 = 0 THEN seq ELSE NULL END
      FROM generate_series(1, 5) AS t(seq)
    """)
    var expected: seq[int64] = @[0'i64, 2, 0, 4, 0]
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.BigInt
      let s = v.toSeq
      check s == expected

  test "bindAs raises on kind mismatch":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT 1 AS i")
    for chunk in r:
      let cv = chunk.vector(0)
      expect(ValueError):
        discard cv.bindAs DuckType.Varchar

  test "vector lookup by name":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT seq AS id, seq * 10 AS ten FROM generate_series(1, 3) AS t(seq)"
    )
    for chunk in r:
      let ten = chunk.vector("ten").bindAs DuckType.BigInt
      let theOtherTen = chunk["ten"].bindAs DuckType.BigInt
      check ten.len == chunk.len
      check ten == theOtherTen
      check ten[0] == 10
      check ten[1] == 20
      check ten[2] == 30

  test "double, float, decimal decode":
    let duck = newDatabase().connect()
    let r = duck.execute("""
      SELECT 1.5::DOUBLE AS d, 0.42::DECIMAL(4,2) AS dec, 2.5::FLOAT AS f
    """)
    for chunk in r:
      let d = chunk.vector(0).bindAs DuckType.Double
      let dec = chunk.vector(1).bindAs DuckType.Decimal
      let f = chunk.vector(2).bindAs DuckType.Float
      check d[0] == 1.5
      check $dec[0] == "0.42"
      check f[0] == 2.5'f32

  test "string $":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT 1 AS i, 'x' AS s")
    let colStr = $r.column(0)
    check "Column" in colStr
    check "i" in colStr
    let resStr = $r
    check "1" in resStr
    check "x" in resStr

  test "materialized iteration via execute":
    let duck = newDatabase().connect()
    var r = duck.execute("SELECT seq FROM generate_series(1, 5) AS t(seq)")
    var sum = 0
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.BigInt)
      for i in 0 ..< v.len:
        sum += v[i]
    check sum == 15

  test "init table from streaming result":
    let conn = newDatabase().connect()
    let stmt = conn.newStatement("SELECT seq FROM generate_series(1, 5) AS t(seq)")
    let r = conn.execute(stmt)
    let tbl = initTable(r)
    check tbl.bindAs("seq", DuckType.BigInt).toSeq() == @[1'i64, 2, 3, 4, 5]

  test "cross-chunk Table random access — BigInt":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT seq FROM generate_series(1, 4100) AS t(seq)"
    )
    let t = initTable(r)
    let v = t.bindAs("seq", DuckType.BigInt)
    check v.len == 4100
    check v[0] == 1
    check v[2047] == 2048
    check v[2048] == 2049
    check v[2049] == 2050
    check v[4099] == 4100

  test "cross-chunk Table toSeq — BigInt":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT seq FROM generate_series(1, 5) AS t(seq)"
    )
    let t = initTable(r)
    let v = t.bindAs("seq", DuckType.BigInt)
    check v.toSeq == @[1'i64, 2, 3, 4, 5]

  test "cross-chunk ColumnVector items — BigInt":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT seq FROM generate_series(1, 3000) AS t(seq)"
    )
    let t = initTable(r)
    var
      last: int64 = 0
      count = 0
    for x in t.bindAs("seq", DuckType.BigInt):
      inc count
      last = x
    check count == 3000
    check last == 3000

  test "cross-chunk Table — Varchar toSeq":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT 'V' || seq::VARCHAR AS s FROM generate_series(1, 5) AS t(seq)"
    )
    let t = initTable(r)
    let v = t.bindAs("s", DuckType.Varchar)
    check v.toSeq == @["V1", "V2", "V3", "V4", "V5"]

  test "cross-chunk Table borrow":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT 'hello' AS s FROM generate_series(1, 1) AS t(seq)"
    )
    let t = initTable(r)
    let v = t.bindAs("s", DuckType.Varchar)
    check v.borrow(0).toString() == "hello"

  test "cross-chunk Table index out of bounds":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT 1::BIGINT AS x")
    let t = initTable(r)
    let v = t.bindAs("x", DuckType.BigInt)
    expect(IndexDefect):
      discard v[1]

  test "cross-chunk Table nonzero column":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT 1::BIGINT AS i")
    expect(ValueError):
      discard initTable(r).bindAs("i", DuckType.Varchar)

  test "cross-chunk Table nonexistent column":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT 1::BIGINT AS i")
    expect(KeyError):
      discard initTable(r).bindAs("nope", DuckType.BigInt)

  test "cross-chunk Table handles nulls":
    let duck = newDatabase().connect()
    let r = duck.execute("""
      SELECT CASE WHEN seq % 2 = 0 THEN seq ELSE NULL END AS maybe_int
      FROM generate_series(1, 3000) AS t(seq)
    """)
    let t = initTable(r)
    let v = t.bindAs("maybe_int", DuckType.BigInt)
    var
      nullCount = 0
      okCount = 0
    for i in 0 ..< v.len:
      if v.valid(i):
        inc okCount
      else:
        inc nullCount
    check nullCount == 1500
    check okCount == 1500

  test "execute (raw query) returns QResult[Materialized]":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT 1 AS i")
    check $typedesc(r) == $typedesc(QResult[Materialized])

  test "execute (prepared stmt) returns QResult[Streaming]":
    let duck = newDatabase().connect()
    var stmt = duck.newStatement("SELECT seq FROM generate_series(1, 5) AS t(seq)")
    var r = duck.execute(stmt)
    check $typedesc(r) == $typedesc(QResult[Streaming])

# ---------------------------------------------------------------------------
# Boolean
# ---------------------------------------------------------------------------
suite "QResult — Boolean":
  test "decode + toSeq":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT seq % 2 = 0 FROM generate_series(1, 6) AS t(seq)"
    )
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Boolean
      check v[0] == false
      check v[1] == true
      check v[2] == false
      check v.toSeq == @[false, true, false, true, false, true]

  test "nulls handle via validity":
    let duck = newDatabase().connect()
    let r = duck.execute("""
      SELECT CASE WHEN seq % 2 = 0 THEN (seq % 4 = 0) ELSE NULL END
      FROM generate_series(1, 4) AS t(seq)
    """)
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Boolean
      check v.valid(0) == false
      check v[1] == false
      check v.valid(2) == false
      check v[3] == true

# ---------------------------------------------------------------------------
# TimestampTz
# ---------------------------------------------------------------------------
suite "QResult — TimestampTz":
  test "decode":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT TIMESTAMP WITH TIME ZONE '2020-01-01 12:00:00+00'"
    )
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.TimestampTz
      let z = v[0]
      check z.utcOffset == 0
      check z.isDst == false
      check v.toSeq.len == 1

# ---------------------------------------------------------------------------
# List — Value bridge
# ---------------------------------------------------------------------------
suite "QResult — List (zero-copy descent)":
  test "listEntry + listChild bindAs BigInt":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT [seq, seq + 1] FROM generate_series(1, 5) AS t(seq)"
    )
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.List
      let child = v.listChild.bindAs DuckType.BigInt
      for i in 0 ..< v.len:
        let (off, ln) = v.listEntry(i)
        check int(ln) == 2
        check child[int(off)] == int64(i + 1)
        check child[int(off) + 1] == int64(i + 2)

  test "descent returns correct child kind":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT ['hello', 'world']"
    )
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.List
      check v.listChild.kind == DuckType.Varchar
      let child = v.listChild.bindAs DuckType.Varchar
      let (off, ln) = v.listEntry(0)
      check int(ln) == 2
      check child[int(off)] == "hello"
      check child[int(off) + 1] == "world"

# ---------------------------------------------------------------------------
# Array
# ---------------------------------------------------------------------------
suite "QResult — Array":
  test "arrayChild + arraySize":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT ARRAY[10, 20, 30]::INT[3]"
    )
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Array
      check v.arraySize == 3
      let child = v.arrayChild.bindAs DuckType.Integer
      check child[0] == 10
      check child[1] == 20
      check child[2] == 30

# ---------------------------------------------------------------------------
# Struct
# ---------------------------------------------------------------------------
suite "QResult — Struct":
  test "structChildCount + zero-copy descent":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT {'a': 100, 'b': 'hello'} AS s"
    )
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Struct
      check v.structChildCount == 2
      let name0 = v.structChildName(0)
      let name1 = v.structChildName(1)
      check (name0 == "a" and name1 == "b") or (name0 == "b" and name1 == "a")
      let childA = v.structChild("a")
      check childA.kind == DuckType.Integer
      check childA.bindAs(DuckType.Integer)[0] == 100
      let childB = v.structChild("b")
      check childB.bindAs(DuckType.Varchar)[0] == "hello"

  test "structChild by name raises on missing":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT {'a': 1} AS s"
    )
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Struct
      expect(KeyError):
        discard v.structChild("nope")

# ---------------------------------------------------------------------------
# Map
# ---------------------------------------------------------------------------
suite "QResult — Map":
  test "mapKeyType + mapValueType":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT MAP(['k1'], [42])"
    )
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Map
      check v.mapKeyType != nil
      check v.mapValueType != nil
      check $v.mapKeyType == "Varchar"
      check $v.mapValueType == "Integer"

  test "mapEntriesChild + zero-copy descent":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT MAP(['a', 'b'], [1, 2])"
    )
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Map
      let entries = v.mapEntriesChild
      check entries.kind == DuckType.Struct
      let entryStruct = entries.bindAs DuckType.Struct
      let keyChild = entryStruct.structChild(0).bindAs DuckType.Varchar
      let valChild = entryStruct.structChild(1).bindAs DuckType.Integer
      check keyChild[0] == "a"
      check valChild[0] == 1
      check keyChild[1] == "b"
      check valChild[1] == 2

# ---------------------------------------------------------------------------
# Union
# ---------------------------------------------------------------------------
suite "QResult — Union":
  test "unionMemberCount + unionMemberName":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT union_value(num := 1)"
    )
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Union
      check v.unionMemberCount >= 1
      check v.unionMemberName(0) == "num"

  test "unionMemberChild descent":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT union_value(num := 99)"
    )
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Union
      let child = v.unionMemberChild(0)
      check child.kind == DuckType.Integer
      check child.bindAs(DuckType.Integer)[0] == 99

# ---------------------------------------------------------------------------
# Arrow toArrowStream
# ---------------------------------------------------------------------------
when defined(features.nimdrake.arrow):
  import narrow

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
      echo conn.execute(stmt).toArrowTable()

  test "scalar() — NimValue":
    let duck = newDatabase().connect()
    let v = duck.execute("SELECT 42").scalar()
    check v.kind == nvInt
    check v.intVal == 42

  test "scalar() — static":
    let duck = newDatabase().connect()
    let v = duck.execute("SELECT 42").scalar(DuckType.Integer)
    check v == 42
