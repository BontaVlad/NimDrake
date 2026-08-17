## Prepared statements, typed parameter binding, and the bulk-insert
## appender API.
##
## Everything here executes against a `Connection` from the `database` module.
## Pick an execution strategy per query:
##
## - `execute` — raw SQL, materialized result.
## - `executeStreaming` — row-at-a-time result from a prepared statement;
##   required for large result sets.
## - `executeMaterialized` — prepared statement execution with all rows in
##   memory; use for DML (`INSERT`/`UPDATE`/`DELETE`) which never stream.
## - `newPendingResult` / `newPendingStreamingResult` + `step` — pause and
##   resume query work; lets a UI thread stay responsive.
##
## Parameters are bound positionally (``?``), by number (``$1``), or by name
## (``$name``). `bindVal` types the parameters at compile time; unknown
## parameters, the wrong count, or NULL handling use `Option[T]`,
## `bindNull`, or passable runtime values (`NimValue`, `JsonNode`,
## `DecimalType`, `Uuid`).
##
## For bulk inserts, `newAppender` hands out an `Appender` that buffers rows
## on an existing table. Rows are committed with `flush` / `close` — the
## `=destroy` hook does **not** flush. `appendRows` wraps the whole lifecycle
## for a `seq` of rows.
##
## .. note:: A `Statement`, `PendingQueryResult`, and `Appender` each own a
##   DuckDB handle and must never outlive their `Connection`. Copying an
##   `Appender` is a compile error.
import std/[strformat, enumerate, times, options, json]
import /[ffi, types, database, qresult, codec, complex, exceptions]

runnableExamples:
  import std/sequtils
  import nimdrake

  let conn = newDatabase().connect()

  # Prepared statements: inspect params, bind by name, then execute.
  conn.execute("CREATE TABLE people (name VARCHAR, age INTEGER);")
  var stmt = conn.newStatement("SELECT age FROM people WHERE name = $name;")
  doAssert stmt.parameters.toSeq.len == 1
  doAssert stmt.bindVal(stmt.bindParameter("name"), "drake") == DuckDBSuccess
  conn.executeMaterialized("INSERT INTO people VALUES (?, ?);", ("drake", 42))
  for chunk in conn.execute("SELECT * FROM people;"):
    for name in chunk.bindAs(0, DuckType.Varchar):
      doAssert name == "drake"
    for age in chunk.bindAs(1, DuckType.Integer):
      doAssert age == 42

  # Bulk insert via the appender: `some`/`none` map to value/SQL NULL.
  conn.execute("CREATE TABLE ages (age INTEGER);")
  conn.appendRows("ages", @[@[some(36)], @[some(104)], @[none(int)]])

proc takeCString(str: cstring): string {.inline.} =
  ## Takes ownership of a DuckDB-allocated cstring and returns a Nim string.
  result = $str
  duckdb_free(str)

type
  Query* = distinct string ## Untrusted SQL text; prepared via `newStatement`.
  Values = (tuple or object)
  Appender* = distinct ptr duckdbAppender ## Owns a DuckDB appender handle.
                                         ## Single-use: copy/dup is a compile
                                         ## error and `=destroy` does not flush.
  AppenderColumn* = object ## Column metadata reported by `columns` on an `Appender`.
    idx*: int
    tpy*: LogicalType

  Parameter* = object ## A prepared-statement placeholder, from `parameters`.
    name*: string
    idx*: int
    tpy*: DuckType

  PendingState* {.pure.} = enum ## Outcome of one `step` on a pending query.
    Ready          ## At least one task ran; more remain.
    NotReady       ## No task ran this step; try again later.
    Error          ## The pending query failed; see `error`.
    NoTasksAvailable ## The query finished; collect via `executeStreaming`.

converter toBase*(a: ptr Appender): ptr duckdbappender =
  ## Adapts an `Appender` to the underlying duckdb handle for FFI calls.
  cast[ptr duckdbappender](a)

converter toBase*(a: Appender): duckdbappender =
  ## Adapts an `Appender` to the underlying duckdb handle for FFI calls.
  cast[duckdbappender](a)

converter toBase*(q: Query): cstring =
  ## Exposes the raw SQL text of a `Query`; prefer the `exec*` procs.
  q.cstring

converter toBase*(s: string): Query =
  ## Lets any `string` be passed where a `Query` is expected.
  Query(s)

proc `=destroy`*(appender: Appender) =
  ## Frees the DuckDB appender handle. Does **not** flush buffered rows —
  ## call `flush` or `close` first, or appended rows are lost.
  if cast[ptr duckdbAppender](appender) != nil:
    discard duckdbAppenderDestroy(appender.addr)

## Appender is move-only: copying would double-free the DuckDB handle.
proc `=dup`*(appender: Appender): Appender {.error.}

## Appender is move-only: copying would double-free the DuckDB handle.
proc `=copy`*(dest: var Appender, source: Appender) {.error.}

proc `=wasMoved`*(appender: var Appender) =
  appender = Appender(nil)

# ---------------------------------------------------------------------------
# Error-handling helpers
# ---------------------------------------------------------------------------

template checkResult(operation: untyped, raw: var duckdb_result, what: string) =
  if operation:
    let msg = $duckdb_result_error(raw.addr)
    duckdb_destroy_result(raw.addr)
    raise newException(OperationError, what & ": " & msg)

template checkAppender(operation: untyped, app: Appender, what: string) =
  if operation:
    let msg = $duckdb_appender_error(app)
    raise newException(OperationError, what & ": " & msg)

# ---------------------------------------------------------------------------
# Prepared statements
# ---------------------------------------------------------------------------

proc newStatement*(con: Connection, query: Query): Statement =
  ## Prepares `query` against `con` and returns the reusable `Statement`.
  ## Raises `OperationError` if the SQL is invalid or uses an unsupported
  ## feature; nothing is executed until you call one of the `execute*` procs.
  result = Statement(nil)
  let error = duckdbPrepare(con.rawHandle, query, result.addr)
  if error:
    let errorMessage = duckdb_prepare_error(result)
    raise newException(OperationError, $errorMessage)

iterator parameters*(statement: Statement): Parameter =
  ## Yields the `Parameter`s of a prepared statement: one per placeholder,
  ## in 1-based `idx` order. `?` becomes the auto-incremented number,
  ## `$n` keeps its number, and `$name` keeps its name.
  ##
  ## .. note:: Not every client supports every syntax; e.g. the JDBC client
  ##   only supports `?`. Use the iterator to validate your statements once
  ##   up-front instead of guessing indexes.
  let nParams = duckdb_nparams(statement)
  for idx in 1 .. nParams:
    yield Parameter(
      name: takeCString(duckdb_parameter_name(statement, idx)),
      idx: idx.int,
      tpy: toDuckType(duckdb_param_type(statement, idx)),
    )

proc bindParameter*(statement: Statement, name: string): int =
  ## Returns the 1-based index of the named parameter `name` — the value
  ## `stmt.bindVal(stmt.bindParameter(name), val)` is a shortcut for binding
  ## by name. Raises if `name` is not a declared parameter.
  var parameterIndex = 0.idx_t
  check(
    duckdbBindParameterIndex(statement, parameterIndex.addr, name.cstring),
    fmt"Failed to bind parameter {name}",
  )
  return parameterIndex.int

# ---------------------------------------------------------------------------
# bindVal — typed parameter binding
# ---------------------------------------------------------------------------

template bindVal*(statement: Statement, i: int, val: bool): DuckState =
  ## Binds a bool value to the prepared statement at the specified index.
  duckdbBindBoolean(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: seq[byte]): DuckState =
  ## Binds a blob value to the prepared statement at the specified index.
  if val.len == 0:
    duckdbBindBlob(statement, i.idx_t, nil, 0)
  else:
    duckdbBindBlob(statement, i.idx_t, cast[pointer](addr val[0]),
      len(val).idx_t)

template bindNull*(statement: Statement, i: int): DuckState =
  ## Binds a NULL value to the prepared statement at the specified index.
  duckdb_bind_null(statement, i.idx_t)

template bindVal*(statement: Statement, i: int, val: int8): DuckState =
  ## Binds an int8_t value to the prepared statement at the specified index.
  duckdb_bind_int8(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: int16): DuckState =
  ## Binds an int16_t value to the prepared statement at the specified index.
  duckdb_bind_int16(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: int32): DuckState =
  ## Binds an int32_t value to the prepared statement at the specified index.
  duckdb_bind_int32(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: int64): DuckState =
  ## Binds an int64_t value to the prepared statement at the specified index.
  duckdb_bind_int64(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: int): DuckState =
  ## Binds an int value to the prepared statement at the specified index (converted to int64).
  duckdb_bind_int64(statement, i.idx_t, int64(val))

template bindVal*(statement: Statement, i: int, val: uint8): DuckState =
  ## Binds an uint8_t value to the prepared statement at the specified index.
  duckdb_bind_uint8(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: uint16): DuckState =
  ## Binds an uint16_t value to the prepared statement at the specified index.
  duckdb_bind_uint16(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: uint32): DuckState =
  ## Binds an uint32_t value to the prepared statement at the specified index.
  duckdb_bind_uint32(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: uint64): DuckState =
  ## Binds an uint64_t value to the prepared statement at the specified index.
  duckdb_bind_uint64(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: float32): DuckState =
  ## Binds a float value to the prepared statement at the specified index.
  duckdb_bind_float(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: float64): DuckState =
  ## Binds a double value to the prepared statement at the specified index.
  duckdb_bind_double(statement, i.idx_t, val)

template bindVal*(statement: Statement, i: int, val: string): DuckState =
  ## Binds a varchar value to the prepared statement at the specified index.
  ## Embedded NUL bytes are preserved via the length-taking API.
  duckdb_bind_varchar_length(statement, i.idx_t, val.cstring, val.len.idx_t)

template bindVal*(statement: Statement, i: int, val: Int128): DuckState =
  ## Binds a HugeInt value to the prepared statement at the specified index.
  duckdb_bind_hugeint(statement, i.idx_t, val.toHugeInt)

template bindVal*(statement: Statement, i: int, val: UInt128): DuckState =
  ## Binds an unsigned HugeInt value to the prepared statement at the specified index.
  duckdb_bind_uhugeint(statement, i.idx_t, val.toUHugeInt)

template bindVal*(statement: Statement, i: int, val: Timestamp): DuckState =
  ## Binds a Timestamp value to the prepared statement at the specified index.
  duckdb_bind_timestamp(statement, i.idx_t, val.toTimestamp)

template bindVal*(statement: Statement, i: int, val: DateTime): DuckState =
  ## Binds a Datetime value to the prepared statement at the specified index
  ## as a TIMESTAMP (time-of-day preserved).
  duckdb_bind_timestamp(statement, i.idx_t, Timestamp(val).toTimestamp)

template bindVal*(statement: Statement, i: int, val: Time): DuckState =
  ## Binds a Time value to the prepared statement at the specified index.
  duckdb_bind_time(statement, i.idx_t, val.toTime)

template bindVal*(statement: Statement, i: int, val: TimeInterval): DuckState =
  ## Binds a TimeInterval value to the prepared statement at the specified index.
  duckdb_bind_interval(statement, i.idx_t, val.toInterval)

template bindVal*(statement: Statement, i: int, val: NimValue): DuckState =
  ## Binds a NimValue to the prepared statement at the specified index.
  ## Complex kinds (List, Struct, Map, Union) are not yet supported.
  duckdb_bind_value(statement, i.idx_t, val.toDuckValue)

template bindVal*[T](statement: Statement, i: int, val: Option[T]): DuckState =
  ## Binds an `Option[T]`: `some(v)` binds `v` via the matching `bindVal`
  ## overload for `T`; `none(T)` binds NULL.
  if val.isSome: statement.bindVal(i, val.get)
  else: statement.bindNull(i)

template bindVal*(statement: Statement, i: int, val: JsonNode): DuckState =
  ## Binds a `JsonNode` as its `$`-stringified JSON text via VARCHAR; DuckDB
  ## coerces it back to a JSON column on bind. Native `duckdb_bind_json` is
  ## not in this libduckdb version.
  duckdb_bind_varchar(statement, i.idx_t, ($val).cstring)

template bindVal*(statement: Statement, i: int, val: DecimalType): DuckState =
  ## Binds a `DecimalType` as its `$`-stringified text via VARCHAR; DuckDB
  ## coerces it back to the column's DECIMAL scale on bind.
  duckdb_bind_varchar(statement, i.idx_t, ($val).cstring)

template bindVal*(statement: Statement, i: int, val: Uuid): DuckState =
  ## Binds a `Uuid` as its canonical hyphenated string via VARCHAR; DuckDB
  ## coerces it back to a UUID column on bind. (`duckdb_bind_uuid` is not
  ## in this libduckdb version.)
  duckdb_bind_varchar(statement, i.idx_t, ($val).cstring)

# ---------------------------------------------------------------------------
# Appender templates
# ---------------------------------------------------------------------------

template append*(appender: Appender, val: bool): untyped =
  ## Appends a bool value to the appender.
  checkAppender(duckdb_append_bool(appender, val),
    appender, "Failed to append bool value: " & $val)

template append*(appender: Appender, val: seq[byte]): untyped =
  ## Appends a blob value to the appender.
  block:
    let v = val
    checkAppender(
      duckdb_append_blob(appender,
        if v.len == 0: nil
        else: cast[pointer](addr v[0]), v.len.idx_t),
      appender, "Failed to append blob value of length: " & $v.len)

template append*(appender: Appender): untyped =
  ## Appends a default value to the appender.
  checkAppender(duckdb_append_default(appender),
    appender, "Failed to append default value")

template append*(appender: Appender, val: int8): untyped =
  ## Appends an int8_t value to the appender.
  checkAppender(duckdb_append_int8(appender, val),
    appender, "Failed to append int8 value: " & $val)

template append*(appender: Appender, val: int16): untyped =
  ## Appends an int16_t value to the appender.
  checkAppender(duckdb_append_int16(appender, val),
    appender, "Failed to append int16 value: " & $val)

template append*(appender: Appender, val: int32): untyped =
  ## Appends an int32_t value to the appender.
  checkAppender(duckdb_append_int32(appender, val),
    appender, "Failed to append int32 value: " & $val)

template append*(appender: Appender, val: int64): untyped =
  ## Appends an int64_t value to the appender.
  checkAppender(duckdb_append_int64(appender, val),
    appender, "Failed to append int64 value: " & $val)

template append*(appender: Appender, val: int): untyped =
  ## Appends an int value to the appender (converted to int64).
  checkAppender(duckdb_append_int64(appender, int64(val)),
    appender, "Failed to append int value: " & $val)

template append*(appender: Appender, val: uint8): untyped =
  ## Appends an uint8_t value to the appender.
  checkAppender(duckdb_append_uint8(appender, val),
    appender, "Failed to append uint8 value: " & $val)

template append*(appender: Appender, val: uint16): untyped =
  ## Appends an uint16_t value to the appender.
  checkAppender(duckdb_append_uint16(appender, val),
    appender, "Failed to append uint16 value: " & $val)

template append*(appender: Appender, val: uint32): untyped =
  ## Appends an uint32_t value to the appender.
  checkAppender(duckdb_append_uint32(appender, val),
    appender, "Failed to append uint32 value: " & $val)

template append*(appender: Appender, val: uint64): untyped =
  ## Appends an uint64_t value to the appender.
  checkAppender(duckdb_append_uint64(appender, val),
    appender, "Failed to append uint64 value: " & $val)

template append*(appender: Appender, val: float32): untyped =
  ## Appends a float value to the appender.
  checkAppender(duckdb_append_float(appender, val),
    appender, "Failed to append float32 value: " & $val)

template append*(appender: Appender, val: float64): untyped =
  ## Appends a double value to the appender.
  checkAppender(duckdb_append_double(appender, val),
    appender, "Failed to append float64 value: " & $val)

template append*(appender: Appender, val: string): untyped =
  ## Appends a varchar value to the appender. Empty strings are real empty
  ## strings (not NULL); embedded NUL bytes are preserved.
  checkAppender(duckdb_append_varchar_length(appender, val.cstring, val.len.idx_t),
    appender, "Failed to append string value: " & val)

template append*(appender: Appender, val: Int128): untyped =
  ## Appends a HugeInt value to the appender.
  checkAppender(duckdb_append_hugeint(appender, val.toHugeInt),
    appender, "Failed to append Int128 value: " & $val)

template append*(appender: Appender, val: UInt128): untyped =
  ## Appends an unsigned HugeInt value to the appender.
  checkAppender(duckdb_append_uhugeint(appender, val.toUHugeInt),
    appender, "Failed to append UInt128 value: " & $val)

template append*(appender: Appender, val: Timestamp): untyped =
  ## Appends a Timestamp value to the appender.
  checkAppender(duckdb_append_timestamp(appender, val.toTimestamp),
    appender, "Failed to append Timestamp value: " & $val)

template append*(appender: Appender, val: DateTime): untyped =
  ## Appends a DateTime value to the appender.
  checkAppender(duckdb_append_date(appender, val.toDateTime),
    appender, "Failed to append DateTime value: " & $val)

template append*(appender: Appender, val: Time): untyped =
  ## Appends a Time value to the appender.
  checkAppender(duckdb_append_time(appender, val.toTime),
    appender, "Failed to append Time value: " & $val)

template append*(appender: Appender, val: TimeInterval): untyped =
  ## Appends a TimeInterval value to the appender.
  checkAppender(duckdb_append_interval(appender, val.toInterval),
    appender, "Failed to append TimeInterval value: " & $val)

template append*(appender: Appender, val: NimValue): untyped =
  ## Appends a NimValue to the appender.
  ## Complex kinds (List, Struct, Map, Union) are not yet supported.
  checkAppender(duckdb_append_value(appender, val.toDuckValue),
    appender, "Failed to append NimValue")

template append*(appender: Appender, val: DataChunk): untyped =
  ## Appends a DataChunk to the appender (zero-copy bulk insert).
  checkAppender(duckdb_append_data_chunk(appender, val.rawHandle),
    appender, "Failed to append DataChunk")

template append*[T](appender: var Appender, val: Option[T]) =
  ## Appends an ``Option[T]`` value to the appender.
  ## Some values are appended normally; None values emit NULL.
  if val.isSome:
    appender.append(val.get())
  else:
    checkAppender(duckdb_append_null(appender),
      appender, "Failed to append NULL for Option[" & $T & "]")

# ---------------------------------------------------------------------------
# execute — streaming (default)
# ---------------------------------------------------------------------------

proc executeStreaming*[T: Values](
    con: Connection, statement: Statement, args: T
): QResult[Streaming] {.discardable.} =
  ## Executes a prepared statement with provided arguments, returning a
  ## streaming result.
  for i, value in enumerate(args.fields):
    check(
      bindVal(statement, (i + 1), value),
      "Failed to bind" & " " & $value & "[" & $typedesc(value) & "]",
    )
  var raw: duckdb_result
  checkResult(duckdb_execute_prepared_streaming(statement, raw.addr),
    raw, "execute prepared streaming")
  if not duckdb_result_is_streaming(raw):
    duckdb_destroy_result(raw.addr)
    raise newException(OperationError,
      "executeStreaming with prepared statement did not produce a streaming " &
      "result; use executeMaterialized for DML or non-streaming statements")
  result = newQResult(QResult[Streaming], raw)

proc executeStreaming*(con: Connection, statement: Statement): QResult[Streaming] {.discardable.} =
  ## Executes a prepared statement, returning a streaming result.
  ## Raises if the query does not produce a streaming result.
  var raw: duckdb_result
  checkResult(duckdb_execute_prepared_streaming(statement, raw.addr),
    raw, "execute prepared streaming")
  if not duckdb_result_is_streaming(raw):
    duckdb_destroy_result(raw.addr)
    raise newException(OperationError,
      "executeStreaming with prepared statement did not produce a streaming " &
      "result; use executeMaterialized for DML or non-streaming statements")
  result = newQResult(QResult[Streaming], raw)

proc execute*(con: Connection, query: Query): QResult[Materialized] {.discardable.} =
  ## Executes a raw query, materializing results upfront.
  ## Use `executeStreaming(con, newStatement(con, query))` for streaming results.
  var raw: duckdb_result
  checkResult(duckdb_query(con.rawHandle, query, raw.addr),
    raw, "execute query")
  result = newQResult(QResult[Materialized], raw)

proc execute*[T: Values](
    con: Connection, query: Query, args: T
): QResult[Materialized] {.discardable.} =
  ## Executes a query with arguments by first preparing a statement,
  ## returning a materialized result. Use `executeStreaming` for streaming.
  let statement = newStatement(con, query)
  result = con.executeMaterialized(statement, args)

proc executeStreaming*(pending: PendingQueryResult): QResult[Streaming] {.discardable.} =
  ## Executes a pending query result, returning a streaming result.
  ## The pending result must have been created with `newPendingStreamingResult`.
  var raw: duckdb_result
  checkResult(duckdb_execute_pending(pending, raw.addr),
    raw, "execute pending")
  if not duckdb_result_is_streaming(raw):
    duckdb_destroy_result(raw.addr)
    raise newException(OperationError,
      "executeStreaming(pending) requires a streaming pending result; " &
      "use newPendingStreamingResult or executeMaterialized for DML")
  result = newQResult(QResult[Streaming], raw)

# ---------------------------------------------------------------------------
# execute — materialized (for DML and non-streaming queries)
# ---------------------------------------------------------------------------

proc executeMaterialized*(con: Connection, statement: Statement): QResult[Materialized] {.discardable.} =
  ## Executes a prepared statement, materializing results upfront.
  ## Use this for DML statements (INSERT, UPDATE, DELETE) and queries that
  ## do not produce a streaming result.
  var raw: duckdb_result
  checkResult(duckdb_execute_prepared(statement, raw.addr),
    raw, "executeMaterialized")
  result = newQResult(QResult[Materialized], raw)

proc executeMaterialized*[T: Values](
    con: Connection, statement: Statement, args: T
): QResult[Materialized] {.discardable.} =
  ## Executes a prepared statement with provided arguments, materializing
  ## results upfront. Suitable for DML statements and non-streaming queries.
  for i, value in enumerate(args.fields):
    check(
      bindVal(statement, (i + 1), value),
      "Failed to bind" & " " & $value & "[" & $typedesc(value) & "]",
    )
  var raw: duckdb_result
  checkResult(duckdb_execute_prepared(statement, raw.addr),
    raw, "executeMaterialized")
  result = newQResult(QResult[Materialized], raw)

proc executeMaterialized*[T: Values](
    con: Connection, query: Query, args: T
): QResult[Materialized] {.discardable.} =
  ## Executes a query with arguments by first preparing a statement,
  ## then materializing results upfront. Suitable for DML statements
  ## (``INSERT``, ``UPDATE``, ``DELETE``) and non-streaming queries.
  ##
  ## .. code-block:: nim
  ##   conn.executeMaterialized(
  ##     "INSERT INTO t VALUES (?, ?, ?)", (1, "hello", 3.14))
  let statement = newStatement(con, query)
  result = con.executeMaterialized(statement, args)

# # ---------------------------------------------------------------------------
# Pending / step-based execution
# ---------------------------------------------------------------------------

proc step*(pending: PendingQueryResult): PendingState =
  ## Execute one chunk of work on a pending query.
  ## Returns the pending state after the step. Use `isFinished` to check
  ## for completion.
  let raw = duckdb_pending_execute_task(pending)
  result = cast[PendingState](raw)

proc isFinished*(state: PendingState): bool {.inline.} =
  ## True when a pending query has no work left — either finished or errored;
  ## collect the result with `executeStreaming` or read `error`.
  duckdb_pending_execution_is_finished(cast[duckdb_pending_state](state))

proc newPendingResult*(statement: Statement): PendingQueryResult =
  ## Wraps `statement` for step-by-step execution. Create it, then call
  ## `step` repeatedly until `isFinished`, and finally collect the result
  ## with `executeStreaming`.
  result = PendingQueryResult(nil)
  check(
    duckdbPendingPrepared(statement, result.addr),
    "Failed to execute the pending prepared statement",
    `=destroy`(result),
  )

proc newPendingStreamingResult*(statement: Statement): PendingQueryResult =
  ## Creates a pending result that executes in a streaming fashion. This is
  ## the pending counterpart of `executeStreaming`; streaming pending results
  ## are what `executeStreaming(pending)` requires.
  result = PendingQueryResult(nil)
  check(
    duckdbPendingPreparedStreaming(statement, result.addr),
    "Failed to execute the pending prepared streaming statement",
    `=destroy`(result),
  )

proc error*(pqresult: PendingQueryResult): string =
  ## Returns the DuckDB error message for a failed pending query.
  return $duckdbPendingError(pqresult)

# ---------------------------------------------------------------------------
# Appender lifecycle
# ---------------------------------------------------------------------------

proc flush*(appender: Appender) {.discardable.} =
  ## Flush pending rows from the appender to the table.
  ## Call this after `endRow` to commit buffered rows.
  let error = duckdb_appender_flush(appender)
  if error:
    let errorMessage = $duckdb_appender_error(appender)
    raise newException(OperationError, fmt"Failed to flush the appender: {errorMessage}")

proc close*(appender: Appender) {.discardable.} =
  ## Close the appender, flushing any pending rows first.
  ## After closing, the appender cannot accept more rows.
  ## The `=destroy` hook does NOT flush — call `close` or `flush` explicitly.
  let error = duckdb_appender_close(appender)
  if error:
    let errorMessage = $duckdb_appender_error(appender)
    raise newException(OperationError, fmt"Failed to close the appender: {errorMessage}")

proc endRow*(appender: Appender) {.discardable.} =
  ## Signal the end of a row in the appender.
  ## All columns for the current row must have been appended before calling this.
  let error = duckdb_appender_end_row(appender)
  if error:
    let errorMessage = $duckdb_appender_error(appender)
    raise
      newException(OperationError, fmt"Failed to end row for appender: {errorMessage}")

iterator columns*(appender: Appender): AppenderColumn =
  ## Returns the columns in the table that belongs to the appender.
  let nColumns = duckdb_appender_column_count(appender)
  for idx in 0 ..< nColumns:
    yield AppenderColumn(
      idx: idx.int, tpy: newLogicalType(duckdb_appender_column_type(appender, idx))
    )

proc newAppender*(con: Connection, table: string): Appender =
  ## Opens an `Appender` for bulk-inserting rows into `table`. Appended rows
  ## are buffered until `flush` or `close`; the handle is freed on destruction
  ## but rows are **not** flushed automatically.
  result = Appender(nil)
  check(
    duckdb_appender_create(con.rawHandle, nil, table.cstring, result.addr),
    fmt"Failed to create appender for table: {table}",
    `=destroy`(result),
  )

proc newDataChunk*(appender: Appender): DataChunk =
  ## Builds an empty `DataChunk` mirroring the appender's target-table columns;
  ## populate it with the `qresult` chunk helpers to bulk-append whole chunks
  ## via `append(chunk)`.
  var cols: seq[Column]
  for c in columns(appender):
    cols.add newColumn("", c.tpy, idx = c.idx)
  result = newDataChunk(cols)

proc newChunkBuilder*(appender: Appender): ChunkBuilder =
  ## Returns a `ChunkBuilder` pre-sized to the appender's schema — the
  ## convenient front-end for `newDataChunk`.
  result = newChunkBuilder(newDataChunk(appender))

proc appendRows*[T](con: Connection, table: string, ent: seq[seq[T]]) =
  ## Appends a sequence of sequences of type `T` to a specified table in a DuckDB database.
  var appender = newAppender(con, table)
  for row in ent:
    for val in row:
      appender.append(val)
    appender.endRow()
  appender.flush()

proc appendRows*[T](con: Connection, table: string, ent: seq[seq[Option[T]]]) =
  ## Appends a sequence of sequences of ``Options[T]`` to a specified table in a DuckDB database.
  var appender = newAppender(con, table)
  for row in ent:
    for val in row:
      appender.append(val)
    appender.endRow()
  appender.flush()

proc newAppender*[T](con: Connection, table: string, ent: seq[seq[T]]) {.
    deprecated: "use appendRows".} =
  ## Appends rows to a table; use `appendRows` instead.
  appendRows(con, table, ent)

proc newAppender*[T](con: Connection, table: string, ent: seq[seq[Option[T]]]) {.
    deprecated: "use appendRows".} =
  ## Appends rows to a table; use `appendRows` instead.
  appendRows(con, table, ent)
