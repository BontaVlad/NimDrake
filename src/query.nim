import std/[strformat, logging, enumerate, times]
import nint128
import decimal
import /[api, types, database, query_result, value, exceptions]

type
  Query* = distinct string
  Statement* = distinct ptr duckdbPreparedStatement
  Values = (tuple or object)
  Appender* = distinct ptr duckdbAppender
  AppenderColumn* = object
    idx*: int
    tpy*: LogicalType
  Parameter* = object ## Prepared Statement parameters
    name*: string
    idx*: int
    tpy*: DuckType

converter toBase*(s: ptr Statement): ptr duckdbPreparedStatement =
  cast[ptr duckdbPreparedStatement](s)

converter toBase*(s: Statement): duckdbPreparedStatement =
  cast[duckdbPreparedStatement](s)

converter toBase*(a: ptr Appender): ptr duckdbappender =
  cast[ptr duckdbappender](a)

converter toBase*(a: Appender): duckdbappender =
  cast[duckdbappender](a)

converter toBase*(q: Query): cstring =
  q.cstring

converter toBase*(s: string): Query =
  Query(s)

proc `=destroy`*(appender: Appender) =
  ## Destroys an appender instance if it exists
  if not isNil(appender.addr):
    discard duckdbAppenderDestroy(appender.addr)

proc `=destroy`*(statement: Statement) =
  ## Destroys a prepared statement instance if it exists
  if not isNil(statement.addr):
    duckdbDestroyPrepare(statement.addr)

proc newStatement*(con: Connection, query: Query): Statement =
  ## Creates a new prepared statement from a connection and query
  result = Statement(nil)
  let error = duckdbPrepare(con.handle, query, result.addr)
  if error:
    let errorMessage = duckdb_prepare_error(result)
    raise newException(OperationError, $errorMessage)

iterator parameters*(statement: Statement): Parameter =
  ## There are three syntaxes for denoting parameters in prepared statements:
  ## auto-incremented (?), positional ($1), and named ($param).
  ## Note that not all clients support all of these syntaxes, e.g.,
  ## the JDBC client only supports auto-incremented parameters in prepared statements.
  runnableExamples:
    import std/sequtils
    import nimdrake

    let conn = newDatabase().connect()

    conn.execute("CREATE TABLE a (i INTEGER, j VARCHAR);")
    var statement = conn.newStatement("INSERT INTO a VALUES (?, ?);")
    let parameters = statement.parameters.toSeq()
    assert len(parameters) == 2
    assert parameters[0].name == "1"
    assert parameters[0].idx == 1
    assert parameters[0].tpy == DuckType.Integer
    assert parameters[1].name == "2"
    assert parameters[1].idx == 2
    assert parameters[1].tpy == DuckType.VARCHAR

  let nParams = duckdb_nparams(statement)
  for idx in 1 .. nParams:
    yield Parameter(
      name: $newDuckString(duckdb_parameter_name(statement, idx)),
      idx: idx.int,
      tpy: newDuckType(duckdb_param_type(statement, idx))
    )

proc bindParameter*(statement: Statement, name: string): int =
  ## Retrieve the index of the parameter for the prepared statement, identified by name

  runnableExamples:
    import nimdrake

    let conn = newDatabase().connect()

    var statement = conn.newStatement("SELECT CAST($my_val AS BIGINT), CAST($my_second_val AS VARCHAR);")
    let indexes = @[
      statement.bindParameter("my_second_val"),
      statement.bindParameter("my_val")
    ]
    assert indexes == @[2, 1]

  var parameterIndex = 0.idx_t
  check(
    duckdbBindParameterIndex(statement, parameterIndex.addr, name.cstring),
    fmt"Failed to bind parameter {name}",
  )
  return parameterIndex.int

template bindVal*(statement: Statement, i: int, val: bool): Error =
  ## Binds a bool value to the prepared statement at the specified index.
  duckdbBindBoolean(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: seq[byte]): Error =
  ## Binds a blob value to the prepared statement at the specified index.
  duckdbBindBlob(statement, i.idx_t, ptr val, len(val))

template bindVal*(statement: Statement, i: int, val: void): Error =
  ## Binds a NULL value to the prepared statement at the specified index
  duckdb_bind_null(statement, i.idx_t)

template bindVal*(statement: Statement, i: int, val: int8): Error =
  ## Binds an int8_t value to the prepared statement at the specified index.
  duckdb_bind_int8(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: int16): Error =
  ## Binds an int16_t value to the prepared statement at the specified index.
  duckdb_bind_int16(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: int32): Error =
  ## Binds an int32_t value to the prepared statement at the specified index.
  duckdb_bind_int32(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: int64): Error =
  ## Binds an int64_t value to the prepared statement at the specified index.
  duckdb_bind_int64(statement, i.idx_t, val)

# TODO: this might be false
template bindVal*(statement: Statement, i: int, val: int): Error =
  ## Binds an int64_t value to the prepared statement at the specified index.
  duckdb_bind_int64(statement, i.idx_t, int64(val))

template bindVal*(statement: Statement, i: int, val: uint8): Error =
  ## Binds an uint8_t value to the prepared statement at the specified index.
  duckdb_bind_uint8(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: uint16): Error =
  ## Binds an uint16_t value to the prepared statement at the specified index.
  duckdb_bind_uint16(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: uint32): Error =
  ## Binds an uint32_t value to the prepared statement at the specified index.
  duckdb_bind_uint32(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: uint64): Error =
  ## Binds an uint64_t value to the prepared statement at the specified index.
  duckdb_bind_uint64(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: float32): Error =
  ## Binds a float value to the prepared statement at the specified index.
  duckdb_bind_float(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: float64): Error =
  ## Binds a double value to the prepared statement at the specified index.
  duckdb_bind_double(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: string): Error =
  ## Binds a varchar value to the prepared statement at the specified index.
  duckdb_bind_varchar(statement, i.idx_t, val.cstring)

template bindVal*(statement: Statement, i: int, val: Value): Error =
  ## Binds a value to the prepared statement at the specified index.
  duckdb_bind_value(statement, i.idx_t, val.toNativeValue.handle)

template bindVal*(statement: Statement, i: int, val: Int128): Error =
  ## Binds a HugeInt value to the prepared statement at the specified index.
  duckdb_bind_hugeint(statement, i.idx_t, val.toHugeInt)

template bindVal*(statement: Statement, i: int, val: UInt128): Error =
  ## Binds a unsigned HugeInt value to the prepared statement at the specified index.
  duckdb_bind_uhugeint(statement, i.idx_t, val.toUhugeInt)

template bindVal*(statement: Statement, i: int, val: Timestamp): Error =
  ## Binds a Timestamp value to the prepared statement at the specified index.
  duckdb_bind_timestamp(statement, i.idx_t, val.toTimestamp)

template bindVal*(statement: Statement, i: int, val: DateTime): Error =
  ## Binds a Datetime value to the prepared statement at the specified index.
  duckdb_bind_date(statement, i.idx_t, val.toDateTime)

template bindVal*(statement: Statement, i: int, val: Time): Error =
  ## Binds a Time value to the prepared statement at the specified index.
  duckdb_bind_time(statement, i.idx_t, val.toTime)

template bindVal*(statement: Statement, i: int, val: TimeInterval): Error =
  ## Binds a TimeInterval value to the prepared statement at the specified index.
  duckdb_bind_interval(statement, i.idx_t, val.toInterval)

# template bind_val*(statement: Statement, i: idx_t, val: ZonedTime): Error =
#   raise newException(ValueError, "BindVal for ZonedTime not implemented")
#   # duckdb_bind_timestamp_tz(statement, i, val)

# template bindVal*(statement: Statement, i: idx_t, val: Decimal): Error =
#   raise newException(ValueError, "BindVal for Decimal not implemented")
  # duckdb_bind_decimal(statement, i, val)
template append*(appender: Appender, val: bool): untyped =
  ## Appends a bool value to the appender.
  check(duckdb_append_bool(appender, val), "Failed to append bool value: " & $val)

template append*(appender: Appender, val: seq[byte]): untyped =
  ## Appends a blob value to the appender.
  check(duckdb_append_blob(appender, ptr val, len(val)), "Failed to append blob value of length: " & $len(val))

template append*(appender: Appender, val: untyped): void =
  ## Appends a NULL value to the appender.
  check(duckdb_append_null(appender), "Failed to append NULL value")

template append*(appender: Appender, val: int8): untyped =
  ## Appends an int8_t value to the appender.
  check(duckdb_append_int8(appender, val), "Failed to append int8 value: " & $val)

template append*(appender: Appender, val: int16): untyped =
  ## Appends an int16_t value to the appender.
  check(duckdb_append_int16(appender, val), "Failed to append int16 value: " & $val)

template append*(appender: Appender, val: int32): untyped =
  ## Appends an int32_t value to the appender.
  check(duckdb_append_int32(appender, val), "Failed to append int32 value: " & $val)

template append*(appender: Appender, val: int64): untyped =
  ## Appends an int64_t value to the appender.
  check(duckdb_append_int64(appender, val), "Failed to append int64 value: " & $val)

template append*(appender: Appender, val: int): untyped =
  ## Appends an int value to the appender (converted to int64).
  check(duckdb_append_int64(appender, int64(val)), "Failed to append int value: " & $val)

template append*(appender: Appender, val: uint8): untyped =
  ## Appends an uint8_t value to the appender.
  check(duckdb_append_uint8(appender, val), "Failed to append uint8 value: " & $val)

template append*(appender: Appender, val: uint16): untyped =
  ## Appends an uint16_t value to the appender.
  check(duckdb_append_uint16(appender, val), "Failed to append uint16 value: " & $val)

template append*(appender: Appender, val: uint32): untyped =
  ## Appends an uint32_t value to the appender.
  check(duckdb_append_uint32(appender, val), "Failed to append uint32 value: " & $val)

template append*(appender: Appender, val: uint64): untyped =
  ## Appends an uint64_t value to the appender.
  check(duckdb_append_uint64(appender, val), "Failed to append uint64 value: " & $val)

template append*(appender: Appender, val: float32): untyped =
  ## Appends a float value to the appender.
  check(duckdb_append_float(appender, val), "Failed to append float32 value: " & $val)

template append*(appender: Appender, val: float64): untyped =
  ## Appends a double value to the appender.
  check(duckdb_append_double(appender, val), "Failed to append float64 value: " & $val)

template append*(appender: Appender, val: string): untyped =
  ## Appends a varchar value to the appender.
  ## Empty strings are treated as NULL values.
  if val == "":
    check(duckdb_append_null(appender), "Failed to append NULL for empty string")
  else:
    check(duckdb_append_varchar(appender, val.cstring), "Failed to append string value: " & val)

template append*(appender: Appender, val: Value): untyped =
  ## Appends a Value to the appender.
  check(duckdb_append_value(appender, val.toNativeValue.handle), "Failed to append Value")

template append*(appender: Appender, val: Int128): untyped =
  ## Appends a HugeInt value to the appender.
  check(duckdb_append_hugeint(appender, val.toHugeInt), "Failed to append Int128 value: " & $val)

template append*(appender: Appender, val: UInt128): untyped =
  ## Appends an unsigned HugeInt value to the appender.
  check(duckdb_append_uhugeint(appender, val.toUhugeInt), "Failed to append UInt128 value: " & $val)

template append*(appender: Appender, val: Timestamp): untyped =
  ## Appends a Timestamp value to the appender.
  check(duckdb_append_timestamp(appender, val.toTimestamp), "Failed to append Timestamp value: " & $val)

template append*(appender: Appender, val: DateTime): untyped =
  ## Appends a DateTime value to the appender.
  check(duckdb_append_date(appender, val.toDateTime), "Failed to append DateTime value: " & $val)

template append*(appender: Appender, val: Time): untyped =
  ## Appends a Time value to the appender.
  check(duckdb_append_time(appender, val.toTime), "Failed to append Time value: " & $val)

template append*(appender: Appender, val: TimeInterval): untyped =
  ## Appends a TimeInterval value to the appender.
  check(duckdb_append_interval(appender, val.toInterval), "Failed to append TimeInterval value: " & $val)

template append*(appender: Appender, val: DataChunk): untyped =
  ## Appends a DataChunk value to the appender.
  runnableExamples:
    import nimdrake

    let db = newDatabase()
    let conn = db.connect()

    conn.execute("CREATE TABLE appender_table (int_val INTEGER, varchar_val VARCHAR, bool_val BOOLEAN);")
    var appender = newAppender(conn, "appender_table")

    let columns =
      @[
        newColumn(idx = 0, name = "index", kind = DuckType.Integer),
        newColumn(idx = 1, name = "name", kind = DuckType.Varchar),
        newColumn(idx = 2, name = "truth", kind = DuckType.Boolean),
      ]
    var chunk = newDataChunk(columns = columns)
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
    assert outcome[0].valueInteger == intValues
    assert outcome[1].valueVarchar == strValues
    assert outcome[2].valueBoolean == boolValues

  check(duckdb_append_datachunk(appender, val.handle), "Failed to append DataChunk value: " & $val)

proc execute*[T: Values](
    con: Connection, statement: Statement, args: T
): QueryResult {.discardable.} =
  ## Executes a prepared statement with provided arguments
  result = QueryResult()
  for i, value in enumerate(args.fields):
    check(bindVal(statement, (i + 1), value),
      "Failed to bind" & " " & $value & "[" & $typedesc(value) & "]",
    )
  check(duckdbExecutePrepared(statement, result.addr), result.error)

proc execute*(con: Connection, query: Query): QueryResult {.discardable.} =
  ## Executes a raw query without any prepared arguments
  result = QueryResult()
  check(duckdbQuery(con.handle, query, result.addr), result.error)

proc execute*[T: Values](
    con: Connection, query: Query, args: T
): QueryResult {.discardable.} =
  ## Executes a query with arguments by first preparing a statement
  let statement = newStatement(con, query)
  result = con.execute(statement, args)

proc flush*(appender: Appender) {.discardable.} =
  let error = duckdb_appender_flush(appender)
  if error:
    let errorMessage = $duckdb_appender_error(appender)
    raise newException(OperationError, fmt"Failed to flush the appender {errorMessage}")

proc close*(appender: Appender) {.discardable.} =
  let error = duckdb_appender_close(appender)
  if error:
    let errorMessage = $duckdb_appender_error(appender)
    raise newException(OperationError, fmt"Failed to close the appender {errorMessage}")

proc endRow*(appender: Appender) {.discardable.} =
  let error = duckdb_appender_end_row(appender)
  if error:
    let errorMessage = $duckdb_appender_error(appender)
    raise newException(OperationError, fmt"Failed to end row for appender {errorMessage}")

iterator columns*(appender: Appender): AppenderColumn =
  ## Returns the columns in the table that belongs to the appender.
  let nColumns = duckdb_appender_column_count(appender)
  for idx in 0 ..< nColumns:
    yield AppenderColumn(
      idx: idx.int,
      tpy: newLogicalType(duckdb_appender_column_type(appender, idx))
    )

proc newAppender*(con: Connection, table: string): Appender =
  ## Creates a new appender for a specified table
  result = Appender(nil)
  check(
    duckdb_appender_create(con.handle, nil, table.cstring, result.addr),
    fmt"Failed to create appender for table: {table}",
  )

proc newAppender*[T](con: Connection, table: string, ent: seq[seq[T]]) =
  ## Appends a sequence of sequences of type `T` to a specified table in a DuckDB database.
  var appender = newAppender(con, table)
  for row in ent:
    for val in row:
      appender.append(val)
    appender.endRow()
  appender.flush()

