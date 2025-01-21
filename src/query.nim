import std/[strformat, logging, enumerate]
import /[api, types, database, query_result, exceptions]

type
  Query* = distinct string
  Statement = distinct ptr duckdbPreparedStatement
  Values = (tuple or object)
  Appender = distinct ptr duckdbAppender

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
  check(
    duckdbPrepare(con.handle, query, result.addr), "Failed to create prepared statement"
  )

proc bind_param_idx*(statement: Statement, name: string, param_idx_out: ptr idx_t) =
  check(
    duckdb_bind_parameter_index(statement, param_idx_out, name.cstring),
    "Failed to bind parameter index",
  )

# template bind_val*(statement: Statement, i: idx_t, val: DuckDBHugeint): Error =
#   duckdb_bind_hugeint(statement, i, val)

# template bind_val*(statement: Statement, i: idx_t, val: DuckDBUHugeint): Error =
#   duckdb_bind_uhugeint(statement, i, val)

# template bind_val*(statement: Statement, i: idx_t, val: DuckDBDecimal): Error =
#   duckdb_bind_decimal(statement, i, val)

# template bind_val*(statement: Statement, i: idx_t, val: DuckDBDate): Error =
#   duckdb_bind_date(statement, i, val)

# template bind_val*(statement: Statement, i: idx_t, val: DuckDBTime): Error =
#   duckdb_bind_time(statement, i, val)

# template bind_val*(statement: Statement, i: idx_t, val: DuckDBTimestamp): Error =
#   duckdb_bind_timestamp(statement, i, val)

# template bind_val*(statement: Statement, i: idx_t, val: DuckDBTimestampTz): Error =
#   duckdb_bind_timestamp_tz(statement, i, val)

# template bind_val*(statement: Statement, i: idx_t, val: DuckDBInterval): Error =
#   duckdb_bind_interval(statement, i, val)

# template bind_val*(statement: Statement, i: idx_t, val: FilePath): Error =
#   duckdb_bind_varchar_length(statement, i, val.cstring, len(val))

# template bind_val*(statement: Statement, i: idx_t, val: FilePath, length: idx_t): Error =
#   duckdb_bind_varchar_length(statement, i, val.cstring, length)

template bind_val*(statement: Statement, i: idx_t, val: seq[byte]): Error =
  duckdb_bind_blob(statement, i, ptr val, len(val))

template bind_val*(statement: Statement, i: idx_t, val: void): Error =
  duckdb_bind_null(statement, i)

template bind_val(statement: Statement, i: idx_t, val: bool): Error =
  duckdb_bind_boolean(statement, i, val)

template bind_val(statement: Statement, i: idx_t, val: int8): Error =
  duckdb_bind_int8(statement, i, val)

template bind_val(statement: Statement, i: idx_t, val: int16): Error =
  duckdb_bind_int16(statement, i, val)

template bind_val(statement: Statement, i: idx_t, val: int32): Error =
  duckdb_bind_int32(statement, i, val)

template bind_val(statement: Statement, i: idx_t, val: int64): Error =
  duckdb_bind_int64(statement, i, val)

template bind_val(statement: Statement, i: idx_t, val: int): Error =
  duckdb_bind_int64(statement, i, int64(val))

template bind_val(statement: Statement, i: idx_t, val: uint8): Error =
  duckdb_bind_uint8(statement, i, val)

template bind_val(statement: Statement, i: idx_t, val: uint16): Error =
  duckdb_bind_uint16(statement, i, val)

template bind_val(statement: Statement, i: idx_t, val: uint32): Error =
  duckdb_bind_uint32(statement, i, val)

template bind_val(statement: Statement, i: idx_t, val: uint64): Error =
  duckdb_bind_uint64(statement, i, val)

template bind_val(statement: Statement, i: idx_t, val: float32): Error =
  duckdb_bind_float(statement, i, val)

template bind_val(statement: Statement, i: idx_t, val: float64): Error =
  duckdb_bind_double(statement, i, val)

template bind_val(statement: Statement, i: idx_t, val: string): Error =
  duckdb_bind_varchar(statement, i, val.cstring)

template bind_val(statement: Statement, i: idx_t, val: Value): Error =
  duckdb_bind_value(statement, i, val.toNativeValue.handle)

# duckdb_state duckdb_bind_value(duckdb_prepared_statement prepared_statement, idx_t param_idx, duckdb_value val);
proc execute*[T: Values](
    con: Connection, statement: Statement, args: T
): QueryResult {.discardable.} =
  ## Executes a prepared statement with provided arguments
  result = QueryResult()
  for i, value in enumerate(args.fields):
    check(
      bind_val(statement, (i + 1).idx_t, value),
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

template append*(appender: Appender, val: bool): Error =
  duckdb_append_bool(appender, val)

template append*(appender: Appender, val: int8): Error =
  duckdb_append_int8(appender, val)

template append*(appender: Appender, val: int16): Error =
  duckdb_append_int16(appender, val)

template append*(appender: Appender, val: int32): Error =
  duckdb_append_int32(appender, val)

template append*(appender: Appender, val: int64): Error =
  duckdb_append_int64(appender, val)

template append*(appender: Appender, val: int): Error =
  duckdb_append_int64(appender, int64(val))

template append*(appender: Appender, val: uint8): Error =
  duckdb_append_uint8(appender, val)

template append*(appender: Appender, val: uint16): Error =
  duckdb_append_uint16(appender, val)

template append*(appender: Appender, val: uint32): Error =
  duckdb_append_uint32(appender, val)

template append*(appender: Appender, val: uint64): Error =
  duckdb_append_uint64(appender, val)

template append*(appender: Appender, val: float32): Error =
  duckdb_append_float(appender, val)

template append*(appender: Appender, val: float64): Error =
  duckdb_append_double(appender, val)

template append*(appender: Appender, val: string): Error =
  # TODO: not sure about this
  if val == "":
    duckdb_append_null(appender)
  else:
    duckdb_append_varchar(appender, val.cstring)

template append*(appender: Appender, val: void): Error =
  duckdb_append_null(appender)

template append*[T](appender: Appender, val: seq[T]) =
  duckdb_append_blob(appender, ptr val, len(val))

template append*(appender: Appender, val: auto): Error =
  raise newException(ValueError, "I have no ideea how to convert val, got: ", $val)

proc newAppender*(con: Connection, table: string): Appender =
  ## Creates a new appender for a specified table
  result = Appender(nil)
  check(
    duckdb_appender_create(con.handle, nil, table.cstring, result.addr),
    "Failed to create appender",
  )

proc appender*[T](con: Connection, table: string, ent: seq[seq[T]]) =
  ## Appends a sequence of sequences of type `T` to a specified table in a DuckDB database.
  var appender = newAppender(con, table)
  for row in ent:
    for val in row:
      check(appender.append(val), fmt"Failed to append: {val}")
    check(duckdb_appender_end_row(appender), "Failed to end row on appender")
  check(duckdb_appender_close(appender), "Failed to close the appender")
