import std/[sequtils, times]
import unittest2
import nint128
import ../../src/[api, database, types, query, query_result, transaction, exceptions]

suite "Basic queries":

  test "Create table":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE integers(i INTEGER);")

  test "Incorrect query throws an error":
    let conn = newDatabase().connect()
    expect(OperationError):
      conn.execute("something very wrong;")

suite "Prepared/Appender statements":

  test "Prepared statement parameters":
    let conn = newDatabase().connect()

    conn.execute("CREATE TABLE a (i INTEGER, j VARCHAR);")
    var statement = conn.newStatement("INSERT INTO a VALUES (?, ?);")
    let parameters = statement.parameters.toSeq()
    check len(parameters) == 2
    check parameters[0].name == "1"
    check parameters[0].idx == 1
    check parameters[0].tpy == DuckType.Integer
    check parameters[1].name == "2"
    check parameters[1].idx == 2
    check parameters[1].tpy == DuckType.VARCHAR

  test "BindParameter and paramters for prepared statement":
    let conn = newDatabase().connect()

    var statement = conn.newStatement("SELECT CAST($my_val AS BIGINT), CAST($my_second_val AS VARCHAR);")
    let indexes = @[
      statement.bindParameter("my_second_val"),
      statement.bindParameter("my_val")
    ]
    check indexes == @[2, 1]
    let parameters = statement.parameters.toSeq()
    check parameters[0].name == "my_val"
    check parameters[0].idx == 1
    check parameters[1].name == "my_second_val"
    check parameters[1].idx == 2

  test "Insert with prepared statements":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE combined(i INTEGER, j VARCHAR);")
    conn.execute(
      "INSERT INTO combined VALUES (6, 'foo'), (5, 'bar'), (?, ?);", ("7", "baz")
    )
    let outcome = conn.execute("SELECT * FROM combined").fetchall()
    check outcome[0].valueInteger == @[6'i32, 5'i32, 7'i32]
    check outcome[1].valueVarChar == @["foo", "bar", "baz"]

  test "Insert with appender":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE integers(i INTEGER, j INTEGER);")
    let expected = @[@["6", "4"], @["5", "6"], @["7", "8"]]
    conn.appender("integers", expected)
    let outcome = conn.execute("SELECT * FROM integers").fetchall()
    check outcome[0].valueInteger == @[6'i32, 5'i32, 7'i32]
    check outcome[1].valueInteger == @[4'i32, 6'i32, 8'i32]

  test "Insert with all appenders":
    let conn = newDatabase().connect()
    conn.execute(
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
    var appender = newAppender(conn, "foo_table")
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
    let outcome = conn.execute("SELECT * FROM foo_table").fetchall()
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
    let conn = newDatabase().connect()
    conn.execute(
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
      conn, "INSERT INTO prepared_table VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
    )
    conn.execute(
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
    let outcome = conn.execute("SELECT * FROM prepared_table").fetchall()
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

suite "Test bind val dispatch":

  setup:
    let db = newDatabase()
    let conn = db.connect()

  test "Bind bool val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (bool_val BOOLEAN,);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.execute(prepared, (true, ))
      let outcome = conn.execute("SELECT bool_val FROM prepared_table;").fetchall()
      check outcome[0].valueBoolean == @[true]

  test "Bind int8 val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (int8_val TINYINT);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.execute(prepared, (42'i8, ))
      let outcome = conn.execute("SELECT int8_val FROM prepared_table;").fetchall()
      check outcome[0].valueTinyInt == @[42'i8]

  test "Bind int16 val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (int16_val SMALLINT);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.execute(prepared, (1000'i16, ))
      let outcome = conn.execute("SELECT int16_val FROM prepared_table;").fetchall()
      check outcome[0].valueSmallInt == @[1000'i16]

  test "Bind int32 val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (int32_val INTEGER);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.execute(prepared, (1_000_000'i32, ))
      let outcome = conn.execute("SELECT int32_val FROM prepared_table;").fetchall()
      check outcome[0].valueInteger == @[1_000_000'i32]

  test "Bind int64 val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (int64_val BIGINT);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.execute(prepared, (1_000_000_000'i64, ))
      let outcome = conn.execute("SELECT int64_val FROM prepared_table;").fetchall()
      check outcome[0].valueBigInt == @[1_000_000_000'i64]

  test "Bind uint8 val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (uint8_val UTINYINT);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.execute(prepared, (200'u8, ))
      let outcome = conn.execute("SELECT uint8_val FROM prepared_table;").fetchall()
      check outcome[0].valueUTinyInt == @[200'u8]

  test "Bind uint16 val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (uint16_val USMALLINT);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.execute(prepared, (50000'u16, ))
      let outcome = conn.execute("SELECT uint16_val FROM prepared_table;").fetchall()
      check outcome[0].valueUSmallInt == @[50000'u16]

  test "Bind uint32 val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (uint32_val UINTEGER);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.execute(prepared, (3_000_000_000'u32, ))
      let outcome = conn.execute("SELECT uint32_val FROM prepared_table;").fetchall()
      check outcome[0].valueUInteger == @[3_000_000_000'u32]

  test "Bind uint64 val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (uint64_val UBIGINT);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.execute(prepared, (18_446_744_073_709_551_615'u64, ))
      let outcome = conn.execute("SELECT uint64_val FROM prepared_table;").fetchall()
      check outcome[0].valueUBigInt == @[18_446_744_073_709_551_615'u64]

  test "Bind float val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (float_val REAL);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.execute(prepared, (3.14'f32, ))
      let outcome = conn.execute("SELECT float_val FROM prepared_table;").fetchall()
      check outcome[0].valueFloat == @[3.14'f32]

  test "Bind double val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (double_val DOUBLE);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.execute(prepared, (3.14159265359, ))
      let outcome = conn.execute("SELECT double_val FROM prepared_table;").fetchall()
      check outcome[0].valueDouble == @[3.14159265359]

  test "Bind varchar val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (varchar_val VARCHAR);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.execute(prepared, ("Hello, World!", ))
      let outcome = conn.execute("SELECT varchar_val FROM prepared_table;").fetchall()
      check outcome[0].valueVarchar == @["Hello, World!"]

  test "Bind HugeInt val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (hugeint_val HUGEINT);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      let hugeIntVal = i128("-18446744073709551616")
      conn.execute(prepared, (hugeIntVal, ))
      let outcome = conn.execute("SELECT hugeint_val FROM prepared_table;").fetchall()
      check outcome[0].valueHugeInt == @[hugeIntVal]

  test "Bind UHugeInt val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (uhugeint_val UHUGEINT);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      let uHugeIntVal = u128("18446744073709551616")
      conn.execute(prepared, (uHugeIntVal, ))
      let outcome = conn.execute("SELECT uhugeint_val FROM prepared_table;").fetchall()
      check outcome[0].valueUHugeInt == @[uHugeIntVal]

  test "Bind timestamp val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (timestamp_val TIMESTAMP);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      let timestamp = Timestamp(parse("2023-12-25T13:45:30", "yyyy-MM-dd'T'HH:mm:ss"))
      conn.execute(prepared, (timestamp, ))
      let outcome = conn.execute("SELECT timestamp_val FROM prepared_table;").fetchall()
      check outcome[0].valueTimestamp == @[timestamp]

  test "Bind date val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (date_val DATE);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      let date = parse("2023-12-25", "yyyy-MM-dd", zone=utc())
      conn.execute(prepared, (date, ))
      let outcome = conn.execute("SELECT date_val FROM prepared_table;").fetchall()
      check outcome[0].valueDate == @[date]

  test "Bind time val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (time_val TIME);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      let time = parse("2023-12-25T15:30:00", "yyyy-MM-dd'T'HH:mm:ss", zone=utc()).toTime()
      conn.execute(prepared, (time, ))
      let outcome = conn.execute("SELECT time_val FROM prepared_table;").fetchall()
      check outcome[0].valueTime == @[time]

  test "Bind interval val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (interval_val INTERVAL);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      let valInterval = initTimeInterval(years=1, months=5, days = 1, hours = 2, minutes=27, seconds=16)
      conn.execute(prepared, (valInterval, ))
      let outcome = conn.execute("SELECT interval_val FROM prepared_table;").fetchall()
      check outcome[0].valueInterval == @[valInterval]

  # test "Bind blob val":
  #   conn.transient:
  #     conn.execute("CREATE TABLE prepared_table (blob_val BLOB);")
  #     let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
  #     let blobData = @[byte(1), 2, 3, 4, 5]
  #     conn.execute(prepared, (blobData, ))
  #     let outcome = conn.execute("SELECT blob_val FROM prepared_table;").fetchall()
  #     check outcome[0].valueBlob == @[blobData]

  # test "Bind null val":
  #   conn.transient:
  #     conn.execute("CREATE TABLE prepared_table (nullable_val INTEGER);")
  #     let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
  #     conn.execute(prepared, (nil, ))
  #     let outcome = conn.execute("SELECT nullable_val FROM prepared_table;").fetchall()
  #     check outcome[0].isNull == true


suite "Test append val dispatch":
  test "Val":
    discard
