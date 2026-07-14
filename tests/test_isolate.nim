import unittest2
import std/[strutils, tables]
import decimal
import ../src/[database, query, qresult, codec, table, types, display]

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
      let cv = chunk.vector(0)
      let v = cv.bindAs DuckType.BigInt
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
      doAssert ten.len == chunk.len
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
    check r.columnCount == 1

  test "execute (prepared stmt) returns QResult[Streaming]":
    let duck = newDatabase().connect()
    var stmt = duck.newStatement("SELECT seq FROM generate_series(1, 5) AS t(seq)")
    var r = duck.execute(stmt)
    var sum = 0
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.BigInt)
      for i in 0 ..< v.len:
        sum += v[i]
    check sum == 15
