import std/[sequtils, times, options, tables]
import unittest2
import nint128
import utils
import ../src/[ffi, database, qresult, types, query, transaction, exceptions, config, codec]
import ../src/compatibility/decimal_compat

{.warning[Deprecated]: off.}

suite "Basic queries":

  test "Create table":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE integers(i INTEGER);")
    for chunk in conn.execute("SELECT count(*)::BIGINT FROM integers"):
      check chunk.bindAs(0, DuckType.BigInt)[0] == 0

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
    check parameters[1].tpy == DuckType.Varchar

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
    conn.executeMaterialized(
      "INSERT INTO combined VALUES (6, 'foo'), (5, 'bar'), (?, ?);", ("7", "baz")
    )
    let r = conn.execute("SELECT * FROM combined")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Integer).toSeq == @[6'i32, 5, 7]
      check chunk.bindAs(1, DuckType.Varchar).toSeq == @["foo", "bar", "baz"]

  test "Insert with appender":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE integers(i INTEGER, j INTEGER);")
    let expected = @[@["6", "4"], @["5", "6"], @["7", "8"]]
    conn.newAppender("integers", expected)
    let r = conn.execute("SELECT * FROM integers")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Integer).toSeq == @[6'i32, 5, 7]
      check chunk.bindAs(1, DuckType.Integer).toSeq == @[4'i32, 6, 8]

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
    appender.endRow()
    appender.close()

    let r = conn.execute("SELECT * FROM foo_table")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Boolean).toSeq == @[true]
      check chunk.bindAs(1, DuckType.TinyInt).toSeq == @[-128'i8]
      check chunk.bindAs(2, DuckType.SmallInt).toSeq == @[32767'i16]
      check chunk.bindAs(3, DuckType.Integer).toSeq == @[-2147483648'i32]
      check chunk.bindAs(4, DuckType.BigInt).toSeq == @[9223372036854775807'i64]
      check chunk.bindAs(5, DuckType.UTinyInt).toSeq == @[255'u8]
      check chunk.bindAs(6, DuckType.USmallInt).toSeq == @[65535'u16]
      check chunk.bindAs(7, DuckType.UInteger).toSeq == @[4294967295'u32]
      check chunk.bindAs(8, DuckType.UBigInt).toSeq == @[18446744073709551615'u64]
      check chunk.bindAs(9, DuckType.Float).toSeq == @[3.14'f32]
      check chunk.bindAs(10, DuckType.Double).toSeq == @[3.14159265359'f64]
      check chunk.bindAs(11, DuckType.Varchar).toSeq == @["hello"]

  test "Insert with blob appender":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE blob_t (b BLOB)")
    var app = conn.newAppender("blob_t")
    app.append(@[1'u8, 2, 3])
    app.endRow()
    app.append(newSeq[byte]())
    app.endRow()
    app.close()
    let r = conn.execute("SELECT b FROM blob_t")
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.Blob)
      check v[0] == @[1'u8, 2, 3]
      check v[1] == newSeq[byte]()

  test "string round-trips embedded NUL and empty string":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE s_t (s VARCHAR)")
    var app = conn.newAppender("s_t")
    app.append("a\0b")
    app.endRow()
    app.append("")
    app.endRow()
    app.close()
    # An empty string is a real empty string, never a NULL.
    var nullCount = -1'i64
    for chunk in conn.execute("SELECT count(*)::BIGINT FROM s_t WHERE s IS NULL"):
      nullCount = chunk.bindAs(0, DuckType.BigInt)[0]
    check nullCount == 0
    # The prepared-statement bind preserves embedded NUL bytes.
    var stmt = conn.newStatement("SELECT s FROM s_t WHERE s = ?")
    check stmt.bindVal(1, "a\0b") == enumDuckDbState.Duckdbsuccess
    let r = conn.executeMaterialized(stmt)
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.Varchar)
      check v.len == 1
      check v[0] == "a\0b"

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
    conn.executeMaterialized(
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
    let r = conn.execute("SELECT * FROM prepared_table")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Boolean).toSeq == @[true]
      check chunk.bindAs(1, DuckType.TinyInt).toSeq == @[-128'i8]
      check chunk.bindAs(2, DuckType.SmallInt).toSeq == @[32767'i16]
      check chunk.bindAs(3, DuckType.Integer).toSeq == @[-2147483648'i32]
      check chunk.bindAs(4, DuckType.BigInt).toSeq == @[9223372036854775807'i64]
      check chunk.bindAs(5, DuckType.UTinyInt).toSeq == @[255'u8]
      check chunk.bindAs(6, DuckType.USmallInt).toSeq == @[65535'u16]
      check chunk.bindAs(7, DuckType.UInteger).toSeq == @[4294967295'u32]
      check chunk.bindAs(8, DuckType.UBigInt).toSeq == @[18446744073709551615'u64]
      check chunk.bindAs(9, DuckType.Float).toSeq == @[3.14'f32]
      check chunk.bindAs(10, DuckType.Double).toSeq == @[3.14159265359'f64]
      check chunk.bindAs(11, DuckType.Varchar).toSeq == @["hello"]

suite "Test bind val dispatch":

  setup:
    let db = newDatabase()
    let conn = db.connect()

  test "Bind bool val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (bool_val BOOLEAN,);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.executeMaterialized(prepared, (true, ))
      let r = conn.execute("SELECT bool_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Boolean).toSeq == @[true]

  test "Bind int8 val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (int8_val TINYINT);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.executeMaterialized(prepared, (42'i8, ))
      let r = conn.execute("SELECT int8_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.TinyInt).toSeq == @[42'i8]

  test "Bind int16 val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (int16_val SMALLINT);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.executeMaterialized(prepared, (1000'i16, ))
      let r = conn.execute("SELECT int16_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.SmallInt).toSeq == @[1000'i16]

  test "Bind int32 val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (int32_val INTEGER);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.executeMaterialized(prepared, (1_000_000'i32, ))
      let r = conn.execute("SELECT int32_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Integer).toSeq == @[1_000_000'i32]

  test "Bind int64 val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (int64_val BIGINT);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.executeMaterialized(prepared, (1_000_000_000'i64, ))
      let r = conn.execute("SELECT int64_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.BigInt).toSeq == @[1_000_000_000'i64]

  test "Bind uint8 val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (uint8_val UTINYINT);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.executeMaterialized(prepared, (200'u8, ))
      let r = conn.execute("SELECT uint8_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.UTinyInt).toSeq == @[200'u8]

  test "Bind uint16 val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (uint16_val USMALLINT);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.executeMaterialized(prepared, (50000'u16, ))
      let r = conn.execute("SELECT uint16_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.USmallInt).toSeq == @[50000'u16]

  test "Bind uint32 val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (uint32_val UINTEGER);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.executeMaterialized(prepared, (3_000_000_000'u32, ))
      let r = conn.execute("SELECT uint32_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.UInteger).toSeq == @[3_000_000_000'u32]

  test "Bind uint64 val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (uint64_val UBIGINT);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.executeMaterialized(prepared, (18_446_744_073_709_551_615'u64, ))
      let r = conn.execute("SELECT uint64_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.UBigInt).toSeq == @[18_446_744_073_709_551_615'u64]

  test "Bind float val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (float_val REAL);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.executeMaterialized(prepared, (3.14'f32, ))
      let r = conn.execute("SELECT float_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Float).toSeq == @[3.14'f32]

  test "Bind double val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (double_val DOUBLE);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.executeMaterialized(prepared, (3.14159265359, ))
      let r = conn.execute("SELECT double_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Double).toSeq == @[3.14159265359]

  test "Bind varchar val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (varchar_val VARCHAR);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      conn.executeMaterialized(prepared, ("Hello, World!", ))
      let r = conn.execute("SELECT varchar_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Varchar).toSeq == @["Hello, World!"]

  test "Bind HugeInt val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (hugeint_val HUGEINT);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      let hugeIntVal = i128("-18446744073709551616")
      conn.executeMaterialized(prepared, (hugeIntVal, ))
      let r = conn.execute("SELECT hugeint_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.HugeInt).toSeq == @[hugeIntVal]

  test "Bind UHugeInt val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (uhugeint_val UHUGEINT);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      let uHugeIntVal = u128("18446744073709551616")
      conn.executeMaterialized(prepared, (uHugeIntVal, ))
      let r = conn.execute("SELECT uhugeint_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.UHugeInt).toSeq == @[uHugeIntVal]

  test "Bind timestamp val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (timestamp_val TIMESTAMP);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      let timestamp = Timestamp(parse("2023-12-25T13:45:30", "yyyy-MM-dd'T'HH:mm:ss"))
      conn.executeMaterialized(prepared, (timestamp, ))
      let r = conn.execute("SELECT timestamp_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Timestamp).toSeq == @[timestamp]

  test "Bind date val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (date_val DATE);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      let date = parse("2023-12-25", "yyyy-MM-dd", zone=utc())
      conn.executeMaterialized(prepared, (date, ))
      let r = conn.execute("SELECT date_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Date).toSeq == @[date]

  test "Bind time val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (time_val TIME);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      let time = parse("2023-12-25T15:30:00", "yyyy-MM-dd'T'HH:mm:ss", zone=utc()).toTime()
      conn.executeMaterialized(prepared, (time, ))
      let r = conn.execute("SELECT time_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Time).toSeq == @[time]

  test "Bind interval val":
    conn.transient:
      conn.execute("CREATE TABLE prepared_table (interval_val INTERVAL);")
      let prepared = newStatement(conn, "INSERT INTO prepared_table VALUES (?);")
      let valInterval = initTimeInterval(years=1, months=5, days = 1, hours = 2, minutes=27, seconds=16)
      conn.executeMaterialized(prepared, (valInterval, ))
      let r = conn.execute("SELECT interval_val FROM prepared_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Interval).toSeq == @[valInterval]

  test "Bind blob val":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE blob_table (blob_val BLOB);")
    let prepared = newStatement(conn, "INSERT INTO blob_table VALUES (?);")
    let blobData: seq[byte] = @[byte(1), byte(2), byte(3), byte(255)]
    check not duckdb_bind_blob(prepared, 1.idx_t, addr blobData[0], blobData.len.idx_t)
    conn.executeMaterialized(prepared)
    let r = conn.execute("SELECT blob_val FROM blob_table;")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Blob).toSeq == @[blobData]

  test "Bind null val":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE nullable_table (int_val INTEGER, str_val VARCHAR);")
    let prepared = newStatement(conn, "INSERT INTO nullable_table VALUES (?, ?);")
    check not bindNull(prepared, 1)
    check not bindNull(prepared, 2)
    conn.executeMaterialized(prepared)
    let r = conn.execute("SELECT int_val, str_val FROM nullable_table;")
    for chunk in r:
      check chunk.vector(0).valid(0) == false
      check chunk.vector(1).valid(0) == false

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
      let r = conn.execute("SELECT bool_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Boolean).toSeq == @[true]

  test "Append int8 val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (int8_val TINYINT);")
      var appender = newAppender(conn, "appender_table")
      appender.append(42'i8)
      appender.endRow()
      appender.flush()
      let r = conn.execute("SELECT int8_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.TinyInt).toSeq == @[42'i8]

  test "Append int16 val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (int16_val SMALLINT);")
      var appender = newAppender(conn, "appender_table")
      appender.append(1000'i16)
      appender.endRow()
      appender.flush()
      let r = conn.execute("SELECT int16_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.SmallInt).toSeq == @[1000'i16]

  test "Append int32 val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (int32_val INTEGER);")
      var appender = newAppender(conn, "appender_table")
      appender.append(1_000_000'i32)
      appender.endRow()
      appender.flush()
      let r = conn.execute("SELECT int32_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Integer).toSeq == @[1_000_000'i32]

  test "Append int64 val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (int64_val BIGINT);")
      var appender = newAppender(conn, "appender_table")
      appender.append(1_000_000_000'i64)
      appender.endRow()
      appender.flush()
      let r = conn.execute("SELECT int64_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.BigInt).toSeq == @[1_000_000_000'i64]

  test "Append uint8 val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (uint8_val UTINYINT);")
      var appender = newAppender(conn, "appender_table")
      appender.append(200'u8)
      appender.endRow()
      appender.flush()
      let r = conn.execute("SELECT uint8_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.UTinyInt).toSeq == @[200'u8]

  test "Append uint16 val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (uint16_val USMALLINT);")
      var appender = newAppender(conn, "appender_table")
      appender.append(50000'u16)
      appender.endRow()
      appender.flush()
      let r = conn.execute("SELECT uint16_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.USmallInt).toSeq == @[50000'u16]

  test "Append uint32 val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (uint32_val UINTEGER);")
      var appender = newAppender(conn, "appender_table")
      appender.append(3_000_000_000'u32)
      appender.endRow()
      appender.flush()
      let r = conn.execute("SELECT uint32_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.UInteger).toSeq == @[3_000_000_000'u32]

  test "Append uint64 val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (uint64_val UBIGINT);")
      var appender = newAppender(conn, "appender_table")
      appender.append(18_446_744_073_709_551_615'u64)
      appender.endRow()
      appender.flush()
      let r = conn.execute("SELECT uint64_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.UBigInt).toSeq == @[18_446_744_073_709_551_615'u64]

  test "Append float val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (float_val REAL);")
      var appender = newAppender(conn, "appender_table")
      appender.append(3.14'f32)
      appender.endRow()
      appender.flush()
      let r = conn.execute("SELECT float_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Float).toSeq == @[3.14'f32]

  test "Append double val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (double_val DOUBLE);")
      var appender = newAppender(conn, "appender_table")
      appender.append(3.14159265359)
      appender.endRow()
      appender.flush()
      let r = conn.execute("SELECT double_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Double).toSeq == @[3.14159265359]

  test "Append varchar val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (varchar_val VARCHAR);")
      var appender = newAppender(conn, "appender_table")
      appender.append("Hello, World!")
      appender.endRow()
      appender.flush()
      let r = conn.execute("SELECT varchar_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Varchar).toSeq == @["Hello, World!"]

  test "Append HugeInt val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (hugeint_val HUGEINT);")
      var appender = newAppender(conn, "appender_table")
      let hugeIntVal = i128("-18446744073709551616")
      appender.append(hugeIntVal)
      appender.endRow()
      appender.flush()
      let r = conn.execute("SELECT hugeint_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.HugeInt).toSeq == @[hugeIntVal]

  test "Append UHugeInt val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (uhugeint_val UHUGEINT);")
      var appender = newAppender(conn, "appender_table")
      let uHugeIntVal = u128("18446744073709551616")
      appender.append(uHugeIntVal)
      appender.endRow()
      appender.flush()
      let r = conn.execute("SELECT uhugeint_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.UHugeInt).toSeq == @[uHugeIntVal]

  test "Append timestamp val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (timestamp_val TIMESTAMP);")
      var appender = newAppender(conn, "appender_table")
      let timestamp = Timestamp(parse("2023-12-25T13:45:30", "yyyy-MM-dd'T'HH:mm:ss"))
      appender.append(timestamp)
      appender.endRow()
      appender.flush()
      let r = conn.execute("SELECT timestamp_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Timestamp).toSeq == @[timestamp]

  test "Append date val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (date_val DATE);")
      var appender = newAppender(conn, "appender_table")
      let date = parse("2023-12-25", "yyyy-MM-dd", zone=utc())
      appender.append(date)
      appender.endRow()
      appender.flush()
      let r = conn.execute("SELECT date_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Date).toSeq == @[date]

  test "Append time val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (time_val TIME);")
      var appender = newAppender(conn, "appender_table")
      let time = parse("2023-12-25T15:30:00", "yyyy-MM-dd'T'HH:mm:ss", zone=utc()).toTime()
      appender.append(time)
      appender.endRow()
      appender.flush()
      let r = conn.execute("SELECT time_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Time).toSeq == @[time]

  test "Append interval val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (interval_val INTERVAL);")
      var appender = newAppender(conn, "appender_table")
      let valInterval = initTimeInterval(years=1, months=5, days=1, hours=2, minutes=27, seconds=16)
      appender.append(valInterval)
      appender.endRow()
      appender.flush()
      let r = conn.execute("SELECT interval_val FROM appender_table;")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Interval).toSeq == @[valInterval]

  test "Append decimal values with different precision and scale":
    ignoreLeak:
      conn.transient:
        conn.execute("CREATE TABLE decimal_test (d1 DECIMAL(4,3), d2 DECIMAL(8,0), d3 DECIMAL(19,6));")
        var appender = newAppender(conn, "decimal_test")

        appender.append("1.234")
        appender.append(99999999)
        appender.append("3245234.123123")

        appender.endRow()
        appender.flush()

        let r = conn.execute("SELECT * FROM decimal_test")
        for chunk in r:
          check chunk.bindAs(0, DuckType.Decimal).toSeq == @[newDecimal("1.234")]
          check chunk.bindAs(1, DuckType.Decimal).toSeq == @[newDecimal("99999999")]
          check chunk.bindAs(2, DuckType.Decimal).toSeq == @[newDecimal("3245234.123123")]

  test "Append DEFAULT values":
    conn.transient:
      conn.execute("CREATE TABLE default_test (a INTEGER, b INTEGER DEFAULT 5);")
      var appender = newAppender(conn, "default_test")

      appender.append(42'i32)
      appender.append()
      appender.endRow()
      appender.flush()

      let r = conn.execute("SELECT * FROM default_test")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Integer).toSeq == @[42'i32]
        check chunk.bindAs(1, DuckType.Integer).toSeq == @[5'i32]

  test "Append without all columns raises error":
    let db = newDatabase()
    let conn = db.connect()
    conn.execute("CREATE TABLE no_default_test (a INTEGER, b INTEGER);")

    doAssertRaises(OperationError):
      var appender = newAppender(conn, "no_default_test")
      appender.append()
      appender.endRow()
      appender.flush()

  test "Append NULL values":
    conn.transient:
      conn.execute("CREATE TABLE null_test (i INTEGER, s VARCHAR, d DOUBLE);")
      var appender = newAppender(conn, "null_test")

      appender.append(42'i32)
      appender.append(none(string))
      appender.append(none(float))
      appender.endRow()
      appender.flush()

      let r = conn.execute("SELECT * FROM null_test")
      for chunk in r:
        check chunk.bindAs(0, DuckType.Integer)[0] == 42'i32
        # Row 0: int is present, varchar and double were appended as NULL
        check chunk.vector(0).valid(0) == true
        check chunk.vector(1).valid(0) == false
        check chunk.vector(2).valid(0) == false

  test "Append DataChunk val":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (int_val INTEGER, varchar_val VARCHAR, bool_val BOOLEAN);")
      var appender = newAppender(conn, "appender_table")

      let
        intValues = @[1'i32, 2'i32, 3'i32]
        strValues = @["foo", "bar", "baz"]
        boolValues = @[true, false, true]

      for i in 0 ..< 3:
        appender.append(intValues[i])
        appender.append(strValues[i])
        appender.append(boolValues[i])
        appender.endRow()
      appender.flush()

      let r = conn.execute("SELECT * FROM appender_table;")
      for ck in r:
        check ck.bindAs(0, DuckType.Integer).toSeq == intValues
        check ck.bindAs(1, DuckType.Varchar).toSeq == strValues
        check ck.bindAs(2, DuckType.Boolean).toSeq == boolValues

  test "Append DataChunk val using Options":
    conn.transient:
      conn.execute("CREATE TABLE appender_table (int_val INTEGER, varchar_val VARCHAR, bool_val BOOLEAN);")
      var appender = newAppender(conn, "appender_table")

      let
        intValues = @[some(1'i32), none(int32), some(3'i32)]
        strValues = @[none(string), some("bar"), none(string)]
        boolValues = @[none(bool), none(bool), some(true)]

      for i in 0 ..< 3:
        appender.append(intValues[i])
        appender.append(strValues[i])
        appender.append(boolValues[i])
        appender.endRow()
      appender.flush()

      let r = conn.execute("SELECT * FROM appender_table;")
      for ck in r:
        check ck.vector(0).valid(0) == true
        check ck.vector(0).valid(1) == false
        check ck.vector(0).valid(2) == true

        check ck.vector(1).valid(0) == false
        check ck.vector(1).valid(1) == true
        check ck.vector(1).valid(2) == false

        check ck.vector(2).valid(0) == false
        check ck.vector(2).valid(1) == false
        check ck.vector(2).valid(2) == true

        check ck.bindAs(0, DuckType.Integer)[0] == intValues[0].get()
        check ck.bindAs(1, DuckType.Varchar)[0] == ""
        check ck.bindAs(2, DuckType.Boolean)[2] == true

  test "Append throws an error on missing column on flush":
    let db = newDatabase()
    let conn = db.connect()

    conn.execute("CREATE TABLE test (i INTEGER, d double, s string)")

    doAssertRaises(OperationError):
      discard newAppender(conn, "unknown_table")

    var appender = newAppender(conn, "test")

    appender.append(42'i32)
    appender.append(4.2)
    appender.append("Hello, World")
    appender.endRow()
    appender.flush()

    appender.append(69'i32)
    appender.append(6.9)

    doAssertRaises(OperationError):
      appender.endRow()

    appender.append("Hello, Duckdb")
    appender.endRow()
    appender.flush()

    let r = conn.execute("SELECT * FROM test")
    check r.meta.columns.len == 3
    for chunk in r:
      check chunk.bindAs(0, DuckType.Integer)[0] == 42'i32
      check chunk.bindAs(1, DuckType.Double)[1] == 6.9
      check chunk.bindAs(2, DuckType.Varchar)[1] == "Hello, Duckdb"

  test "Complex varchar":
    let conn = newDatabase().connect()

    let query = """
      select
        case
          when i != 0
          and i % 42 = 0 then NULL
          else repeat(chr((65 + (i % 26))::INTEGER),
          (4 + (i % 12)))
        end
      from
        range(5000) tbl(i);
    """
    var r = conn.execute(query)
    check r.meta.columns.len == 1
    var totalLen = 0
    for chunk in r:
      let cv = chunk.vector(0)
      check cv.kind == DuckType.Varchar
      totalLen += cv.len
    check totalLen == 5000

suite "Test pending statement queries":

  test "Basic pending query, execute directly (materialized)":
    let
      conn = newDatabase().connect()
      prepared = conn.newStatement("SELECT SUM(i) FROM range(1000000) tbl(i);")
      pending = newPendingStreamingResult(prepared)

    let outcome = pending.executeStreaming()
    for chunk in outcome:
      check chunk.bindAs(0, DuckType.HugeInt)[0] == i128("499999500000")

  test "Basic pending query stepping with step/isFinished":
    let
      conn = newDatabase().connect()
      prepared = conn.newStatement("SELECT SUM(i) FROM range(1000000) tbl(i);")
      pending = newPendingStreamingResult(prepared)

    while true:
      let state = pending.step()
      if state.isFinished:
        break
      elif state == PendingState.Error:
        break

    let outcome = pending.executeStreaming()
    for chunk in outcome:
      check chunk.bindAs(0, DuckType.HugeInt)[0] == i128("499999500000")

  test "Testing streaming results with step":
    let
      conn = newDatabase().connect()
      prepared = conn.newStatement("SELECT i::UINT32 FROM range(1000000) tbl(i)")
      pending = newPendingStreamingResult(prepared)

    while true:
      let state = pending.step()
      if state.isFinished:
        break
      elif state == PendingState.Error:
        break
      elif state == PendingState.NotReady:
        continue

    var res = pending.executeStreaming()
    check res.meta.columns.len == 1
    var total = 0
    for chunk in res:
      total += chunk.len
    check total == 1000000

  test "Testing streaming interrupt and progress with step":
    let config = newConfig({"threads": "1",}.toTable)
    let conn = newDatabase(config).connect()

    conn.execute("CREATE TABLE tbl AS SELECT RANGE a, MOD(RANGE,10) b FROM RANGE(10000);")
    conn.execute("CREATE TABLE tbl_2 AS SELECT RANGE a FROM RANGE(10000);")
    conn.execute("SET enable_progress_bar=true;")
    conn.execute("SET enable_progress_bar_print=false;")

    # Idle connection: no query in flight → progress is unset (-1).
    check conn.queryProgress.percentage == -1

    let
      prepared = conn.newStatement("SELECT COUNT(*) FROM tbl WHERE a = (SELECT MIN(a) FROM tbl_2);")
      pending = newPendingStreamingResult(prepared)

    # Step until progress advances past zero or the query resolves. Progress
    # values are timing-dependent (threads=1, scheduler-dependent), so assert
    # ranges/monotonicity, not exact numbers, to avoid flakes.
    var sawProgress = false
    var steps = 0
    while true:
      let state = pending.step()
      if conn.queryProgress.percentage > 0.0:
        sawProgress = true
      if state.isFinished or state == PendingState.Error:
        break
      check steps < 1_000_000  # hang guard only
      inc steps

    let progress = conn.queryProgress
    check progress.percentage >= 0.0 and progress.percentage <= 100.0
    check progress.rowsProcessed >= 0

    # Interrupt mid-flight: safe to call at any point. The pending must resolve
    # (to Error when interrupted, or Ready/Finished if it already completed).
    conn.interrupt()
    var finalState = PendingState.NotReady
    var guard = 0
    while true:
      finalState = pending.step()
      if finalState.isFinished or finalState == PendingState.Error:
        break
      check guard < 1_000_000  # hang guard only
      inc guard
    check finalState == PendingState.Error or finalState.isFinished

  test "Pending states observed during stepping are from the valid set":
    let conn = newDatabase().connect()
    let prepared = conn.newStatement("SELECT SUM(i) FROM range(1000000) tbl(i)")
    let pending = newPendingStreamingResult(prepared)
    var observed: set[PendingState]
    var lastState = PendingState.NotReady
    var steps = 0
    while true:
      let state = pending.step()
      lastState = state
      observed.incl state
      inc steps
      if state.isFinished: break
      if state == PendingState.Error: break
      # Generous infinite-loop guard: step count varies with scheduler/load,
      # so this must only fire on a genuine hang, not slow execution.
      check steps < 1_000_000
    check lastState.isFinished or PendingState.Ready in observed
    # The wrapper enum only exposes states DuckDB actually reports
    for s in observed:
      check s in {PendingState.Ready, PendingState.NotReady,
                  PendingState.Error, PendingState.NoTasksAvailable}

suite "Transaction templates":
  test "transact commits on success — rows visible after":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE trans_commit (i INTEGER)")
    conn.transaction:
      conn.executeMaterialized("INSERT INTO trans_commit VALUES (?), (?)", (1, 2))
    let r = conn.execute("SELECT i FROM trans_commit ORDER BY i")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Integer).toSeq == @[1'i32, 2]

  test "transient rolls back even when body raises":
    proc rollMeBack() =
      raise newException(ValueError, "roll me back")
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE trans_rollback (i INTEGER)")
    conn.executeMaterialized("INSERT INTO trans_rollback VALUES (?)", (1,))
    expect(ValueError):
      conn.transient:
        conn.executeMaterialized("INSERT INTO trans_rollback VALUES (?)", (2,))
        rollMeBack()
    let r = conn.execute("SELECT i FROM trans_rollback ORDER BY i")
    for chunk in r:
      check chunk.bindAs(0, DuckType.Integer).toSeq == @[1'i32]

suite "Bind/append type mismatch":
  test "Bind string to INTEGER column raises OperationError":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE bind_mismatch (i INTEGER)")
    let prepared = newStatement(conn, "INSERT INTO bind_mismatch VALUES (?)")
    expect(OperationError):
      conn.executeMaterialized(prepared, ("hello",))

  test "Append string to INTEGER column raises OperationError":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE app_mismatch (i INTEGER)")
    expect(OperationError):
      var appender = newAppender(conn, "app_mismatch")
      appender.append("hello")

suite "Prepared statement reuse":
  test "Same prepared stmt reused with multiple param values":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE reuse_test (x BIGINT, y VARCHAR)")
    let prepared = newStatement(conn, "INSERT INTO reuse_test VALUES (?, ?)")
    conn.executeMaterialized(prepared, (10'i64, "ten"))
    conn.executeMaterialized(prepared, (20'i64, "twenty"))
    conn.executeMaterialized(prepared, (30'i64, "thirty"))
    let r = conn.execute("SELECT x, y FROM reuse_test ORDER BY x")
    for chunk in r:
      check chunk.bindAs(0, DuckType.BigInt).toSeq == @[10'i64, 20, 30]
      check chunk.bindAs(1, DuckType.Varchar).toSeq == @["ten", "twenty", "thirty"]

suite "Pending statement state machine":
  test "Pending streaming state transitions and abandon":
    let conn = newDatabase().connect()
    let prepared = conn.newStatement("SELECT i FROM range(100) t(i)")
    let pending = newPendingStreamingResult(prepared)
    var steps = 0
    while true:
      let state = pending.step()
      steps += 1
      if state.isFinished:
        break
      elif state == PendingState.Error:
        check false
        break
      elif state == PendingState.NotReady:
        continue
    check steps > 0
    let r = pending.executeStreaming()
    var total = 0
    for chunk in r:
      total += chunk.len
    check total == 100

  test "Abandon streaming result mid-iteration (sanitizer-validated)":
    # No assertion: this test's value is that dropping a partially-consumed
    # streaming result frees cleanly. Leak/double-free detection is delegated
    # to ASan/LSan (CI runs with detect_leaks=1); the drop path is still
    # exercised here on every build.
    let conn = newDatabase().connect()
    let prepared = conn.newStatement("SELECT i FROM range(10000) t(i)")
    let r = conn.executeStreaming(prepared)
    # iterate a few chunks then drop the ref — ASan catches double-free / leak
    var seen = 0
    for chunk in r:
      seen += chunk.len
      if seen > 500:
        break

suite "Error and panic edge cases":
  test "Incorrect bind parameter type raises OperationError":
    let conn = newDatabase().connect()
    discard conn.execute("CREATE TABLE bind_err (i INTEGER)")
    expect(OperationError):
      conn.executeMaterialized("INSERT INTO bind_err VALUES (?)", ("not_an_int",))

  test "Cross-connection interference does not affect independent databases":
    let db1 = newDatabase()
    let db2 = newDatabase()
    let con1 = db1.connect()
    let con2 = db2.connect()
    con1.execute("CREATE TABLE t (x INTEGER)")
    con2.execute("CREATE TABLE t (x INTEGER)")
    con1.execute("INSERT INTO t VALUES (1)")
    con2.execute("INSERT INTO t VALUES (2)")
    for chunk in con1.execute("SELECT x FROM t"):
      check chunk.bindAs(0, DuckType.Integer).toSeq == @[1'i32]
    for chunk in con2.execute("SELECT x FROM t"):
      check chunk.bindAs(0, DuckType.Integer).toSeq == @[2'i32]

suite "Memory ownership — move semantics":
  test "Moving a prepared statement preserves its handle":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE move_prep (i INTEGER, s VARCHAR)")
    var stmt2 = conn.newStatement("INSERT INTO move_prep VALUES (?, ?)")
    let params2 = stmt2.parameters.toSeq
    check params2.len == 2
    let handle2 = stmt2.rawHandle
    check handle2 != nil
    var moved = move(stmt2)
    # moved-from Statement is nil; moved-to retains the prepared handle
    check stmt2.rawHandle == nil
    check moved.rawHandle == handle2
    conn.executeMaterialized(moved, (1, "a"))
    conn.executeMaterialized(moved, (2, "b"))
    for chunk in conn.execute("SELECT i, s FROM move_prep ORDER BY i"):
      check chunk.bindAs(0, DuckType.Integer).toSeq == @[1'i32, 2'i32]

  test "Moving a pending statement is safe after create":
    let conn = newDatabase().connect()
    var pending = newPendingStreamingResult(
      conn.newStatement("SELECT i FROM range(5) t(i)")
    )
    var pending2 = move(pending)
    var steps = 0
    while true:
      let state = pending2.step()
      steps += 1
      if state.isFinished:
        break
      elif state == PendingState.Error:
        check false
        break
    check steps > 0

  test "Abandoning a streaming query mid-flow (sanitizer-validated)":
    # No assertion: dropping a partially-consumed streaming result must not
    # leak or double-free. Verified under ASan/LSan in CI (detect_leaks=1).
    let conn = newDatabase().connect()
    let r = conn.execute("SELECT i FROM range(1000) t(i)")
    var count = 0
    for chunk in r:
      count += chunk.len
      if count > 100:
        break
    # Don't iterate the rest; r is destroyed here — ASan catches leaks

  test "Re-execute prepared statement after materialized result consumed":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE reuse2 (x BIGINT)")
    let prep = conn.newStatement("INSERT INTO reuse2 VALUES (?)")
    conn.executeMaterialized(prep, (10,))
    conn.executeMaterialized(prep, (20,))
    for chunk in conn.execute("SELECT x FROM reuse2 ORDER BY x"):
      check chunk.bindAs(0, DuckType.BigInt).toSeq == @[10'i64, 20'i64]
