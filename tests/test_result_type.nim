import std/[times, strformat]
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
