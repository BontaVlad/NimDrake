import std/[times, strformat, math]
import unittest2
import nint128
import ../src/[types, database, query, qresult, codec]
import utils

suite "Test result types":
  test "Test Boolean result type":
    let conn = newDatabase().connect()
    discard conn.execute("CREATE TABLE booleans(i BOOLEAN);")
    discard conn.execute(
      "INSERT INTO booleans VALUES (true), (false), (true);"
    )
    let r = conn.execute("SELECT * FROM booleans")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Boolean).toSeq == @[true, false, true]

  test "Test TinyInt result type":
    let conn = newDatabase().connect()
    discard conn.execute(
      "CREATE TABLE tinyints(i TINYINT); INSERT INTO tinyints VALUES (-128), (0), (127);"
    )
    let r = conn.execute("SELECT * FROM tinyints")
    for chunk in r:
      check chunk.bindAs(0, DuckType.TinyInt).toSeq == @[-128'i8, 0'i8, 127'i8]

  test "Test SmallInt result type":
    let conn = newDatabase().connect()
    discard conn.execute(
      "CREATE TABLE smallints(i SMALLINT); INSERT INTO smallints VALUES (-32768), (0), (32767);"
    )
    let r = conn.execute("SELECT * FROM smallints")
    for chunk in r:
      check chunk.bindAs(0, DuckType.SmallInt).toSeq == @[-32768'i16, 0'i16, 32767'i16]

  test "Test Integer result type":
    let conn = newDatabase().connect()
    discard conn.execute(
      "CREATE TABLE integers(i INTEGER); INSERT INTO integers VALUES (-2147483648), (0), (2147483647);"
    )
    let r = conn.execute("SELECT * FROM integers")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Integer).toSeq ==
        @[-2147483648'i32, 0'i32, 2147483647'i32]

  test "Test BigInt result type":
    let conn = newDatabase().connect()
    discard conn.execute(
      "CREATE TABLE bigints(i BIGINT); INSERT INTO bigints VALUES (-9223372036854775808), (0), (9223372036854775807);"
    )
    let r = conn.execute("SELECT * FROM bigints")
    for chunk in r:
      check chunk.bindAs(0, DuckType.BigInt).toSeq ==
        @[-9223372036854775808'i64, 0'i64, 9223372036854775807'i64]

  test "Test UTinyInt result type":
    let conn = newDatabase().connect()
    discard conn.execute(
      "CREATE TABLE utinyints(i UTINYINT); INSERT INTO utinyints VALUES (255), (0), (127);"
    )
    let r = conn.execute("SELECT * FROM utinyints")
    for chunk in r:
      check chunk.bindAs(0, DuckType.UTinyInt).toSeq == @[255'u8, 0'u8, 127'u8]

  test "Test USmallInt result type":
    let conn = newDatabase().connect()
    discard conn.execute(
      "CREATE TABLE usmallints(i USMALLINT); INSERT INTO usmallints VALUES (0), (32767), (65535);"
    )
    let r = conn.execute("SELECT * FROM usmallints")
    for chunk in r:
      check chunk.bindAs(0, DuckType.USmallInt).toSeq ==
        @[0'u16, 32767'u16, 65535'u16]

  test "Test UInteger result type":
    let conn = newDatabase().connect()
    discard conn.execute(
      "CREATE TABLE uintegers(i UINTEGER); INSERT INTO uintegers VALUES (0), (2147483647), (4294967295);"
    )
    let r = conn.execute("SELECT * FROM uintegers")
    for chunk in r:
      check chunk.bindAs(0, DuckType.UInteger).toSeq ==
        @[0'u32, 2147483647'u32, 4294967295'u32]

  test "Test UBigInt result type":
    let conn = newDatabase().connect()
    discard conn.execute(
      "CREATE TABLE ubigints(i UBIGINT); INSERT INTO ubigints VALUES (0), (922337203685477580), (1844674407370940000);"
    )
    let r = conn.execute("SELECT * FROM ubigints")
    for chunk in r:
      check chunk.bindAs(0, DuckType.UBigInt).toSeq ==
        @[0'u64, 922337203685477580'u64, 1844674407370940000'u64]

  test "Test Float result type":
    let conn = newDatabase().connect()
    discard conn.execute(
      "CREATE TABLE floats(i FLOAT); INSERT INTO floats VALUES (-3.4), (0.0), (0.42);"
    )
    let r = conn.execute("SELECT * FROM floats")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Float).toSeq == @[-3.4'f, 0.0'f, 0.42'f]

  test "Test Double result type":
    let conn = newDatabase().connect()
    discard conn.execute(
      "CREATE TABLE doubles(i DOUBLE); INSERT INTO doubles VALUES (-3.4), (0.0), (0.42);"
    )
    let r = conn.execute("SELECT * FROM doubles")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Double).toSeq == @[-3.4, 0.0, 0.42]

  test "Test Timestamp result type":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT TIMESTAMP '1992-09-20 11:30:00.123456789';"
    )
    for chunk in r:
      check chunk.bindAs(0, DuckType.Timestamp)[0]
        .format("yyyy-MM-dd HH:mm:ss'.'ffffff") ==
        "1992-09-20 11:30:00.123456"

  test "Test Date result type":
    let conn = newDatabase().connect()
    discard conn.execute("CREATE TABLE IF NOT EXISTS dates (dt DATE);")
    discard conn.execute("INSERT INTO dates VALUES ('1992-09-20')")
    let r = conn.execute("SELECT * FROM dates")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Date)[0].year == 1992

  test "Test Time result type":
    let conn = newDatabase().connect()
    discard conn.execute("CREATE TABLE IF NOT EXISTS times (tm TIME);")
    discard conn.execute("INSERT INTO times VALUES ('01:02:03')")
    let r = conn.execute("SELECT * FROM times")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Time)[0] == initTime(3723, 0)

  test "Test Interval result type":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT INTERVAL '1.5' YEARS AS months_interval;"
    )
    for chunk in r:
      check chunk.bindAs("months_interval", DuckType.Interval)[0].years == 1

  test "Test HugeInt result type":
    let conn = newDatabase().connect()
    discard conn.execute(
      "CREATE TABLE IF NOT EXISTS huge (hg HUGEINT);"
    )
    discard conn.execute(
      fmt"INSERT INTO huge VALUES ({high(Int128)})"
    )
    let r = conn.execute("SELECT * FROM huge")
    for chunk in r:
      check chunk.bindAs(0, DuckType.HugeInt)[0] == high(Int128)

  test "Test Varchar result type":
    let conn = newDatabase().connect()
    discard conn.execute(
      "CREATE TABLE varchars(i VARCHAR); INSERT INTO varchars VALUES ('foo'), ('bar'), ('baz');"
    )
    let r = conn.execute("SELECT * FROM varchars")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Varchar).toSeq == @["foo", "bar", "baz"]

  test "Test Blob result type":
    let conn = newDatabase().connect()
    let r = conn.execute("SELECT 'AB'::BLOB;")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Blob)[0] ==
        @[byte(ord('A')), byte(ord('B'))]

  test "Test Decimal result type":
    ignoreLeak:
      let conn = newDatabase().connect()
      let r = conn.execute("SELECT CAST(12.3456 AS DECIMAL);")
      for chunk in r:
        check $chunk.bindAs(0, DuckType.Decimal)[0] == "12.346"

  test "Test TimestampS result type":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT TIMESTAMP_S '1992-09-20 11:30:00.123456789';"
    )
    for chunk in r:
      check chunk.bindAs(0, DuckType.TimestampS)[0]
        .format("yyyy-MM-dd HH:mm:ss'.'ffffff") ==
        "1992-09-20 11:30:00.000000"

  test "Test TimestampMs result type":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT TIMESTAMP_MS '1992-09-20 11:30:00.123456789';"
    )
    for chunk in r:
      check chunk.bindAs(0, DuckType.TimestampMs)[0]
        .format("yyyy-MM-dd HH:mm:ss'.'ffffff") ==
        "1992-09-20 11:30:00.123000"

  test "Test TimestampNs result type":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT TIMESTAMP_NS '1992-09-20 11:30:00.123456789';"
    )
    for chunk in r:
      check chunk.bindAs(0, DuckType.TimestampNs)[0]
        .format("yyyy-MM-dd HH:mm:ss'.'ffffff") ==
        "1992-09-20 11:30:00.123456"

# ---------------------------------------------------------------------------
# Codec matrix — extended type coverage
# ---------------------------------------------------------------------------

test "TimestampTz round-trip (codec: fromDuckTimestampTz / toDuckTimestampTz)":
  let conn = newDatabase().connect()
  # 12:30 at +05 == 07:30 UTC. TIMESTAMPTZ stores the UTC instant only; the
  # zone offset is not part of the value, so the read-back time is 07:30 UTC
  # with utcOffset 0. The full date is preserved.
  let r = conn.execute("SELECT TIMESTAMPTZ '2020-06-15 12:30:00+05'")
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.TimestampTz
    let z = v[0]
    check z.time == dateTime(2020, mJun, 15, 7, 30, 0, zone = utc()).toTime
    check z.utcOffset == 0
    check z.isDst == false

  # A pre-epoch TIMESTAMPTZ must survive with its date intact.
  let r2 = conn.execute("SELECT TIMESTAMPTZ '1969-07-20 20:17:40+00'")
  for chunk in r2:
    let z = chunk.vector(0).bindAs(DuckType.TimestampTz)[0]
    check z.time == dateTime(1969, mJul, 20, 20, 17, 40, zone = utc()).toTime

test "TimestampS / Ms / Ns sub-second preservation (codec: fromDuckTimestamp*)":
  let conn = newDatabase().connect()
  let r = conn.execute("""
    SELECT
      TIMESTAMP_S '2020-01-01 12:00:00.999'          AS s,
      TIMESTAMP_MS '2020-01-01 12:00:00.999'         AS ms,
      TIMESTAMP_NS '2020-01-01 12:00:00.999888777'   AS ns
  """)
  for chunk in r:
    let s = chunk.vector(0).bindAs(DuckType.TimestampS)[0]
    check s.year == 2020
    let ms = chunk.vector(1).bindAs(DuckType.TimestampMs)[0]
    check ms.year == 2020
    let ns = chunk.vector(2).bindAs(DuckType.TimestampNs)[0]
    check ns.year == 2020

test "toTimestamp preserves microseconds":
  let dt = dateTime(2024, mJan, 1, 12, 30, 45, 123_000).inZone(utc())
  let raw = toTimestamp(Timestamp(dt))
  check raw.micros == dt.toTime.toUnix * 1_000_000 + 123
  let back = fromTimestamp(raw.micros)
  check DateTime(back) == dt

test "toDatetime pre-epoch dates":
  # floorDiv semantics: any time within a calendar day maps to that day's
  # epoch-day index (truncation toward zero would map 1969-12-31T12:00 to
  # day 0 = 1970-01-01, which is wrong).
  check toDatetime(dateTime(1969, mDec, 31, 12, 0, 0, zone = utc())).days == -1'i32
  check toDatetime(dateTime(1969, mDec, 31, 0, 0, 0, zone = utc())).days == -1'i32
  check toDatetime(dateTime(1970, mJan, 2, 0, 0, 0, zone = utc())).days == 1'i32
  # Dates carry only the day: a round-trip returns midnight of the same day.
  check fromDatetime(toDatetime(dateTime(1969, mJul, 20, 20, 17, 0, zone = utc()))) ==
        dateTime(1969, mJul, 20, 0, 0, 0, zone = utc())

test "UHugeInt round-trip (codec: toUHugeInt / fromUHugeInt)":
  let conn = newDatabase().connect()
  discard conn.execute("CREATE TABLE uhi_test (u UHUGEINT)")
  let val = not zero(UInt128)
  conn.executeMaterialized("INSERT INTO uhi_test VALUES (?)", (val,))
  let r = conn.execute("SELECT u FROM uhi_test")
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.UHugeInt
    check v[0] == val

test "UUID round-trip (codec: toDuckUuid / fromDuckUuid)":
  let conn = newDatabase().connect()
  conn.execute("CREATE TABLE uuid_test (u UUID)")
  let uStr = "550e8400-e29b-41d4-a716-446655440000"
  conn.executeMaterialized("INSERT INTO uuid_test VALUES (?::UUID)", (uStr,))
  let r = conn.execute("SELECT u FROM uuid_test")
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.UUID
    check $v[0] == uStr
    check $v[0] == $fromDuckUuid(toDuckUuid(v[0]))

when defined(i386) or defined(amd64):
  test "Decimal width buckets (codec: fromDuckDecimal width branches ≤4, ≤9, ≤18, >18)":
    let conn = newDatabase().connect()
    let r = conn.execute("""
      SELECT
        CAST(1.234 AS DECIMAL(4,3))       AS w4,    -- width ≤4 → int16
        CAST(12345.67 AS DECIMAL(9,2))     AS w9,    -- width ≤9 → int32
        CAST(123456789.1 AS DECIMAL(18,1)) AS w18,   -- width ≤18 → int64
        CAST(1.234567890123456789 AS DECIMAL(38,18)) AS w38  -- width >18 → hugeint
    """)
    for chunk in r:
      check $chunk.bindAs(0, DuckType.Decimal)[0] == "1.234"
      check $chunk.bindAs(1, DuckType.Decimal)[0] == "12345.67"
      check $chunk.bindAs(2, DuckType.Decimal)[0] == "123456789.1"
      check $chunk.bindAs(3, DuckType.Decimal)[0] == "1.234567890123456789"

test "Double NaN / ±Inf round-trip (codec: double NaN path)":
  let conn = newDatabase().connect()
  discard conn.execute("CREATE TABLE float_edge (d DOUBLE)")
  conn.execute("INSERT INTO float_edge VALUES ('NaN'::DOUBLE)")
  conn.execute("INSERT INTO float_edge VALUES ('Infinity'::DOUBLE)")
  conn.execute("INSERT INTO float_edge VALUES ('-Infinity'::DOUBLE)")
  let r = conn.execute("SELECT d FROM float_edge")
  var foundNaN, foundInf, foundNegInf = false
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.Double
    for i in 0 ..< v.len:
      if v[i] != v[i]: foundNaN = true  # NaN is the only value not equal to itself
      elif v[i] > 1e300: foundInf = true
      elif v[i] < -1e300: foundNegInf = true
  check foundNaN and foundInf and foundNegInf

test "Interval full-field round-trip (codec: fromInterval all components)":
  let conn = newDatabase().connect()
  let r = conn.execute("""
    SELECT INTERVAL '1 year 2 months 3 days 4 hours 5 minutes 6 seconds' AS iv
  """)
  for chunk in r:
    let iv = chunk.vector(0).bindAs(DuckType.Interval)[0]
    check iv.years == 1
    check iv.months == 2
    check iv.days == 3
    check iv.hours == 4
    check iv.minutes == 5
    check iv.seconds == 6

test "Time with fractional seconds (codec: fromTime modulo)":
  let conn = newDatabase().connect()
  let r = conn.execute("SELECT TIME '01:02:03.123456'")
  for chunk in r:
    let t = chunk.vector(0).bindAs(DuckType.Time)[0]
    check t == initTime(3723, 123_456_000)

test "Blob with embedded zero bytes (codec: blob path)":
  let conn = newDatabase().connect()
  let r = conn.execute("SELECT '\\x00\\x01\\x00\\xFF'::BLOB")
  for chunk in r:
    check chunk.bindAs(0, DuckType.Blob)[0] ==
      @[byte 0, 1, 0, 255]

test "VARCHAR with Unicode and emoji (codec: string path)":
  let conn = newDatabase().connect()
  discard conn.execute("CREATE TABLE unicode_test (s VARCHAR)")
  let emoji = "héllo wörld 😊"
  conn.executeMaterialized("INSERT INTO unicode_test VALUES (?)", (emoji,))
  let r = conn.execute("SELECT s FROM unicode_test")
  for chunk in r:
    let s = chunk.vector(0).bindAs(DuckType.Varchar)[0]
    check s == emoji

suite "Null edge cases":
  test "Null TimestampTz round-trips correctly":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE tstz (t TIMESTAMPTZ)")
    conn.execute("INSERT INTO tstz VALUES (NULL), ('2024-01-15 10:30:00+00'::TIMESTAMPTZ), (NULL)")
    for chunk in conn.execute("SELECT t FROM tstz ORDER BY t NULLS LAST"):
      let v = chunk.bindAs(0, DuckType.TimestampTz)
      check v.valid(0)
      check not v.valid(1)
      check not v.valid(2)

  test "Null Interval round-trips correctly":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE ivs (i INTERVAL)")
    conn.execute("INSERT INTO ivs VALUES (NULL), ('2 days'::INTERVAL), (NULL)")
    for chunk in conn.execute("SELECT i FROM ivs ORDER BY i NULLS LAST"):
      let v = chunk.bindAs(0, DuckType.Interval)
      check v.valid(0)
      check not v.valid(1)
      check not v.valid(2)

  test "Null HugeInt round-trips correctly":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE hi (h HUGEINT)")
    conn.execute("INSERT INTO hi VALUES (NULL), (42), (NULL)")
    for chunk in conn.execute("SELECT h FROM hi ORDER BY h NULLS LAST"):
      let v = chunk.bindAs(0, DuckType.HugeInt)
      check v.valid(0)
      check not v.valid(1)
      check not v.valid(2)

  test "Null UHugeInt round-trips correctly":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE uhi (u UHUGEINT)")
    conn.execute("INSERT INTO uhi VALUES (NULL), (42), (NULL)")
    for chunk in conn.execute("SELECT u FROM uhi ORDER BY u NULLS LAST"):
      let v = chunk.bindAs(0, DuckType.UHugeInt)
      check v.valid(0)
      check not v.valid(1)
      check not v.valid(2)

  test "Null Decimal round-trips correctly":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE decs (d DECIMAL(10,2))")
    conn.execute("INSERT INTO decs VALUES (NULL), (3.14), (NULL)")
    for chunk in conn.execute("SELECT d FROM decs ORDER BY d NULLS LAST"):
      let v = chunk.vector(0)
      check v.valid(0)
      check not v.valid(1)
      check not v.valid(2)

suite "Type mapping edge cases":
  test "Enum type creates and reads correctly":
    let conn = newDatabase().connect()
    conn.execute("CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy')")
    conn.execute("CREATE TABLE enums (m mood)")
    conn.execute("INSERT INTO enums VALUES ('sad'), ('ok'), ('happy')")
    # Raw enum codec path: bindAs(DuckType.Enum) yields the enum indices
    for chunk in conn.execute("SELECT m FROM enums ORDER BY m"):
      let v = chunk.vector(0).bindAs(DuckType.Enum)
      check v.toSeq == @[0'u, 1, 2]
    # DuckDB's enum→varchar cast path
    for chunk in conn.execute("SELECT m::VARCHAR FROM enums ORDER BY m"):
      check chunk.vector(0).bindAs(DuckType.Varchar).toSeq == @["sad", "ok", "happy"]

  test "Interval string representation":
    let conn = newDatabase().connect()
    for chunk in conn.execute("SELECT '2 days 3 hours'::INTERVAL"):
      let iv = chunk.vector(0).bindAs(DuckType.Interval)[0]
      check iv.days == 2
      check iv.hours == 3
      check $iv == "2 days and 3 hours"
