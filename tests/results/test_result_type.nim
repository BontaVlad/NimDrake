import std/[unittest, times, tables, strformat, sequtils, sugar]
import nint128
import ../../src/[database, query, query_result]

# TODO: expand tests with more scenarios, especially the unhappy types

suite "results":
  test "Test Boolean result type":
    let con = connect()
    con.execute("CREATE TABLE booleans(i BOOLEAN);")
    con.execute("INSERT INTO booleans VALUES (true), (false), (true);")
    let outcome = con.execute("SELECT * FROM booleans").fetchall()
    check outcome[0].valueBoolean == @[true, false, true]

  test "Test TinyInt result type":
    let con = connect()
    con.execute(
      "CREATE TABLE tinyints(i TINYINT); INSERT INTO tinyints VALUES (-128), (0), (127);"
    )
    let outcome = con.execute("SELECT * FROM tinyints").fetchall()
    check outcome[0].valueTinyint == @[-128'i8, 0'i8, 127'i8]

  test "Test SmallInt result type":
    let con = connect()
    con.execute(
      "CREATE TABLE smallints(i SMALLINT); INSERT INTO smallints VALUES (-32768), (0), (32767);"
    )
    let outcome = con.execute("SELECT * FROM smallints").fetchall()
    check outcome[0].valueSmallint == @[-32768'i16, 0'i16, 32767'i16]

  test "Test Integer result type":
    let con = connect()
    con.execute(
      "CREATE TABLE integers(i INTEGER); INSERT INTO integers VALUES (-2147483648), (0), (2147483647);"
    )
    let outcome = con.execute("SELECT * FROM integers").fetchall()
    check outcome[0].valueInteger == @[-2147483648'i32, 0'i32, 2147483647'i32]

  test "Test BigInt result type":
    let con = connect()
    con.execute(
      "CREATE TABLE bigints(i BIGINT); INSERT INTO bigints VALUES (-9223372036854775808), (0), (9223372036854775807);"
    )
    let outcome = con.execute("SELECT * FROM bigints").fetchall()
    check outcome[0].valueBigint ==
      @[-9223372036854775808'i64, 0'i64, 9223372036854775807'i64]

  test "Test UTinyInt result type":
    let con = connect()
    con.execute(
      "CREATE TABLE utinyints(i UTINYINT); INSERT INTO utinyints VALUES (255), (0), (127);"
    )
    let outcome = con.execute("SELECT * FROM utinyints").fetchall()
    check outcome[0].valueUtinyint == @[255'u8, 0'u8, 127'u8]

  test "Test USmallInt result type":
    let con = connect()
    con.execute(
      "CREATE TABLE usmallints(i USMALLINT); INSERT INTO usmallints VALUES (0), (32767), (65535);"
    )
    let outcome = con.execute("SELECT * FROM usmallints").fetchall()
    check outcome[0].valueUsmallint == @[0'u16, 32767'u16, 65535'u16]

  test "Test UInteger result type":
    let con = connect()
    con.execute(
      "CREATE TABLE uintegers(i UINTEGER); INSERT INTO uintegers VALUES (0), (2147483647), (4294967295);"
    )
    let outcome = con.execute("SELECT * FROM uintegers").fetchall()
    check outcome[0].valueUinteger == @[0'u32, 2147483647'u32, 4294967295'u32]

  test "Test UBigInt result type":
    let con = connect()
    con.execute(
      "CREATE TABLE ubigints(i UBIGINT); INSERT INTO ubigints VALUES (0), (922337203685477580), (1844674407370940000);"
    )
    let outcome = con.execute("SELECT * FROM ubigints").fetchall()
    check outcome[0].valueUbigint ==
      @[0'u64, 922337203685477580'u64, 1844674407370940000'u64]

  test "Test Float result type":
    let con = connect()
    con.execute(
      "CREATE TABLE floats(i FLOAT); INSERT INTO floats VALUES (-3.4), (0.0), (0.42);"
    )
    let outcome = con.execute("SELECT * FROM floats").fetchall()
    check outcome[0].valueFloat == @[-3.4'f, 0.0'f, 0.42'f]

  test "Test Double result type":
    let con = connect()
    con.execute(
      "CREATE TABLE doubles(i DOUBLE); INSERT INTO doubles VALUES (-3.4), (0.0), (0.42);"
    )
    let outcome = con.execute("SELECT * FROM doubles").fetchall()
    check outcome[0].valueDouble == @[-3.4, 0.0, 0.42]

  test "Test Timestamp result type":
    let con = connect()
    let outcome =
      con.execute("SELECT TIMESTAMP '1992-09-20 11:30:00.123456789';").fetchall()
    check outcome[0].valueTimestamp[0].format("yyyy-MM-dd HH:mm:ss'.'ffffff") ==
      "1992-09-20 11:30:00.123456"

  test "Test Date result type":
    let con = connect()
    con.execute("CREATE TABLE IF NOT EXISTS dates (dt DATE);")
    con.execute("INSERT INTO dates VALUES ('1992-09-20')")
    let outcome = con.execute("SELECT * FROM dates").fetchall()
    check outcome[0].valueDate[0].year == 1992

  test "Test Time result type":
    let con = connect()
    con.execute("CREATE TABLE IF NOT EXISTS times (tm TIME);")
    con.execute("INSERT INTO times VALUES ('01:02:03')")
    let outcome = con.execute("SELECT * FROM times").fetchall()
    check outcome[0].valueTime[0] == initTime(3723, 0)

  test "Test Interval result type":
    let
      con = connect()
      # -- Returns 12 months; equivalent to `to_years(CAST(trunc(1.5) AS INTEGER))`
      outcome =
        con.execute("SELECT INTERVAL '1.5' YEARS AS months_interval;").fetchAllNamed()
    check outcome["months_interval"].valueInterval[0].months == 12

  test "Test HugeInt result type":
    let con = connect()
    con.execute("CREATE TABLE IF NOT EXISTS huge (hg HUGEINT);")
    con.execute(fmt"INSERT INTO huge VALUES ({high(Int128)})")
    let outcome = con.execute("SELECT * FROM huge").fetchall()
    check i128(outcome[0].valueHugeInt[0].lo) == i128("18446744073709551615")

  test "Test Varchar result type":
    let con = connect()
    con.execute(
      "CREATE TABLE varchars(i VARCHAR); INSERT INTO varchars VALUES ('foo'), ('bar'), ('baz');"
    )
    let outcome = con.execute("SELECT * FROM varchars").fetchall()
    check outcome[0].valueVarchar == @["foo", "bar", "baz"]

  test "Test Blob result type":
    let
      con = connect()
      outcome = con.execute("SELECT 'AB'::BLOB;").fetchAll()
    check outcome[0].valueBlob[0] == @[byte(ord('A')), byte(ord('B'))]
  # TODO: this leaks memory
  # test "Test Decimal result type":
  #   let
  #       con = connect()
  #       outcome = con.execute("SELECT CAST(12.3456 AS DECIMAL);").fetchAll()
  #   check outcome[0].valueDecimal[0] == newDecimal("12.346")
  test "Test TimestampS result type":
    let con = connect()
    let outcome =
      con.execute("SELECT TIMESTAMP_S '1992-09-20 11:30:00.123456789';").fetchall()
    check outcome[0].valueTimestampS[0].format("yyyy-MM-dd HH:mm:ss'.'ffffff") ==
      "1992-09-20 11:30:00.000000"

  test "Test TimestampMs result type":
    let con = connect()
    let outcome =
      con.execute("SELECT TIMESTAMP_MS '1992-09-20 11:30:00.123456789';").fetchall()
    check outcome[0].valueTimestampMs[0].format("yyyy-MM-dd HH:mm:ss'.'ffffff") ==
      "1992-09-20 11:30:00.123000"
  test "Test TimestampNs result type":
    let con = connect()
    let outcome =
      con.execute("SELECT TIMESTAMP_NS '1992-09-20 11:30:00.123456789';").fetchall()
    check outcome[0].valueTimestampNs[0].format("yyyy-MM-dd HH:mm:ss'.'ffffff") ==
      "1992-09-20 11:30:00.123456"
  test "Test Enum result type":
    let con = connect()
    con.execute("CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy');")
    con.execute("CREATE TABLE person (name TEXT, current_mood mood);")
    con.execute(
      "INSERT INTO person VALUES ('Pedro', 'happy'), ('Mark', NULL), ('Pagliacci', 'sad'), ('Mr. Mackey', 'ok');"
    )
    let outcome =
      con.execute("SELECT * FROM person WHERE current_mood = 'sad';").fetchall()
    check outcome[0].valueVarchar[0] == "Pagliacci"
    check outcome[1].valueEnum[0] == 0
  test "Test List result type":
    let
      con = connect()
      outcome = con
        .execute(
          "SELECT CASE WHEN i % 5 = 0 THEN NULL WHEN i % 2 = 0 THEN [i, i + 1] ELSE [i * 42, NULL, i * 84] END FROM range(10) t(i)"
        )
        .fetchall()

    # echo outcome[0].valueList[0].toSeq
    let firstArrayChild =
      outcome[0].valueList[0].toSeq.filter(c => c.isValid).map(c => c.valueBigInt)
    check firstArrayChild == @[42'i64, 84'i64]
    let secondArrayChild =
      outcome[0].valueList[1].toSeq.filter(c => c.isValid).map(c => c.valueBigInt)
    check secondArrayChild == @[2'i64]

  test "Test Struct result type":
    let
      con = connect()
      outcome = con
        .execute(
          "SELECT CASE WHEN i%5=0 THEN NULL ELSE {'col1': i, 'col2': CASE WHEN i%2=0 THEN NULL ELSE 100 + i * 42 END} END FROM range(10) t(i);"
        )
        .fetchall()
    check outcome[0].valueStruct[1]["col1"].valueBigInt == 1
    check outcome[0].valueStruct[1]["col2"].valueBigInt == 142
    check $outcome[0].valueStruct[2] == """{"col1": 2, "col2": }"""
