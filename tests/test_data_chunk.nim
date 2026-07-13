import unittest2
import std/[times]
import nint128
import uuid4
import ../src/[database, query, qresult, types]

suite "DataChunk read-only API":
  test "chunk vector access + bindAs":
    let duck = newDatabase().connect()
    let r = duck.execute(
      "SELECT 1::INTEGER AS idx, 'hello'::VARCHAR AS name, true::BOOLEAN AS flag"
    )
    for chunk in r:
      check chunk.vector(0).kind == DuckType.Integer
      check chunk.vector(1).kind == DuckType.Varchar
      check chunk.vector(2).kind == DuckType.Boolean
      check chunk.bindAs(0, DuckType.Integer).toSeq == @[1'i32]
      check chunk.bindAs(1, DuckType.Varchar).toSeq == @["hello"]
      check chunk.bindAs(2, DuckType.Boolean).toSeq == @[true]

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------
suite "DataChunk construction":
  test "newDataChunk from columns then setSize":
    let cols = @[
      newColumn("i", newLogicalType(DuckType.Integer)),
      newColumn("s", newLogicalType(DuckType.Varchar)),
    ]
    let c = newDataChunk(cols)
    check c.len == 0
    c.setSize(3)
    check c.len == 3

  test "newColumn derives kind from ltype":
    let col = newColumn("x", newLogicalType(DuckType.BigInt))
    check col.name == "x"
    check col.kind == DuckType.BigInt
    check col.idx == 0

  test "newDataChunk zero columns raises ValueError":
    expect(ValueError):
      discard newDataChunk(@[])

  test "newDataChunk nil ltype assertion":
    let cols = @[Column(idx: 0, name: "bad", kind: DuckType.Invalid, ltype: nil)]
    expect(AssertionDefect):
      discard newDataChunk(cols)

# ---------------------------------------------------------------------------
# Zero-copy primitive writes + read-back
# ---------------------------------------------------------------------------
suite "DataChunk write []= — primitives":
  test "int32 round-trip":
    let cols = @[newColumn("i", newLogicalType(DuckType.Integer))]
    let c = newDataChunk(cols)
    c.setSize(3)
    var w = c.bindAs(0, DuckType.Integer)
    w[0] = 10'i32
    w[1] = 20'i32
    w[2] = 30'i32
    check w.toSeq == @[10'i32, 20, 30]

  test "int64 round-trip":
    let cols = @[newColumn("i", newLogicalType(DuckType.BigInt))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.BigInt)
    w[0] = 9223372036854775807'i64
    w[1] = -1'i64
    check w.toSeq == @[9223372036854775807'i64, -1]

  test "int8 round-trip":
    let cols = @[newColumn("x", newLogicalType(DuckType.TinyInt))]
    let c = newDataChunk(cols)
    c.setSize(3)
    var w = c.bindAs(0, DuckType.TinyInt)
    w[0] = -128'i8
    w[1] = 0'i8
    w[2] = 127'i8
    check w.toSeq == @[-128'i8, 0, 127]

  test "uint8 round-trip":
    let cols = @[newColumn("x", newLogicalType(DuckType.UTinyInt))]
    let c = newDataChunk(cols)
    c.setSize(3)
    var w = c.bindAs(0, DuckType.UTinyInt)
    w[0] = 0'u8
    w[1] = 128'u8
    w[2] = 255'u8
    check w.toSeq == @[0'u8, 128, 255]

  test "float32 round-trip":
    let cols = @[newColumn("f", newLogicalType(DuckType.Float))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.Float)
    w[0] = 1.5'f32
    w[1] = -0.0'f32
    check w.toSeq == @[1.5'f32, -0.0]

  test "float64 round-trip":
    let cols = @[newColumn("d", newLogicalType(DuckType.Double))]
    let c = newDataChunk(cols)
    c.setSize(3)
    var w = c.bindAs(0, DuckType.Double)
    w[0] = 3.14159265358979
    w[1] = 2.71828182845904
    w[2] = -0.0
    check w.toSeq == @[3.14159265358979, 2.71828182845904, -0.0]

  test "boolean round-trip":
    let cols = @[newColumn("b", newLogicalType(DuckType.Boolean))]
    let c = newDataChunk(cols)
    c.setSize(4)
    var w = c.bindAs(0, DuckType.Boolean)
    w[0] = true
    w[1] = false
    w[2] = false
    w[3] = true
    check w.toSeq == @[true, false, false, true]

  test "uint16 round-trip":
    let cols = @[newColumn("x", newLogicalType(DuckType.USmallInt))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.USmallInt)
    w[0] = 0'u16
    w[1] = 65535'u16
    check w.toSeq == @[0'u16, 65535]

  test "uint32 round-trip":
    let cols = @[newColumn("x", newLogicalType(DuckType.UInteger))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.UInteger)
    w[0] = 0'u32
    w[1] = 4294967295'u32
    check w.toSeq == @[0'u32, 4294967295'u32]

  test "uint64 round-trip":
    let cols = @[newColumn("x", newLogicalType(DuckType.UBigInt))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.UBigInt)
    w[0] = 0'u64
    w[1] = 18446744073709551615'u64
    check w.toSeq == @[0'u64, 18446744073709551615'u64]

# ---------------------------------------------------------------------------
# String / blob writes
# ---------------------------------------------------------------------------
suite "DataChunk write []= — strings and blobs":
  test "varchar round-trip":
    let cols = @[newColumn("s", newLogicalType(DuckType.Varchar))]
    let c = newDataChunk(cols)
    c.setSize(3)
    var w = c.bindAs(0, DuckType.Varchar)
    w[0] = "hello"
    w[1] = ""
    w[2] = "world"
    check w.toSeq == @["hello", "", "world"]

  test "varchar embedded NUL":
    let cols = @[newColumn("s", newLogicalType(DuckType.Varchar))]
    let c = newDataChunk(cols)
    c.setSize(1)
    var w = c.bindAs(0, DuckType.Varchar)
    let s = "a\x00b"
    w[0] = s
    check w[0].len == 3
    check w[0] == s

  test "blob round-trip":
    let cols = @[newColumn("b", newLogicalType(DuckType.Blob))]
    let c = newDataChunk(cols)
    c.setSize(3)
    var w = c.bindAs(0, DuckType.Blob)
    w[0] = @[byte 1, 2, 3]
    w[1] = @[]
    w[2] = @[byte 255, 0, 128]
    check w.toSeq == @[@[byte 1, 2, 3], @[], @[byte 255, 0, 128]]

  test "bit round-trip":
    let cols = @[newColumn("b", newLogicalType(DuckType.Bit))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.Bit)
    w[0] = "1010"
    w[1] = ""
    check w.toSeq == @["1010", ""]

# ---------------------------------------------------------------------------
# Nulls
# ---------------------------------------------------------------------------
suite "DataChunk writes — nulls and validity":
  test "setNull marks row invalid":
    let cols = @[newColumn("i", newLogicalType(DuckType.Integer))]
    let c = newDataChunk(cols)
    c.setSize(3)
    var w = c.bindAs(0, DuckType.Integer)
    w[0] = 1'i32
    w[2] = 3'i32
    w.setNull(1)
    check w.valid(0) == true
    check w.valid(1) == false
    check w.valid(2) == true
    check w.toSeq == @[1'i32, 0'i32, 3'i32]

  test "setNull then setValid":
    let cols = @[newColumn("i", newLogicalType(DuckType.Integer))]
    let c = newDataChunk(cols)
    c.setSize(1)
    var w = c.bindAs(0, DuckType.Integer)
    w.setNull(0)
    check w.valid(0) == false
    w.setValid(0)
    check w.valid(0) == true

  test "all rows valid on fresh chunk":
    let cols = @[newColumn("i", newLogicalType(DuckType.Integer))]
    let c = newDataChunk(cols)
    c.setSize(2)
    let w = c.bindAs(0, DuckType.Integer)
    check w.valid(0) == true
    check w.valid(1) == true

  test "lazy validity allocation on first setNull":
    let cols = @[
      newColumn("i", newLogicalType(DuckType.Integer)),
      newColumn("s", newLogicalType(DuckType.Varchar)),
    ]
    let c = newDataChunk(cols)
    c.setSize(2)
    var wi = c.bindAs(0, DuckType.Integer)
    check wi.valid(0) == true
    wi.setNull(0)
    # after setNull, the bool-valid reference stays nil — the validity mask
    # is lazily allocated inside setNull; vector uses the validity ptr
    check wi.valid(0) == false
    check wi.valid(1) == true

# ---------------------------------------------------------------------------
# Index bounds
# ---------------------------------------------------------------------------
suite "DataChunk writes — bounds checking":
  test "[]= out of bounds raises":
    let cols = @[newColumn("i", newLogicalType(DuckType.Integer))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.Integer)
    expect(AssertionDefect):
      w[2] = 42'i32
    expect(AssertionDefect):
      w[-1] = 42'i32

  test "setNull out of bounds raises":
    let cols = @[newColumn("i", newLogicalType(DuckType.Integer))]
    let c = newDataChunk(cols)
    c.setSize(1)
    var w = c.bindAs(0, DuckType.Integer)
    expect(AssertionDefect):
      w.setNull(1)

# ---------------------------------------------------------------------------
# Temporal writes
# ---------------------------------------------------------------------------
suite "DataChunk write []= — temporal":
  test "timestamp round-trip":
    let cols = @[newColumn("t", newLogicalType(DuckType.Timestamp))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.Timestamp)
    let ts1 = Timestamp(dateTime(2020, mJan, 1, 12, 0, 0, zone = utc()))
    let ts2 = Timestamp(dateTime(1999, mDec, 31, 23, 59, 59, zone = utc()))
    w[0] = ts1
    w[1] = ts2
    check w[0] == ts1
    check w[1] == ts2

  test "date round-trip":
    let cols = @[newColumn("d", newLogicalType(DuckType.Date))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.Date)
    let d1 = dateTime(2023, mJul, 14, zone = utc())
    let d2 = dateTime(2000, mJan, 1, zone = utc())
    w[0] = d1
    w[1] = d2
    check w[0].utc.toTime.toUnix == d1.utc.toTime.toUnix
    check w[1].utc.toTime.toUnix == d2.utc.toTime.toUnix

  test "time round-trip":
    let cols = @[newColumn("t", newLogicalType(DuckType.Time))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.Time)
    let t1 = initTime(8 * 3600 + 30 * 60, 0)
    let t2 = initTime(23 * 3600 + 59 * 60 + 59, 0)
    w[0] = t1
    w[1] = t2
    check w[0] == t1
    check w[1] == t2

  test "interval round-trip":
    let cols = @[newColumn("iv", newLogicalType(DuckType.Interval))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.Interval)
    let iv1 = initTimeInterval(years = 1, months = 6, days = 10,
                               hours = 2, minutes = 30, seconds = 15)
    let iv2 = initTimeInterval(days = 1, hours = 1)
    w[0] = iv1
    w[1] = iv2
    check w[0] == iv1
    check w[1] == iv2

# ---------------------------------------------------------------------------
# HugeInt / UUID writes
# ---------------------------------------------------------------------------
suite "DataChunk write []= — hugeint and uuid":
  test "hugeint round-trip":
    let cols = @[newColumn("h", newLogicalType(DuckType.HugeInt))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.HugeInt)
    w[0] = i128(42'u64)
    w[1] = i128(0x7FFF_FFFF_FFFF_FFFF'u64)
    check w[0] == i128(42'u64)
    check w[1] == i128(0x7FFF_FFFF_FFFF_FFFF'u64)

  test "uhugeint round-trip":
    let cols = @[newColumn("u", newLogicalType(DuckType.UHugeInt))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.UHugeInt)
    let maxUhi = not zero(UInt128)
    w[0] = zero(UInt128)
    w[1] = maxUhi
    check w[0] == zero(UInt128)
    check w[1] == maxUhi

  test "uuid round-trip":
    let cols = @[newColumn("u", newLogicalType(DuckType.UUID))]
    let c = newDataChunk(cols)
    c.setSize(1)
    var w = c.bindAs(0, DuckType.UUID)
    let u = uuid4()
    w[0] = u
    check w[0] == u

# ---------------------------------------------------------------------------
# Bulk insert round-trip via appender
# ---------------------------------------------------------------------------
suite "DataChunk bulk insert via appender":
  test "build chunk from appender schema + append":
    let conn = newDatabase().connect()
    conn.execute(
      "CREATE TABLE bulk_insert (c_int INTEGER, c_str VARCHAR, c_bool BOOLEAN)"
    )
    var app = newAppender(conn, "bulk_insert")
    let chunk = newDataChunk(app)
    check chunk.columnCount == 3
    check chunk.vector(0).kind == DuckType.Integer
    check chunk.vector(1).kind == DuckType.Varchar
    check chunk.vector(2).kind == DuckType.Boolean

    chunk.setSize(3)
    var wi = chunk.bindAs(0, DuckType.Integer)
    var ws = chunk.bindAs(1, DuckType.Varchar)
    var wb = chunk.bindAs(2, DuckType.Boolean)
    wi[0] = 1'i32; ws[0] = "foo"; wb[0] = true
    wi[1] = 2'i32; ws[1] = "bar"; wb[1] = false
    wi[2] = 3'i32; ws[2] = "baz"; wb[2] = true

    app.append(chunk)
    app.close()

    let r = conn.execute("SELECT * FROM bulk_insert ORDER BY c_int")
    for ck in r:
      check ck.bindAs(0, DuckType.Integer).toSeq == @[1'i32, 2, 3]
      check ck.bindAs(1, DuckType.Varchar).toSeq == @["foo", "bar", "baz"]
      check ck.bindAs(2, DuckType.Boolean).toSeq == @[true, false, true]

  test "bulk insert with nulls via setNull":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE bulk_null (i INTEGER)")
    var app = newAppender(conn, "bulk_null")
    let chunk = newDataChunk(app)
    chunk.setSize(3)
    var wi = chunk.bindAs(0, DuckType.Integer)
    wi[0] = 100'i32
    wi[2] = 300'i32
    wi.setNull(1)
    app.append(chunk)
    app.close()

    let r = conn.execute("SELECT * FROM bulk_null ORDER BY i NULLS FIRST")
    for ck in r:
      check ck.bindAs(0, DuckType.Integer).valid(0) == false
      check ck.bindAs(0, DuckType.Integer).valid(1) == true
      check ck.bindAs(0, DuckType.Integer).valid(2) == true
      check ck.bindAs(0, DuckType.Integer)[1] == 100'i32
      check ck.bindAs(0, DuckType.Integer)[2] == 300'i32

  test "bulk insert multiple types via newDataChunk(columns)":
    let conn = newDatabase().connect()
    conn.execute(
      "CREATE TABLE multitype (d DOUBLE, v VARCHAR, t TIMESTAMP)"
    )
    var app = newAppender(conn, "multitype")
    let cols = @[
      newColumn("d", newLogicalType(DuckType.Double)),
      newColumn("v", newLogicalType(DuckType.Varchar)),
      newColumn("t", newLogicalType(DuckType.Timestamp)),
    ]
    let chunk = newDataChunk(cols)
    chunk.setSize(2)
    var wd = chunk.bindAs(0, DuckType.Double)
    var wv = chunk.bindAs(1, DuckType.Varchar)
    var wt = chunk.bindAs(2, DuckType.Timestamp)
    let ts1 = Timestamp(dateTime(2021, mJun, 15, 9, 30, 0, zone = utc()))
    let ts2 = Timestamp(dateTime(2022, mMar, 1, 18, 0, 0, zone = utc()))
    wd[0] = 3.14; wv[0] = "alpha"; wt[0] = ts1
    wd[1] = 2.71; wv[1] = "beta";  wt[1] = ts2
    app.append(chunk)
    app.close()

    let r = conn.execute("SELECT * FROM multitype ORDER BY d")
    for ck in r:
      check ck.bindAs(0, DuckType.Double).toSeq == @[2.71, 3.14]
      check ck.bindAs(1, DuckType.Varchar).toSeq == @["beta", "alpha"]
      let ts = ck.bindAs(2, DuckType.Timestamp)
      check ts[0] == ts2
      check ts[1] == ts1

# ---------------------------------------------------------------------------
# Decimal write (conditional on x86)
# ---------------------------------------------------------------------------
when defined(i386) or defined(amd64):
  import decimal
  import ../src/[codec]

  suite "DataChunk write []= — decimal":
    test "decimal round-trip via appender":
      let conn = newDatabase().connect()
      conn.execute("CREATE TABLE dec_insert (d DECIMAL(6, 3))")
      var app = newAppender(conn, "dec_insert")
      let chunk = newDataChunk(app)
      chunk.setSize(3)
      var w = chunk.bindAs(0, DuckType.Decimal)
      w[0] = newDecimal("12.345")
      w[1] = newDecimal("-6.789")
      w[2] = newDecimal("0.001")
      app.append(chunk)
      app.close()

      let r = conn.execute("SELECT * FROM dec_insert ORDER BY d")
      for ck in r:
        let v = ck.bindAs(0, DuckType.Decimal)
        check $(v[0]) == "-6.789"
        check $(v[1]) == "0.001"
        check $(v[2]) == "12.345"

# ---------------------------------------------------------------------------
# setSize edges
# ---------------------------------------------------------------------------
suite "DataChunk setSize":
  test "setSize zero is allowed":
    let cols = @[newColumn("i", newLogicalType(DuckType.Integer))]
    let c = newDataChunk(cols)
    c.setSize(0)
    check c.len == 0

  test "re-setSize to larger count works":
    let cols = @[newColumn("i", newLogicalType(DuckType.Integer))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.Integer)
    w[0] = 1'i32
    w[1] = 2'i32
    c.setSize(4)
    w = c.bindAs(0, DuckType.Integer)
    w[2] = 3'i32
    w[3] = 4'i32
    check w.toSeq == @[1'i32, 2, 3, 4]

# ---------------------------------------------------------------------------
# Vector[kt].appendValues — bulk fill
# ---------------------------------------------------------------------------
suite "Vector[kt].appendValues":

  test "int32 appendValues round-trip":
    let cols = @[newColumn("i", newLogicalType(DuckType.Integer))]
    let c = newDataChunk(cols)
    c.setSize(3)
    var w = c.bindAs(0, DuckType.Integer)
    w.appendValues(@[10'i32, 20, 30])
    check w.toSeq == @[10'i32, 20, 30]

  test "int64 appendValues round-trip":
    let cols = @[newColumn("i", newLogicalType(DuckType.BigInt))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.BigInt)
    w.appendValues(@[9223372036854775807'i64, -1])
    check w.toSeq == @[9223372036854775807'i64, -1]

  test "int8 appendValues round-trip":
    let cols = @[newColumn("x", newLogicalType(DuckType.TinyInt))]
    let c = newDataChunk(cols)
    c.setSize(3)
    var w = c.bindAs(0, DuckType.TinyInt)
    w.appendValues(@[-128'i8, 0, 127])
    check w.toSeq == @[-128'i8, 0, 127]

  test "uint8 appendValues round-trip":
    let cols = @[newColumn("x", newLogicalType(DuckType.UTinyInt))]
    let c = newDataChunk(cols)
    c.setSize(3)
    var w = c.bindAs(0, DuckType.UTinyInt)
    w.appendValues(@[0'u8, 128, 255])
    check w.toSeq == @[0'u8, 128, 255]

  test "float32 appendValues round-trip":
    let cols = @[newColumn("f", newLogicalType(DuckType.Float))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.Float)
    w.appendValues(@[1.5'f32, -0.0])
    check w.toSeq == @[1.5'f32, -0.0]

  test "float64 appendValues round-trip":
    let cols = @[newColumn("d", newLogicalType(DuckType.Double))]
    let c = newDataChunk(cols)
    c.setSize(3)
    var w = c.bindAs(0, DuckType.Double)
    w.appendValues(@[3.14159265358979, 2.71828182845904, -0.0])
    check w.toSeq == @[3.14159265358979, 2.71828182845904, -0.0]

  test "boolean appendValues round-trip":
    let cols = @[newColumn("b", newLogicalType(DuckType.Boolean))]
    let c = newDataChunk(cols)
    c.setSize(4)
    var w = c.bindAs(0, DuckType.Boolean)
    w.appendValues(@[true, false, false, true])
    check w.toSeq == @[true, false, false, true]

  test "varchar appendValues round-trip":
    let cols = @[newColumn("s", newLogicalType(DuckType.Varchar))]
    let c = newDataChunk(cols)
    c.setSize(3)
    var w = c.bindAs(0, DuckType.Varchar)
    w.appendValues(@["hello", "", "world"])
    check w.toSeq == @["hello", "", "world"]

  test "varchar appendValues with embedded NUL":
    let cols = @[newColumn("s", newLogicalType(DuckType.Varchar))]
    let c = newDataChunk(cols)
    c.setSize(1)
    var w = c.bindAs(0, DuckType.Varchar)
    let s = "a\x00b"
    w.appendValues(@[s])
    check w[0].len == 3
    check w[0] == s

  test "blob appendValues round-trip":
    let cols = @[newColumn("b", newLogicalType(DuckType.Blob))]
    let c = newDataChunk(cols)
    c.setSize(3)
    var w = c.bindAs(0, DuckType.Blob)
    w.appendValues(@[@[byte 1, 2, 3], @[], @[byte 255, 0, 128]])
    check w.toSeq == @[@[byte 1, 2, 3], @[], @[byte 255, 0, 128]]

  test "timestamp appendValues round-trip":
    let cols = @[newColumn("t", newLogicalType(DuckType.Timestamp))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.Timestamp)
    let ts1 = Timestamp(dateTime(2020, mJan, 1, 12, 0, 0, zone = utc()))
    let ts2 = Timestamp(dateTime(1999, mDec, 31, 23, 59, 59, zone = utc()))
    w.appendValues(@[ts1, ts2])
    check w[0] == ts1
    check w[1] == ts2

  test "date appendValues round-trip":
    let cols = @[newColumn("d", newLogicalType(DuckType.Date))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.Date)
    let d1 = dateTime(2023, mJul, 14, zone = utc())
    let d2 = dateTime(2000, mJan, 1, zone = utc())
    w.appendValues(@[d1, d2])
    check w[0].utc.toTime.toUnix == d1.utc.toTime.toUnix
    check w[1].utc.toTime.toUnix == d2.utc.toTime.toUnix

  test "time appendValues round-trip":
    let cols = @[newColumn("t", newLogicalType(DuckType.Time))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.Time)
    let t1 = initTime(8 * 3600 + 30 * 60, 0)
    let t2 = initTime(23 * 3600 + 59 * 60 + 59, 0)
    w.appendValues(@[t1, t2])
    check w[0] == t1
    check w[1] == t2

  test "interval appendValues round-trip":
    let cols = @[newColumn("iv", newLogicalType(DuckType.Interval))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.Interval)
    let iv1 = initTimeInterval(years = 1, months = 6, days = 10,
                               hours = 2, minutes = 30, seconds = 15)
    let iv2 = initTimeInterval(days = 1, hours = 1)
    w.appendValues(@[iv1, iv2])
    check w[0] == iv1
    check w[1] == iv2

  test "hugeint appendValues round-trip":
    let cols = @[newColumn("h", newLogicalType(DuckType.HugeInt))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.HugeInt)
    w.appendValues(@[i128(42'u64), i128(0x7FFF_FFFF_FFFF_FFFF'u64)])
    check w[0] == i128(42'u64)
    check w[1] == i128(0x7FFF_FFFF_FFFF_FFFF'u64)

  test "uhugeint appendValues round-trip":
    let cols = @[newColumn("u", newLogicalType(DuckType.UHugeInt))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.UHugeInt)
    let maxUhi = not zero(UInt128)
    w.appendValues(@[zero(UInt128), maxUhi])
    check w[0] == zero(UInt128)
    check w[1] == maxUhi

  test "uuid appendValues round-trip":
    let cols = @[newColumn("u", newLogicalType(DuckType.UUID))]
    let c = newDataChunk(cols)
    c.setSize(1)
    var w = c.bindAs(0, DuckType.UUID)
    let u = uuid4()
    w.appendValues(@[u])
    check w[0] == u

  test "appendValues empty seq is no-op":
    let cols = @[newColumn("i", newLogicalType(DuckType.Integer))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.Integer)
    w[0] = 99'i32
    w.appendValues(newSeq[int32](0))
    check w[0] == 99'i32

  test "appendValues with start offset":
    let cols = @[newColumn("i", newLogicalType(DuckType.Integer))]
    let c = newDataChunk(cols)
    c.setSize(5)
    var w = c.bindAs(0, DuckType.Integer)
    w[0] = 0'i32
    w[1] = 0'i32
    w.appendValues(@[1'i32, 2, 3], start = 2)
    check w.toSeq == @[0'i32, 0, 1, 2, 3]

  test "appendValues out of bounds raises":
    let cols = @[newColumn("i", newLogicalType(DuckType.Integer))]
    let c = newDataChunk(cols)
    c.setSize(2)
    var w = c.bindAs(0, DuckType.Integer)
    expect(AssertionDefect):
      w.appendValues(@[1'i32, 2, 3])

# ---------------------------------------------------------------------------
# ChunkBuilder — column-oriented multi-column builder
# ---------------------------------------------------------------------------
suite "ChunkBuilder":

  test "builder fill two columns via appendValues":
    let cols = @[
      newColumn("i", newLogicalType(DuckType.Integer)),
      newColumn("s", newLogicalType(DuckType.Varchar)),
    ]
    var b = newChunkBuilder(cols)
    appendValues[DuckType.Integer](b, 0, @[1'i32, 2, 3])
    appendValues[DuckType.Varchar](b, 1, @["a", "b", "c"])
    let c = finish(b)
    check c.len == 3
    check c.bindAs(0, DuckType.Integer).toSeq == @[1'i32, 2, 3]
    check c.bindAs(1, DuckType.Varchar).toSeq == @["a", "b", "c"]

  test "builder append + appendNull + appendValues mixed":
    let cols = @[newColumn("i", newLogicalType(DuckType.Integer))]
    var b = newChunkBuilder(cols)
    append[DuckType.Integer](b, 0, 1'i32)
    appendNull[DuckType.Integer](b, 0)
    appendValues[DuckType.Integer](b, 0, @[3'i32, 4])
    let c = finish(b)
    check c.len == 4
    let v = c.bindAs(0, DuckType.Integer)
    check v.valid(0) == true
    check v[0] == 1'i32
    check v.valid(1) == false
    check v.valid(2) == true
    check v[2] == 3'i32
    check v.valid(3) == true
    check v[3] == 4'i32

  test "builder appendNulls bulk":
    let cols = @[newColumn("i", newLogicalType(DuckType.Integer))]
    var b = newChunkBuilder(cols)
    append[DuckType.Integer](b, 0, 1'i32)
    appendNulls[DuckType.Integer](b, 0, 2)
    append[DuckType.Integer](b, 0, 4'i32)
    let c = finish(b)
    check c.len == 4
    let v = c.bindAs(0, DuckType.Integer)
    check v.valid(0) == true
    check v.valid(1) == false
    check v.valid(2) == false
    check v.valid(3) == true

  test "builder capacity overflow raises":
    let cols = @[newColumn("i", newLogicalType(DuckType.Integer))]
    var b = newChunkBuilder(cols)
    expect(AssertionDefect):
      appendValues[DuckType.Integer](b, 0, newSeq[int32](3000))

  test "builder column length mismatch at finish":
    let cols = @[
      newColumn("i", newLogicalType(DuckType.Integer)),
      newColumn("s", newLogicalType(DuckType.Varchar)),
    ]
    var b = newChunkBuilder(cols)
    appendValues[DuckType.Integer](b, 0, @[1'i32, 2, 3])
    appendValues[DuckType.Varchar](b, 1, @["a", "b"])
    expect(ValueError):
      discard finish(b)

  test "builder finish twice raises":
    let cols = @[newColumn("i", newLogicalType(DuckType.Integer))]
    var b = newChunkBuilder(cols)
    append[DuckType.Integer](b, 0, 1'i32)
    discard finish(b)
    expect(AssertionDefect):
      discard finish(b)

  test "builder len and appendedRows":
    let cols = @[
      newColumn("i", newLogicalType(DuckType.Integer)),
      newColumn("s", newLogicalType(DuckType.Varchar)),
    ]
    var b = newChunkBuilder(cols)
    check b.len == 0
    append[DuckType.Integer](b, 0, 1'i32)
    check b.len == 1
    check b.appendedRows(0) == 1
    check b.appendedRows(1) == 0
    appendValues[DuckType.Integer](b, 0, @[2'i32, 3])
    check b.len == 3
    append[DuckType.Varchar](b, 1, "a")
    check b.appendedRows(1) == 1

  test "builder columnCount":
    let cols = @[
      newColumn("a", newLogicalType(DuckType.Integer)),
      newColumn("b", newLogicalType(DuckType.Float)),
      newColumn("c", newLogicalType(DuckType.Varchar)),
    ]
    let b = newChunkBuilder(cols)
    check b.columnCount == 3

  test "builder appender round-trip":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE builder_insert (n INTEGER, t TEXT)")
    var app = newAppender(conn, "builder_insert")
    var b = newChunkBuilder(app)
    appendValues[DuckType.Integer](b, 0, @[10'i32, 20, 30])
    appendValues[DuckType.Varchar](b, 1, @["x", "y", "z"])
    let chunk = finish(b)
    app.append(chunk)
    app.close()
    let r = conn.execute("SELECT * FROM builder_insert ORDER BY n")
    for ck in r:
      check ck.bindAs(0, DuckType.Integer).toSeq == @[10'i32, 20, 30]
      check ck.bindAs(1, DuckType.Varchar).toSeq == @["x", "y", "z"]

  test "builder from existing DataChunk":
    let cols = @[newColumn("i", newLogicalType(DuckType.Integer))]
    let chunk = newDataChunk(cols)
    var b = newChunkBuilder(chunk)
    appendValues[DuckType.Integer](b, 0, @[42'i32])
    let c = finish(b)
    check c.len == 1
    check c.bindAs(0, DuckType.Integer)[0] == 42'i32

# ---------------------------------------------------------------------------
# Single-column newDataChunk(name, seq[T])
# ---------------------------------------------------------------------------
suite "newDataChunk(name, seq[T]) single-column":

  test "int32 single-column from seq":
    let c = newDataChunk("i", @[1'i32, 2, 3])
    check c.columnCount == 1
    check c.len == 3
    check c.bindAs(0, DuckType.Integer).toSeq == @[1'i32, 2, 3]

  test "int64 single-column from seq":
    let c = newDataChunk("i", @[100'i64, 200])
    check c.bindAs(0, DuckType.BigInt).toSeq == @[100'i64, 200]

  test "float64 single-column from seq":
    let c = newDataChunk("f", @[1.5, 2.5, 3.5])
    check c.bindAs(0, DuckType.Double).toSeq == @[1.5, 2.5, 3.5]

  test "bool single-column from seq":
    let c = newDataChunk("b", @[true, false, true])
    check c.bindAs(0, DuckType.Boolean).toSeq == @[true, false, true]

  test "string single-column from seq":
    let c = newDataChunk("s", @["hello", "", "world"])
    check c.bindAs(0, DuckType.Varchar).toSeq == @["hello", "", "world"]

  test "blob single-column from seq":
    let c = newDataChunk("b", @[@[byte 1, 2, 3], @[], @[byte 255]])
    check c.bindAs(0, DuckType.Blob).toSeq == @[@[byte 1, 2, 3], @[], @[byte 255]]

  test "timestamp single-column from seq":
    let ts1 = Timestamp(dateTime(2020, mJan, 1, 12, 0, 0, zone = utc()))
    let ts2 = Timestamp(dateTime(2021, mJun, 15, 9, 30, 0, zone = utc()))
    let c = newDataChunk("t", @[ts1, ts2])
    let v = c.bindAs(0, DuckType.Timestamp)
    check v[0] == ts1
    check v[1] == ts2

  test "hugeint single-column from seq":
    let c = newDataChunk("h", @[i128(42'u64), i128(100'u64)])
    check c.bindAs(0, DuckType.HugeInt).toSeq == @[i128(42'u64), i128(100'u64)]

  test "uuid single-column from seq":
    let u = uuid4()
    let c = newDataChunk("u", @[u])
    check c.bindAs(0, DuckType.UUID)[0] == u

  test "empty seq produces empty chunk":
    let c = newDataChunk("i", newSeq[int32](0))
    check c.len == 0
    check c.columnCount == 1

  test "single-column round-trip via appender":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE sc_bulk (v VARCHAR)")
    var app = newAppender(conn, "sc_bulk")
    let c = newDataChunk("v", @["one", "two", "three"])
    app.append(c)
    app.close()
    let r = conn.execute("SELECT * FROM sc_bulk ORDER BY v")
    for ck in r:
      check ck.bindAs(0, DuckType.Varchar).toSeq == @["one", "three", "two"]

# ---------------------------------------------------------------------------
# Multi-column newChunk(tuple) macro
# ---------------------------------------------------------------------------
suite "newChunk(tuple) multi-column macro":

  test "two-column int + string":
    let c = newChunk(
      ("i", @[1'i32, 2, 3]),
      ("s", @["a", "b", "c"]),
    )
    check c.columnCount == 2
    check c.len == 3
    check c.bindAs(0, DuckType.Integer).toSeq == @[1'i32, 2, 3]
    check c.bindAs(1, DuckType.Varchar).toSeq == @["a", "b", "c"]

  test "three-column int + float + string":
    let c = newChunk(
      ("a", @[10'i32, 20]),
      ("b", @[1.5, 2.5]),
      ("c", @["x", "y"]),
    )
    check c.columnCount == 3
    check c.len == 2
    check c.bindAs(0, DuckType.Integer).toSeq == @[10'i32, 20]
    check c.bindAs(1, DuckType.Double).toSeq == @[1.5, 2.5]
    check c.bindAs(2, DuckType.Varchar).toSeq == @["x", "y"]

  test "multi-column with blob":
    let c = newChunk(
      ("k", @[1'i32, 2]),
      ("b", @[@[byte 1, 2], @[byte 3]]),
    )
    check c.columnCount == 2
    check c.bindAs(0, DuckType.Integer).toSeq == @[1'i32, 2]
    check c.bindAs(1, DuckType.Blob).toSeq == @[@[byte 1, 2], @[byte 3]]

  test "length mismatch raises":
    expect(AssertionDefect):
      discard newChunk(
        ("i", @[1'i32, 2, 3]),
        ("s", @["a"]),
      )

  test "single-column tuple works":
    let c = newChunk(("x", @[5'i32, 10]))
    check c.columnCount == 1
    check c.len == 2
    check c.bindAs(0, DuckType.Integer).toSeq == @[5'i32, 10]

  test "multi-column round-trip via appender":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE mc_bulk (n INTEGER, f DOUBLE, s VARCHAR)")
    var app = newAppender(conn, "mc_bulk")
    let c = newChunk(
      ("n", @[1'i32, 2, 3]),
      ("f", @[1.1, 2.2, 3.3]),
      ("s", @["a", "b", "c"]),
    )
    app.append(c)
    app.close()
    let r = conn.execute("SELECT * FROM mc_bulk ORDER BY n")
    for ck in r:
      check ck.bindAs(0, DuckType.Integer).toSeq == @[1'i32, 2, 3]
      check ck.bindAs(1, DuckType.Double).toSeq == @[1.1, 2.2, 3.3]
      check ck.bindAs(2, DuckType.Varchar).toSeq == @["a", "b", "c"]
