import unittest
import ../../src/[api, database, query, query_result, exceptions]

suite "tests":
  test "DuckDB init":
    let _ = connect()

  test "Create table":
    let con = connect()
    con.execute("CREATE TABLE integers(i INTEGER);")

  test "Incorrect query throws an error":
    let con = connect()
    expect(OperationError):
      con.execute("something very wrong;")

  test "Insert with prepared statements":
    let con = connect()
    con.execute("CREATE TABLE combined(i INTEGER, j VARCHAR);")
    con.execute(
      "INSERT INTO combined VALUES (6, 'foo'), (5, 'bar'), (?, ?);", ("7", "baz")
    )
    let outcome = con.execute("SELECT * FROM combined").fetchall()
    check outcome[0].valueInteger == @[6'i32, 5'i32, 7'i32]
    check outcome[1].valueVarChar == @["foo", "bar", "baz"]

  test "Insert with appender":
    let con = connect()
    con.execute("CREATE TABLE integers(i INTEGER, j INTEGER);")
    let expected = @[@["6", "4"], @["5", "6"], @["7", "8"]]
    con.appender("integers", expected)
    let outcome = con.execute("SELECT * FROM integers").fetchall()
    check outcome[0].valueInteger == @[6'i32, 5'i32, 7'i32]
    check outcome[1].valueInteger == @[4'i32, 6'i32, 8'i32]

  test "Insert with all appenders":
    let con = connect()
    con.execute(
      """
        CREATE TABLE foo_table (
          bool_val BOOLEAN,
          int8_val TINYINT,
          int16_val SMALLINT,
          int32_val INTEGER,
          int64_val BIGINT,
          uint8_val UTINYINT,
          uint16_val USMALLINT,
          uint32_val UINTEGER,
          uint64_val UBIGINT,
          float32_val FLOAT,
          float64_val DOUBLE,
          string_val VARCHAR,
        );
      """
    )
    var appender = newAppender(con, "foo_table")
    # let blob = @[uint8(1), uint8(2), uint8(3)]

    check(appender.append(true), "Failed to append bool")
    check(appender.append(int8(-128)), "Failed to append int8")
    check(appender.append(int16(32767)), "Failed to append int16")
    check(appender.append(int32(-2147483648)), "Failed to append int32")
    check(appender.append(int64(9223372036854775807)), "Failed to append int64")
    check(appender.append(uint8(255)), "Failed to append uint8")
    check(appender.append(uint16(65535)), "Failed to append uint16")
    check(appender.append(uint32(4294967295)), "Failed to append uint32")
    check(appender.append(uint64(18446744073709551615'u64)), "Failed to append uint64")
    check(appender.append(float32(3.14'f32)), "Failed to append float32")
    check(appender.append(float64(3.14159265359'f64)), "Failed to append float64")
    check(appender.append("hello"), "Failed to append string")
    # check(appender.append(blob), "Failed to append blob")
    # check(appender.append(void), "Failed to append null")
    check(duckdb_appender_end_row(appender), "Failed to end row on appender")
    check(duckdb_appender_close(appender), "Failed to close the appender")

    # Fetch the data and verify correctness
    let outcome = con.execute("SELECT * FROM foo_table").fetchall()
    check outcome[0].valueBoolean == @[true]
    check outcome[1].valueTinyInt == @[-128'i8]
    check outcome[2].valueSmallInt == @[32767'i16]
    check outcome[3].valueInteger == @[-2147483648'i32]
    check outcome[4].valueBigInt == @[9223372036854775807'i64]
    check outcome[5].valueUTinyInt == @[255'u8]
    check outcome[6].valueUSmallInt == @[65535'u16]
    check outcome[7].valueUInteger == @[4294967295'u32]
    check outcome[8].valueUBigInt == @[18446744073709551615'u64]
    check outcome[9].valueFloat == @[3.14'f32]
    check outcome[10].valueDouble == @[3.14159265359'f64]
    check outcome[11].valueVarChar == @["hello"]

  test "Insert with already made prepared statement":
    let con = connect()
    con.execute(
      """
        CREATE TABLE prepared_table (
          bool_val BOOLEAN,
          int8_val TINYINT,
          int16_val SMALLINT,
          int32_val INTEGER,
          int64_val BIGINT,
          uint8_val UTINYINT,
          uint16_val USMALLINT,
          uint32_val UINTEGER,
          uint64_val UBIGINT,
          float32_val FLOAT,
          float64_val DOUBLE,
          string_val VARCHAR,
        );
      """
    )

    let prepared = newStatement(
      con, "INSERT INTO prepared_table VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
    )
    con.execute(
      prepared,
      (
        true,
        int8(-128),
        int16(32767),
        int32(-2147483648),
        int64(9223372036854775807),
        uint8(255),
        uint16(65535),
        uint32(4294967295),
        uint64(18446744073709551615'u64),
        float32(3.14'f32),
        float64(3.14159265359'f64),
        "hello",
      ),
    )
    let outcome = con.execute("SELECT * FROM prepared_table").fetchall()
    check outcome[0].valueBoolean == @[true]
    check outcome[1].valueTinyInt == @[-128'i8]
    check outcome[2].valueSmallInt == @[32767'i16]
    check outcome[3].valueInteger == @[-2147483648'i32]
    check outcome[4].valueBigInt == @[9223372036854775807'i64]
    check outcome[5].valueUTinyInt == @[255'u8]
    check outcome[6].valueUSmallInt == @[65535'u16]
    check outcome[7].valueUInteger == @[4294967295'u32]
    check outcome[8].valueUBigInt == @[18446744073709551615'u64]
    check outcome[9].valueFloat == @[3.14'f32]
    check outcome[10].valueDouble == @[3.14159265359'f64]
    check outcome[11].valueVarChar == @["hello"]
