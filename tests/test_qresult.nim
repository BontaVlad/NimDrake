import unittest2
import std/[strutils, tables]
import decimal
import ../src/[database, query, qresult, codec, table, types]

suite "QResult zero-copy API":
  test "construction + metadata":
    let duck = newDatabase().connect()
    let r = duck.executeMaterialized(
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
    let r = duck.executeMaterialized(
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
    let r = duck.executeMaterialized(
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
    let r = duck.executeMaterialized(
      "SELECT seq AS id, seq * 10 AS ten FROM generate_series(1, 3) AS t(seq)"
    )
    for chunk in r:
      let ten = chunk.bindAs("ten", DuckType.BigInt)
      check ten[0] == 10
      check ten[1] == 20
      check ten[2] == 30

  test "chunk[string] syntactic sugar":
    let duck = newDatabase().connect()
    let r = duck.executeMaterialized(
      "SELECT seq AS id FROM generate_series(1, 3) AS t(seq)"
    )
    for chunk in r:
      let v = chunk["id"].bindAs DuckType.BigInt
      check v[0] == 1
      check v[1] == 2
      check v[2] == 3

  test "varchar bulk decode via toSeq":
    let duck = newDatabase().connect()
    let r = duck.executeMaterialized(
      "SELECT 'V' || seq::VARCHAR FROM generate_series(1, 5) AS t(seq)"
    )
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Varchar
      let strs = v.toSeq
      check strs == @["V1", "V2", "V3", "V4", "V5"]

  test "borrow() avoids allocation":
    let duck = newDatabase().connect()
    let r = duck.executeMaterialized(
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
    let r = duck.executeMaterialized("""
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
    let r = duck.executeMaterialized("""
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
    let r = duck.executeMaterialized("SELECT 1 AS i")
    for chunk in r:
      let cv = chunk.vector(0)
      expect(ValueError):
        discard cv.bindAs DuckType.Varchar

  test "vector lookup by name":
    let duck = newDatabase().connect()
    let r = duck.executeMaterialized(
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
    let r = duck.executeMaterialized("""
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
    let r = duck.executeMaterialized("SELECT 1 AS i, 'x' AS s")
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
    let r = duck.executeMaterialized(
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
    let r = duck.executeMaterialized(
      "SELECT seq FROM generate_series(1, 5) AS t(seq)"
    )
    let t = initTable(r)
    let v = t.bindAs("seq", DuckType.BigInt)
    check v.toSeq == @[1'i64, 2, 3, 4, 5]

  test "cross-chunk ColumnVector items — BigInt":
    let duck = newDatabase().connect()
    let r = duck.executeMaterialized(
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
    let r = duck.executeMaterialized(
      "SELECT 'V' || seq::VARCHAR AS s FROM generate_series(1, 5) AS t(seq)"
    )
    let t = initTable(r)
    let v = t.bindAs("s", DuckType.Varchar)
    check v.toSeq == @["V1", "V2", "V3", "V4", "V5"]

  test "cross-chunk Table borrow":
    let duck = newDatabase().connect()
    let r = duck.executeMaterialized(
      "SELECT 'hello' AS s FROM generate_series(1, 1) AS t(seq)"
    )
    let t = initTable(r)
    let v = t.bindAs("s", DuckType.Varchar)
    check v.borrow(0).toString() == "hello"

  test "cross-chunk Table index out of bounds":
    let duck = newDatabase().connect()
    let r = duck.executeMaterialized("SELECT 1::BIGINT AS x")
    let t = initTable(r)
    let v = t.bindAs("x", DuckType.BigInt)
    expect(IndexDefect):
      discard v[1]

  test "cross-chunk Table nonzero column":
    let duck = newDatabase().connect()
    let r = duck.executeMaterialized("SELECT 1::BIGINT AS i")
    expect(ValueError):
      discard initTable(r).bindAs("i", DuckType.Varchar)

  test "cross-chunk Table nonexistent column":
    let duck = newDatabase().connect()
    let r = duck.executeMaterialized("SELECT 1::BIGINT AS i")
    expect(KeyError):
      discard initTable(r).bindAs("nope", DuckType.BigInt)

  test "cross-chunk Table handles nulls":
    let duck = newDatabase().connect()
    let r = duck.executeMaterialized("""
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

# ---------------------------------------------------------------------------
# Boolean
# ---------------------------------------------------------------------------
suite "QResult — Boolean":
  test "decode + toSeq":
    let duck = newDatabase().connect()
    let r = duck.executeMaterialized(
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
    let r = duck.executeMaterialized("""
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
    let r = duck.executeMaterialized(
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
    let r = duck.executeMaterialized(
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
    let r = duck.executeMaterialized(
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
    let r = duck.executeMaterialized(
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
    let r = duck.executeMaterialized(
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
    let r = duck.executeMaterialized(
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
    let r = duck.executeMaterialized(
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
    let r = duck.executeMaterialized(
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
    let r = duck.executeMaterialized(
      "SELECT union_value(num := 1)"
    )
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Union
      check v.unionMemberCount >= 1
      check v.unionMemberName(0) == "num"

  test "unionMemberChild descent":
    let duck = newDatabase().connect()
    let r = duck.executeMaterialized(
      "SELECT union_value(num := 99)"
    )
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Union
      let child = v.unionMemberChild(0)
      check child.kind == DuckType.Integer
      check child.bindAs(DuckType.Integer)[0] == 99
