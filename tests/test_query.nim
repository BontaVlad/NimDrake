import std/[sequtils, times]
import unittest2
import nint128
import ../src/[api, database, datachunk, types, query, query_result, transaction, exceptions]

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
    conn.newAppender("integers", expected)
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
    check len(appender.columns.toSeq()) == 12

    appender.append(true)
    appender.append(int8(-128))
    appender.append(int16(32767))
    appender.append(int32(-2147483648))
    appender.append(int64(9223372036854775807))
    appender.append(uint8(255))
    appender.append(uint16(65535))
    appender.append(uint32(4294967295))
    appender.append(uint64(18446744073709551615'u64))
    appender.append(float32(3.14'f32))
    appender.append(float64(3.14159265359'f64))
    appender.append("hello")
    # check(appender.append(blob), "Failed to append blob")
    # check(appender.append(void), "Failed to append null")
    appender.endRow()
    appender.close()

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
  #     let blobData = @[byte(1), byte(2), byte(3)]
  #     conn.execute(prepared, (blobData, ))
  #     # let outcome = conn.execute("SELECT blob_val FROM prepared_table;").fetchall()
  #     # check outcome[0].valueBlob == @[blobData]

  # test "Bind null val":
  #   conn.transient:
  #     conn.execute("CREATE TABLE prepared_table (nullable_val INTEGER);")
  #     let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
  #     conn.execute(prepared, (nil, ))
  #     echo conn.execute("SELECT nullable_val FROM prepared_table;")
  #     # let outcome = conn.execute("SELECT nullable_val FROM prepared_table;").fetchall()
  #     # check outcome[0].isNull == true

suite "Test appender dispatch":

  setup:
    let db = newDatabase()
    let conn = db.connect()

  test "Append bool val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (bool_val BOOLEAN);")
      var appender = newAppender(conn, "appender_table")
      appender.append(true)
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT bool_val FROM appender_table;").fetchall()
      check outcome[0].valueBoolean == @[true]

  test "Append int8 val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (int8_val TINYINT);")
      var appender = newAppender(conn, "appender_table")
      appender.append(42'i8)
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT int8_val FROM appender_table;").fetchall()
      check outcome[0].valueTinyInt == @[42'i8]

  test "Append int16 val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (int16_val SMALLINT);")
      var appender = newAppender(conn, "appender_table")
      appender.append(1000'i16)
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT int16_val FROM appender_table;").fetchall()
      check outcome[0].valueSmallInt == @[1000'i16]

  test "Append int32 val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (int32_val INTEGER);")
      var appender = newAppender(conn, "appender_table")
      appender.append(1_000_000'i32)
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT int32_val FROM appender_table;").fetchall()
      check outcome[0].valueInteger == @[1_000_000'i32]

  test "Append int64 val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (int64_val BIGINT);")
      var appender = newAppender(conn, "appender_table")
      appender.append(1_000_000_000'i64)
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT int64_val FROM appender_table;").fetchall()
      check outcome[0].valueBigInt == @[1_000_000_000'i64]

  test "Append uint8 val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (uint8_val UTINYINT);")
      var appender = newAppender(conn, "appender_table")
      appender.append(200'u8)
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT uint8_val FROM appender_table;").fetchall()
      check outcome[0].valueUTinyInt == @[200'u8]

  test "Append uint16 val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (uint16_val USMALLINT);")
      var appender = newAppender(conn, "appender_table")
      appender.append(50000'u16)
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT uint16_val FROM appender_table;").fetchall()
      check outcome[0].valueUSmallInt == @[50000'u16]

  test "Append uint32 val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (uint32_val UINTEGER);")
      var appender = newAppender(conn, "appender_table")
      appender.append(3_000_000_000'u32)
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT uint32_val FROM appender_table;").fetchall()
      check outcome[0].valueUInteger == @[3_000_000_000'u32]

  test "Append uint64 val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (uint64_val UBIGINT);")
      var appender = newAppender(conn, "appender_table")
      appender.append(18_446_744_073_709_551_615'u64)
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT uint64_val FROM appender_table;").fetchall()
      check outcome[0].valueUBigInt == @[18_446_744_073_709_551_615'u64]

  test "Append float val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (float_val REAL);")
      var appender = newAppender(conn, "appender_table")
      appender.append(3.14'f32)
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT float_val FROM appender_table;").fetchall()
      check outcome[0].valueFloat == @[3.14'f32]

  test "Append double val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (double_val DOUBLE);")
      var appender = newAppender(conn, "appender_table")
      appender.append(3.14159265359)
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT double_val FROM appender_table;").fetchall()
      check outcome[0].valueDouble == @[3.14159265359]

  test "Append varchar val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (varchar_val VARCHAR);")
      var appender = newAppender(conn, "appender_table")
      appender.append("Hello, World!")
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT varchar_val FROM appender_table;").fetchall()
      check outcome[0].valueVarchar == @["Hello, World!"]

  test "Append HugeInt val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (hugeint_val HUGEINT);")
      var appender = newAppender(conn, "appender_table")
      let hugeIntVal = i128("-18446744073709551616")
      appender.append(hugeIntVal)
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT hugeint_val FROM appender_table;").fetchall()
      check outcome[0].valueHugeInt == @[hugeIntVal]

  test "Append UHugeInt val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (uhugeint_val UHUGEINT);")
      var appender = newAppender(conn, "appender_table")
      let uHugeIntVal = u128("18446744073709551616")
      appender.append(uHugeIntVal)
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT uhugeint_val FROM appender_table;").fetchall()
      check outcome[0].valueUHugeInt == @[uHugeIntVal]

  test "Append timestamp val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (timestamp_val TIMESTAMP);")
      var appender = newAppender(conn, "appender_table")
      let timestamp = Timestamp(parse("2023-12-25T13:45:30", "yyyy-MM-dd'T'HH:mm:ss"))
      appender.append(timestamp)
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT timestamp_val FROM appender_table;").fetchall()
      check outcome[0].valueTimestamp == @[timestamp]

  test "Append date val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (date_val DATE);")
      var appender = newAppender(conn, "appender_table")
      let date = parse("2023-12-25", "yyyy-MM-dd", zone=utc())
      appender.append(date)
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT date_val FROM appender_table;").fetchall()
      check outcome[0].valueDate == @[date]

  test "Append time val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (time_val TIME);")
      var appender = newAppender(conn, "appender_table")
      let time = parse("2023-12-25T15:30:00", "yyyy-MM-dd'T'HH:mm:ss", zone=utc()).toTime()
      appender.append(time)
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT time_val FROM appender_table;").fetchall()
      check outcome[0].valueTime == @[time]

  test "Append interval val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (interval_val INTERVAL);")
      var appender = newAppender(conn, "appender_table")
      let valInterval = initTimeInterval(years=1, months=5, days=1, hours=2, minutes=27, seconds=16)
      appender.append(valInterval)
      appender.endRow()
      appender.flush()
      let outcome = conn.execute("SELECT interval_val FROM appender_table;").fetchall()
      check outcome[0].valueInterval == @[valInterval]

  test "Append DataChunk val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (int_val INTEGER, varchar_val VARCHAR, bool_val BOOLEAN);")
      var appender = newAppender(conn, "appender_table")

      let types =
        @[
          DuckType.Integer,
          DuckType.Varchar,
          DuckType.Boolean
        ]
      var chunk = newDataChunk(types)
      let
        intValues = @[1'i32, 2'i32, 3'i32]
        strValues = @["foo", "bar", "baz"]
        boolValues = @[true, false, true]

      chunk[0] = intValues
      chunk[1] = strValues
      chunk[2] = boolValues

      appender.append(chunk)
      appender.flush()

      let outcome = conn.execute("SELECT * FROM appender_table;").fetchall()
      check outcome[0].valueInteger == intValues
      check outcome[1].valueVarchar == strValues
      check outcome[2].valueBoolean == boolValues
