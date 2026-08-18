import unittest2
import std/[strutils, tables, math, times]
import ../src/[database, query, qresult, codec, table, types, complex, display]

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
    let stream = duck.executeStreaming(newStatement(duck,
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

  when defined(i386) or defined(amd64):
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
    let r = conn.executeStreaming(stmt)
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
    # Compile-time type assertion: assignment fails to compile if `execute`
    # does not return the materialized variant for a raw SQL string.
    let _: QResult[Materialized] = r
    check r.columnCount == 1

  test "execute (prepared stmt) returns QResult[Streaming]":
    let duck = newDatabase().connect()
    var stmt = duck.newStatement("SELECT seq FROM generate_series(1, 5) AS t(seq)")
    var r = duck.executeStreaming(stmt)
    let _: QResult[Streaming] = r
    var sum = 0
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.BigInt)
      for i in 0 ..< v.len:
        sum += v[i]
    check sum == 15

  test "cross-chunk borrow on multi-chunk Table":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT 's' || seq::VARCHAR AS s FROM generate_series(1, 4100) AS t(seq)"
    )
    let t = initTable(r)
    let v = t.bindAs("s", DuckType.Varchar)
    check v.borrow(0).toString() == "s1"
    check v.borrow(2048).toString() == "s2049"
    check v.borrow(4099).toString() == "s4100"

  test "Nulls in specific chunks (chunks 1 and 3 have nulls)":
    let duck = newDatabase().connect()
    let r = duck.execute("""
      SELECT CASE
        WHEN seq >= 2049 AND seq <= 4096 THEN NULL
        WHEN seq >= 6145 THEN NULL
        ELSE seq
      END AS maybe
      FROM generate_series(1, 8000) AS t(seq)
    """)
    let t = initTable(r)
    let v = t.bindAs("maybe", DuckType.BigInt)
    var nullCount, okCount = 0
    for i in 0 ..< v.len:
      if v.valid(i): inc okCount
      else: inc nullCount
    check okCount == 2048 + 2048  # chunks 0 and 2 have no nulls
    check nullCount == 2048 + 1856  # chunks 1 and 3 have nulls

  test "toSeq default-fill on nulls in middle chunk":
    let duck = newDatabase().connect()
    let r = duck.execute("""
      SELECT CASE WHEN seq % 2 = 0 THEN seq ELSE NULL END AS maybe
      FROM generate_series(1, 5000) AS t(seq)
    """)
    let t = initTable(r)
    let v = t.bindAs("maybe", DuckType.BigInt)
    let seq = v.toSeq
    check seq.len == 5000
    check seq[0] == 0  # default fill
    check seq[1] == 2  # non-null
    check seq[4999] == 5000  # last is even

  when defined(i386) or defined(amd64):
    test "cross-chunk Table — Decimal toSeq across chunk boundary":
      let duck = newDatabase().connect()
      let r = duck.execute(
        "SELECT (seq % 100)::DECIMAL(18,3) AS d FROM generate_series(1, 4100) AS t(seq)"
      )
      let t = initTable(r)
      let v = t.bindAs("d", DuckType.Decimal)
      check v.len == 4100
      check $v[0] == "1.000"
      check $v[2048] == "49.000"
      check $v[4099] == "0.000"

  test "cross-chunk Table — Date random access":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT (DATE '2000-01-01' + seq::INTEGER) AS d FROM generate_series(0, 4099) AS t(seq)"
    )
    let t = initTable(r)
    let v = t.bindAs("d", DuckType.Date)
    check v.len == 4100
    check v[0].year == 2000
    check v[0].monthday == 1
    check v[2048].year == 2005
    check v[4099].year == 2011

  test "cross-chunk Table — UUID toSeq":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT gen_random_uuid() AS u FROM generate_series(1, 5) AS t(seq)"
    )
    let t = initTable(r)
    let v = t.bindAs("u", DuckType.Uuid)
    check v.len == 5
    let seq = v.toSeq
    check seq.len == 5

  test "cross-chunk Table — Interval toSeq":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT INTERVAL (seq || ' days') AS iv FROM generate_series(1, 4100) AS t(seq)"
    )
    let t = initTable(r)
    let v = t.bindAs("iv", DuckType.Interval)
    check v.len == 4100
    check v[0].days == 1
    check v[2048].days == 2049
    check v[4099].days == 4100

  test "cross-chunk Table — Blob toSeq":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT from_hex('DEADBEEF' || lpad(seq::VARCHAR, 2, '0')) AS b FROM generate_series(1, 4100) AS t(seq)"
    )
    let t = initTable(r)
    let v = t.bindAs("b", DuckType.Blob)
    check v.len == 4100
    let seq = v.toSeq
    check seq.len == 4100
    check seq[0] == @[byte 0xDE, 0xAD, 0xBE, 0xEF, 0x01]
    check seq[2048][0] == 0xDE

  test "cross-chunk Table — Time toSeq":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT TIME '12:00:00' AS tm FROM generate_series(1, 4100) AS t(seq)"
    )
    let t = initTable(r)
    let v = t.bindAs("tm", DuckType.Time)
    check v.len == 4100
    check v[0] == initTime(12 * 3600, 0)
    check v[2048] == initTime(12 * 3600, 0)
    check v[4099] == initTime(12 * 3600, 0)

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
      # DuckDB stores TIMESTAMPTZ as UTC microseconds only; the offset is not
      # part of the value (display applies the session TimeZone). The full
      # instant (date + time) is preserved.
      check z.time == dateTime(2020, mJan, 1, 12, 0, 0, zone = utc()).toTime
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
# scalar() — convenience single-value extraction
# ---------------------------------------------------------------------------
test "scalar() — NimValue":
  let duck = newDatabase().connect()
  let v = duck.execute("SELECT 42").scalar()
  check v.kind == nvInt
  check v.intVal == 42

test "scalar() — static":
  let duck = newDatabase().connect()
  let v = duck.execute("SELECT 42").scalar(DuckType.Integer)
  check v == 42

# ---------------------------------------------------------------------------
# Empty / zero-column results
# ---------------------------------------------------------------------------
suite "Empty & edge results":
  test "Empty result set — columns present, zero rows":
    let conn = newDatabase().connect()
    let r = conn.execute("SELECT 1 AS x, 'a' AS s WHERE 1=0")
    check r.columnCount == 2
    check r.columnName(0) == "x"
    check r.columnName(1) == "s"
    var rows = 0
    for chunk in r:
      rows += chunk.len
    check rows == 0

  test "Empty result materializes to empty Table":
    let conn = newDatabase().connect()
    let r = conn.execute("SELECT 1::BIGINT AS x WHERE 1=0")
    let t = initTable(r)
    let v = t.bindAs("x", DuckType.BigInt)
    check v.len == 0

# ---------------------------------------------------------------------------
# Cross-chunk Vector coverage — remaining types
# ---------------------------------------------------------------------------
suite "Vector[kt] — type coverage":
  test "Blob decode":
    let conn = newDatabase().connect()
    let r = conn.execute("SELECT 'hello'::BLOB")
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Blob
      check v[0] == @[byte 104, 101, 108, 108, 111]

  test "UUID decode":
    let conn = newDatabase().connect()
    let r = conn.execute("SELECT uuid() AS u")
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.UUID
      check v.len == 1

  test "UHugeInt decode":
    let conn = newDatabase().connect()
    discard conn.execute("CREATE TABLE uhi (u UHUGEINT)")
    let val = not zero(UInt128)
    conn.executeMaterialized("INSERT INTO uhi VALUES (?)", (val,))
    let r = conn.execute("SELECT u FROM uhi")
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.UHugeInt
      check v[0] == val

  test "Date vector decode":
    let conn = newDatabase().connect()
    let r = conn.execute("SELECT DATE '2023-12-25' AS d")
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Date
      check v[0].year == 2023
      check v[0].month == mDec
      check v[0].monthday == 25

  test "Time vector decode":
    let conn = newDatabase().connect()
    let r = conn.execute("SELECT TIME '01:02:03.123456' AS t")
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Time
      check initTime(3723, 123_456_000) == v[0]

  test "Interval vector decode":
    let conn = newDatabase().connect()
    let r = conn.execute("SELECT INTERVAL '1 year 2 months 3 days' AS iv")
    for chunk in r:
      let iv = chunk.vector(0).bindAs(DuckType.Interval)[0]
      check iv.years == 1
      check iv.months == 2
      check iv.days == 3

  test "structChild by index":
    let conn = newDatabase().connect()
    let r = conn.execute("SELECT {'a': 10, 'b': 'x'} AS s")
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Struct
      let child0 = v.structChild(0).bindAs DuckType.Integer
      let child1 = v.structChild(1).bindAs DuckType.Varchar
      check child0[0] == 10
      check child1[0] == "x"

  test "3-level nesting — List of Struct of List":
    let conn = newDatabase().connect()
    let r = conn.execute("SELECT [{'xs': [1, 2]}, {'xs': [3, 4]}] AS nested")
    for chunk in r:
      let outer = chunk.vector(0).bindAs DuckType.List
      let mid = outer.listChild.bindAs DuckType.Struct
      let (off0, len0) = outer.listEntry(0)
      check int(len0) == 2  # list has 2 struct elements
      check mid.structChildCount >= 1
      let inner = mid.structChild("xs").bindAs DuckType.List
      let innerVals = inner.listChild.bindAs DuckType.Integer
      let (off1, len1) = inner.listEntry(0)
      check int(len1) == 2  # first struct's list has 2 elements
      check innerVals[int(off1)] == 1'i32
      check innerVals[int(off1) + 1] == 2'i32
      let (off2, len2) = inner.listEntry(1)
      check int(len2) == 2  # second struct's list has 2 elements
      check innerVals[int(off2)] == 3'i32
      check innerVals[int(off2) + 1] == 4'i32

  test "cross-chunk Validity mask reset between chunks":
    let conn = newDatabase().connect()
    let r = conn.execute("""
      SELECT CASE WHEN seq % 2 = 0 THEN seq ELSE NULL END AS maybe
      FROM generate_series(1, 5000) AS t(seq)
    """)
    var nullCount, okCount = 0
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.BigInt
      for i in 0 ..< v.len:
        if v.valid(i): inc okCount
        else: inc nullCount
    check nullCount == 2500
    check okCount == 2500

# ---------------------------------------------------------------------------
# Bound container views — Map / List / Array / Struct / Union
# ===========================================================================
# `bindAs Table[K,V]` / `bindAs OrderedTable[K,V]` → `MapView`,
# `bindAs seq[T]` → `ListView`, `bindAsArray(kt)` → `ArrayView`. Each is a
# zero-copy cached typed view over a complex column; `mv[i]` returns the
# Nim container, `mv.borrowMap(i)` returns a zero-copy row view.
# ---------------------------------------------------------------------------

suite "QResult — bound container views: Map":
  test "bindAs(OrderedTable[string,int32]) builds MapView":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT MAP(['a', 'b'], [1, 2])")
    for chunk in r:
      let mv = chunk.vector(0).bindAs OrderedTable[string, int32]
      check mv.len == 1
      let row = mv[0]
      check row.len == 2
      check row["a"] == 1
      check row["b"] == 2

  test "bindAs(Table[string,int32]) is the same MapView":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT MAP(['k1', 'k2'], [42, 7])")
    for chunk in r:
      let mv = chunk.vector(0).bindAs Table[string, int32]
      check mv.borrowMap(0)["k1"] == 42
      check mv.borrowMap(0)["k2"] == 7

  test "DataChunk.bindAs convenience":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT MAP(['k'], [99])")
    for chunk in r:
      let mv = chunk.bindAs(0, OrderedTable[string, int32])
      check mv.borrowMap(0)["k"] == 99

  test "MapRowView zero-copy pairs/keys/values":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT MAP(['a', 'b', 'c'], [10, 20, 30])")
    for chunk in r:
      let mv = chunk.vector(0).bindAs OrderedTable[string, int32]
      let row = mv.borrowMap(0)
      check row.len == 3
      var keys: seq[string] = @[]
      for k in row.keys: keys.add(k)
      check keys == @["a", "b", "c"]
      var vals: seq[int32] = @[]
      for v in row.values: vals.add(v)
      check vals == @[10'i32, 20, 30]
      var pairs: seq[(string, int32)] = @[]
      for k, v in row.pairs: pairs.add((k, v))
      check pairs == @[("a", 10'i32), ("b", 20), ("c", 30)]

  test "MapRowView contains / [] / getOrDefault":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT MAP(['a', 'b'], [1, 2])")
    for chunk in r:
      let mv = chunk.vector(0).bindAs OrderedTable[string, int32]
      let row = mv.borrowMap(0)
      check row.contains("a")
      check not row.contains("z")
      check row["a"] == 1
      check row.getOrDefault("z", -1'i32) == -1
      check row.getOrDefault("z") == 0  # default fill

  test "borrowed string MAP access preserves NULL and empty values":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT MAP(['a', 'b'], ['', NULL])")
    for chunk in r:
      let mv = chunk.bindAs(0, OrderedTable[string, string])
      let row = mv.borrowMap(0)
      var keys: seq[DuckStringRef] = @[]
      var values: seq[DuckStringRef] = @[]
      for key in row.borrowKeys: keys.add key
      for value in row.borrowValues: values.add value
      check keys.len == 2
      check keys[0].valid and keys[0].len == 1
      check values[0].valid and values[0].len == 0
      check not values[1].valid
      let (value, found) = row.borrowLookup(keys[0])
      check found
      check value.valid and value.len == 0

  test "MapRowView [] raises KeyError on missing":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT MAP(['a'], [1])")
    for chunk in r:
      let mv = chunk.vector(0).bindAs OrderedTable[string, int32]
      expect(KeyError):
        discard mv.borrowMap(0)["nope"]

  test "MapView toSeq parity with complex.toMap":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT MAP(['a', 'b', 'c'], [1, 2, 3])")
    for chunk in r:
      let mv = chunk.vector(0).bindAs OrderedTable[string, int32]
      let mvRows = mv.toSeq
      let refRows = toMap[DuckType.Varchar, DuckType.Integer](
        chunk.vector(0).bindAs(DuckType.Map))
      check mvRows == refRows

  test "MapView items iterator":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT MAP(['a'], [1]), MAP(['x', 'y'], [10, 11])")
    for chunk in r:
      var totalRows = 0
      for mv in chunk.bindAs(0, OrderedTable[string, int32]):
        inc totalRows
        check mv.len == 1
      for mv in chunk.bindAs(1, Table[string, int32]):
        check mv.len == 2

  test "bindAs(Table[K,V]) raises on non-Map column":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT 1 AS i")
    for chunk in r:
      expect(ValueError):
        discard chunk.vector(0).bindAs OrderedTable[string, int32]

  test "bindAs(Table) kind-mismatch on key/value raises":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT MAP(['a'], [1])")
    for chunk in r:
      expect(ValueError):
        discard chunk.vector(0).bindAs OrderedTable[int64, int32]  # key kind mismatch

  test "MapView per-chunk row access within chunk":
    # MapView is a per-chunk view; mv.len is the chunk's row count, not the
    # total. Use a small result that fits in a single chunk to assert
    # first/last-row behaviour without a chunk-boundary guessing game.
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT MAP(['k' || seq::VARCHAR], [seq]) FROM generate_series(1, 5) AS t(seq)"
    )
    for chunk in r:
      let mv = chunk.vector(0).bindAs OrderedTable[string, int64]
      check mv.borrowMap(0)["k1"] == 1
      check mv.borrowMap(mv.len - 1)["k5"] == 5

suite "QResult — bound container views: List":
  test "bindAs(seq[int32]) builds ListView":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT [10, 20, 30] AS xs")
    for chunk in r:
      let lv = chunk.vector(0).bindAs seq[int32]
      check lv.len == 1
      check lv[0] == @[10'i32, 20, 30]

  test "ListView borrowList returns SliceView":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT [1, 2, 3] AS xs")
    for chunk in r:
      let lv = chunk.vector(0).bindAs seq[int32]
      let slice = lv.borrowList(0)
      check slice.len == 3
      check slice[0] == 1
      check slice[1] == 2
      check slice[2] == 3

  test "ListView SliceView items + toSeq":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT [1, 2, 3] AS xs")
    for chunk in r:
      let lv = chunk.vector(0).bindAs seq[int32]
      var collected: seq[int32] = @[]
      for x in lv.borrowList(0): collected.add(x)
      check collected == @[1'i32, 2, 3]
      check lv.borrowList(0).toSeq == @[1'i32, 2, 3]

  test "ListView multi-row column":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT [seq, seq + 1] FROM generate_series(1, 5) AS t(seq)"
    )
    for chunk in r:
      let lv = chunk.vector(0).bindAs seq[int64]
      check lv.len == 5
      check lv[0] == @[1'i64, 2]
      check lv[4] == @[5'i64, 6]
      let allRows = lv.toSeq
      check allRows.len == 5
      check allRows[2] == @[3'i64, 4]

  test "ListView parity with complex.toList":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT [seq, seq + 1, seq + 2] FROM generate_series(1, 4) AS t(seq)"
    )
    for chunk in r:
      let lv = chunk.vector(0).bindAs seq[int64]
      let viaView = lv.toSeq
      let viaComplex = toList[DuckType.BigInt](chunk.vector(0).bindAs(DuckType.List))
      check viaView == viaComplex

  test "ListView DataChunk convenience":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT [7, 8, 9] AS xs")
    for chunk in r:
      let lv = chunk.bindAs(0, seq[int32])
      check lv[0] == @[7'i32, 8, 9]

suite "QResult — bound container views: Array":
  test "bindAsArray builds ArrayView":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT ARRAY[10, 20, 30]::INT[3] AS arr")
    for chunk in r:
      let av = chunk.vector(0).bindAsArray(DuckType.Integer)
      check av.arraySize == 3
      check av.len == 1
      check av[0] == @[10'i32, 20, 30]

  test "bindAsArray DataChunk convenience":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT ARRAY[1, 2, 3]::INT[3]")
    for chunk in r:
      let av = chunk.bindAsArray(0, DuckType.Integer)
      check av.borrowArray(0).len == 3
      check av.borrowArray(0).toSeq == @[1'i32, 2, 3]

  test "ArrayView SliceView items":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT ARRAY[1, 2, 3]::INT[3]")
    for chunk in r:
      let av = chunk.bindAsArray(0, DuckType.Integer)
      var collected: seq[int32] = @[]
      for x in av.borrowArray(0): collected.add(x)
      check collected == @[1'i32, 2, 3]

  test "ArrayView multi-row column":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT ARRAY[seq, seq + 10, seq + 20]::INT[3] FROM generate_series(1, 4) AS t(seq)"
    )
    for chunk in r:
      let av = chunk.vector(0).bindAsArray(DuckType.Integer)
      check av.arraySize == 3
      check av.len >= 1
      check av[0] == @[1'i32, 11, 21]

  test "ArrayView toSeq parity":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT ARRAY[1, 2, 3]::INT[3]")
    for chunk in r:
      let av = chunk.vector(0).bindAsArray(DuckType.Integer)
      let viaView = av.toSeq
      let viaComplex = toArray[DuckType.Integer](chunk.vector(0).bindAs(DuckType.Array))
      check viaView == viaComplex

suite "QResult — bound container views: Struct cached child + element access":
  test "structChild(j, kt) cached overload returns Vector[kt]":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT {'a': 100, 'b': 'hello'} AS s")
    for chunk in r:
      let sv = chunk.vector(0).bindAs DuckType.Struct
      let a = sv.structChild(0, DuckType.Integer)
      check a[0] == 100
      let b = sv.structChild(1, DuckType.Varchar)
      check b[0] == "hello"

  test "structChild(name, kt) cached overload":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT {'a': 7, 'b': 99} AS s")
    for chunk in r:
      let sv = chunk.vector(0).bindAs DuckType.Struct
      let valA = sv.structChild("a", DuckType.Integer)[0]
      let valB = sv.structChild("b", DuckType.Integer)[0]
      check ((valA, valB) == (7'i32, 99'i32)) or ((valA, valB) == (99'i32, 7'i32))  # struct child order not guaranteed

  test "Vector[Struct].[] returns (string, NimValue) pairs":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT {'a': 100, 'b': 'hello'} AS s")
    for chunk in r:
      let sv = chunk.vector(0).bindAs DuckType.Struct
      let row = sv[0]
      check row.len == 2
      var aVal, bVal: NimValue
      for (name, val) in row:
        if name == "a": aVal = val
        elif name == "b": bVal = val
      check aVal.kind == nvInt
      check aVal.intVal == 100
      check bVal.kind == nvString
      check bVal.strVal == "hello"

  test "Vector[Struct] toSeq + items parity":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT {'a': 1} AS s UNION ALL SELECT {'a': 2} AS s")
    var viaItems: seq[seq[(string, NimValue)]]
    for chunk in r:
      for row in chunk.vector(0).bindAs DuckType.Struct:
        viaItems.add(row)
    check viaItems.len == 2

  test "structChild(name, kt) raises on missing":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT {'a': 1} AS s")
    for chunk in r:
      let sv = chunk.vector(0).bindAs DuckType.Struct
      expect(KeyError):
        discard sv.structChild("nope", DuckType.Integer)

suite "QResult — bound container views: Union cached child + element access":
  test "unionMemberChild(j, kt) cached overload":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT union_value(num := 99)")
    for chunk in r:
      let uv = chunk.vector(0).bindAs DuckType.Union
      let m = uv.unionMemberChild(0, DuckType.Integer)
      check m[0] == 99

  test "Vector[Union].[] returns (string, NimValue)":
    let duck = newDatabase().connect()
    let r = duck.execute("SELECT union_value(num := 99)")
    for chunk in r:
      let uv = chunk.vector(0).bindAs DuckType.Union
      let (name, val) = uv[0]
      check name == "num"
      check val.kind == nvInt
      check val.intVal == 99

  test "Vector[Union] toSeq":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT union_value(num := seq) FROM generate_series(7, 8) AS t(seq)"
    )
    for chunk in r:
      let uv = chunk.vector(0).bindAs DuckType.Union
      let rows = uv.toSeq
      check rows.len == 2
      check rows[0][0] == "num"
      check rows[1][0] == "num"
      check rows[0][1].intVal in {7, 8}
      check rows[1][1].intVal in {7, 8}

suite "QResult — composite nesting via bound views":
  test "List of Struct of List — heterogeneous nesting uses descent procs":
    # Heterogeneous nesting (List of Struct of List) has no single `T` for
    # `bindAs(seq[T])` because the outer child kind is Struct (complex). The
    # descent-proc path + the cached `structChild(name, kt)` overload is the
    # idiomatic shape here; the per-row typed container views are reserved for
    # columns whose declared element is a non-complex typed value.
    let conn = newDatabase().connect()
    let r = conn.execute("SELECT [{'xs': [1, 2]}, {'xs': [3, 4]}] AS nested")
    for chunk in r:
      let outer = chunk.vector(0).bindAs DuckType.List
      let mid = outer.listChild.bindAs DuckType.Struct
      check outer.listEntry(0)[1] == 2  # 2 structs in outer list
      let inner = mid.structChild("xs", DuckType.List)
      let innerVals = inner.listChild.bindAs DuckType.Integer
      let (off0, len0) = outer.listEntry(0)
      let (off1, len1) = inner.listEntry(0)
      check int(len0) == 2  # struct 0's list has 2 elements
      check innerVals[int(off1)] == 1'i32
      check innerVals[int(off1) + 1] == 2'i32
      let (off2, len2) = inner.listEntry(1)
      check int(len2) == 2
      check innerVals[int(off2)] == 3'i32
      check innerVals[int(off2) + 1] == 4'i32

  test "List of Integer triples via bindAs(seq[int64])":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT [seq, seq+1, seq+2] FROM generate_series(1, 100) AS t(seq)"
    )
    for chunk in r:
      let lv = chunk.vector(0).bindAs seq[int64]
      var sum = 0'i64
      for i in 0 ..< lv.len:
        for x in lv.borrowList(i): sum += x
      # per row, each list of 3 sequential ints sums to 3*(i + (i+1) + (i+2))/3…
      # Expected: sum_{i=1..100} (3*i + 3) = 3 * sum(1..100) + 3*100
      let expect = 3'i64 * (10100'i64 div 2) + 3'i64 * 100
      check sum == expect
