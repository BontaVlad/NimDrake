## Core handle types and the DuckDB type system shared by every other module.
##
## `DuckType` mirrors DuckDB's `duckdb_type` enum 1:1 and is the compile-time
## kind used throughout the `qresult` views. The `Duck*Kind` sets group it
## into the categories the codec and chunk layers branch on (integers,
## floats, strings, blobs, temporals, huge ints, complex kinds).
##
## The handle types `Statement`, `PendingQueryResult`, and `LogicalType` are
## ownership-carrying wrappers: each owns a DuckDB resource freed on
## destruction and is non-copyable (`=dup`/`=copy` raise a compile error).
##
## .. note:: `Timestamp` (a distinct `DateTime`) is UTC-based; there is no
##   timezone stored, matching DuckDB's `TIMESTAMP` (as opposed to
##   `TIMESTAMP WITH TIME ZONE`, carried as `ZonedTime`).
import std/[times]

import /[ffi, exceptions]

type
  Timestamp* = distinct DateTime ## A DuckDB `TIMESTAMP` (microsecond precision,
                                 ## no timezone). Convert via `DateTime(x)` or
                                 ## format with `format`.

  Statement* = distinct ptr duckdbPreparedStatement ## Owns a compiled prepared
                                                    ## statement; non-copyable.

  PendingQueryResult* = distinct ptr duckdbPendingResult ## Owns an in-flight
                                                         ## pending query;
                                                         ## non-copyable.

  # The mirror of DuckDB's C `duckdb_type`. Prefer the `Duck*Kind` category
  # sets when branching, not raw equality against single values.
  DuckType* {.pure.} = enum ## The DuckDB C `duckdb_type` enum, mirrored 1:1.
    Invalid = enum_DUCKDB_TYPE.DUCKDB_TYPE_INVALID
    Boolean = enum_DUCKDB_TYPE.DUCKDB_TYPE_BOOLEAN
    TinyInt = enum_DUCKDB_TYPE.DUCKDB_TYPE_TINYINT
    SmallInt = enum_DUCKDB_TYPE.DUCKDB_TYPE_SMALLINT
    Integer = enum_DUCKDB_TYPE.DUCKDB_TYPE_INTEGER
    BigInt = enum_DUCKDB_TYPE.DUCKDB_TYPE_BIGINT
    UTinyInt = enum_DUCKDB_TYPE.DUCKDB_TYPE_UTINYINT
    USmallInt = enum_DUCKDB_TYPE.DUCKDB_TYPE_USMALLINT
    UInteger = enum_DUCKDB_TYPE.DUCKDB_TYPE_UINTEGER
    UBigInt = enum_DUCKDB_TYPE.DUCKDB_TYPE_UBIGINT
    Float = enum_DUCKDB_TYPE.DUCKDB_TYPE_FLOAT
    Double = enum_DUCKDB_TYPE.DUCKDB_TYPE_DOUBLE
    Timestamp = enum_DUCKDB_TYPE.DUCKDB_TYPE_TIMESTAMP
    Date = enum_DUCKDB_TYPE.DUCKDB_TYPE_DATE
    Time = enum_DUCKDB_TYPE.DUCKDB_TYPE_TIME
    Interval = enum_DUCKDB_TYPE.DUCKDB_TYPE_INTERVAL
    HugeInt = enum_DUCKDB_TYPE.DUCKDB_TYPE_HUGEINT
    Varchar = enum_DUCKDB_TYPE.DUCKDB_TYPE_VARCHAR
    Blob = enum_DUCKDB_TYPE.DUCKDB_TYPE_BLOB
    Decimal = enum_DUCKDB_TYPE.DUCKDB_TYPE_DECIMAL
    TimestampS = enum_DUCKDB_TYPE.DUCKDB_TYPE_TIMESTAMP_S
    TimestampMs = enum_DUCKDB_TYPE.DUCKDB_TYPE_TIMESTAMP_MS
    TimestampNs = enum_DUCKDB_TYPE.DUCKDB_TYPE_TIMESTAMP_NS
    Enum = enum_DUCKDB_TYPE.DUCKDB_TYPE_ENUM
    List = enum_DUCKDB_TYPE.DUCKDB_TYPE_LIST
    Struct = enum_DUCKDB_TYPE.DUCKDB_TYPE_STRUCT
    Map = enum_DUCKDB_TYPE.DUCKDB_TYPE_MAP
    UUID = enum_DUCKDB_TYPE.DUCKDB_TYPE_UUID
    Union = enum_DUCKDB_TYPE.DUCKDB_TYPE_UNION
    Bit = enum_DUCKDB_TYPE.DUCKDB_TYPE_BIT
    TimeTz = enum_DUCKDB_TYPE.DUCKDB_TYPE_TIME_TZ
    TimestampTz = enum_DUCKDB_TYPE.DUCKDB_TYPE_TIMESTAMP_TZ
    UHugeInt = enum_DUCKDB_TYPE.DUCKDB_TYPE_UHUGEINT
    Array = enum_DUCKDB_TYPE.DUCKDB_TYPE_ARRAY
    Any = enum_DUCKDB_TYPE.DUCKDB_TYPE_ANY
    SqlNull = enum_DUCKDB_TYPE.DUCKDB_TYPE_SQLNULL
    Bignum = enum_DUCKDB_TYPE.DUCKDB_TYPE_BIGNUM
    StringLiteral = enum_DUCKDB_TYPE.DUCKDB_TYPE_STRING_LITERAL
    IntegerLiteral = enum_DUCKDB_TYPE.DUCKDB_TYPE_INTEGER_LITERAL
    TimeNs = enum_DUCKDB_TYPE.DUCKDB_TYPE_TIME_NS
    Geometry = enum_DUCKDB_TYPE.DUCKDB_TYPE_GEOMETRY
    Variant = enum_DUCKDB_TYPE.DUCKDB_TYPE_VARIANT

const
  DuckIntegerKind* = { ## All integer kinds (signed and unsigned).
    DuckType.TinyInt, DuckType.SmallInt, DuckType.Integer, DuckType.BigInt,
    DuckType.UTinyInt, DuckType.USmallInt, DuckType.UInteger, DuckType.UBigInt,
  }
  DuckFloatKind* = {DuckType.Float, DuckType.Double} ## 32- and 64-bit floats.
  DuckStringKind* = {DuckType.Varchar, DuckType.Bit} ## Text-like kinds.
  DuckBlobKind* = {DuckType.Blob} ## Raw byte blobs.
  DuckTemporalKind* = { ## Date/time kinds, including count `S`/`MS`/`NS` variants.
    DuckType.Timestamp, DuckType.TimestampS, DuckType.TimestampMs,
    DuckType.TimestampNs, DuckType.Date, DuckType.Time, DuckType.TimeTz,
    DuckType.TimestampTz,
  }
  DuckHugeKind* = {DuckType.HugeInt, DuckType.UHugeInt} ## 128-bit integers.
  DuckPrimitiveKind* = DuckIntegerKind + DuckFloatKind ## Fixed-width scalars.
  DuckComplexKind* = { ## Nested kinds with one or more child columns.
    DuckType.List, DuckType.Array, DuckType.Struct,
    DuckType.Map, DuckType.Union}

type
  LogicalTypeObj = object
    handle*: duckdbLogicalType
    childNames*: ref seq[string] ## Lazily-populated cache of struct/union
                                  ## child/member names. Nil until first access.

  LogicalType* = ref LogicalTypeObj ## Owns a DuckDB logical-type handle plus a
                                   ## cache of struct/union child/member names.

proc `=destroy`*(statement: Statement) =
  ## Destroys a prepared statement instance if it exists
  if cast[ptr duckdbPreparedStatement](statement) != nil:
    duckdbDestroyPrepare(cast[ptr duckdbPreparedStatement](statement.addr))

## Statement is move-only: copying would double-free the DuckDB handle.
proc `=copy`*(dest: var Statement, source: Statement) {.error.}
## Statement is move-only.
proc `=dup`*(statement: Statement): Statement {.error.}

## Resets a moved-from statement to an empty handle; the old handle was
## transferred by ARC, not freed here.
proc `=wasMoved`*(statement: var Statement) =
  statement = Statement(nil)

## Frees the DuckDB logical-type handle and its child-name cache.
proc `=destroy`*(lt: LogicalTypeObj) =
  if lt.handle != nil:
    duckdbDestroyLogicalType(lt.handle.addr)
  `=destroy`(lt.childNames)

## Resets a moved-from LogicalTypeObj; the old handle was transferred by ARC.
proc `=wasMoved`*(lt: var LogicalTypeObj) =
  lt.handle = nil
  lt.childNames = nil

## Frees the DuckDB pending-result handle; the pending query must already be
## finished (collected via `executeStreaming`) or its work is cancelled.
proc `=destroy`*(pqresult: PendingQueryResult) =
  if cast[ptr duckdbPendingResult](pqresult) != nil:
    duckdbDestroyPending(cast[ptr duckdbPendingResult](pqresult.addr))

## PendingQueryResult is move-only.
proc `=copy`*(dest: var PendingQueryResult, source: PendingQueryResult) {.error.}
## PendingQueryResult is move-only.
proc `=dup`*(pqresult: PendingQueryResult): PendingQueryResult {.error.}

proc `=wasMoved`*(pqresult: var PendingQueryResult) =
  pqresult = PendingQueryResult(nil)

proc rawHandle*(s: Statement): duckdbPreparedStatement {.inline.} =
  ## Underlying DuckDB handle; forwards to the FFI layer.
  cast[duckdbPreparedStatement](s)

proc rawHandle*(p: PendingQueryResult): duckdbPendingResult {.inline.} =
  ## Underlying DuckDB handle; forwards to the FFI layer.
  cast[duckdbPendingResult](p)

## Adapts a statement to the underlying handled pointer for FFI calls.
converter toBase*(s: ptr Statement): ptr duckdbPreparedStatement =
  cast[ptr duckdbPreparedStatement](s)

## Adapts a statement to the underlying handle for FFI calls.
converter toBase*(s: Statement): duckdbPreparedStatement =
  cast[duckdbPreparedStatement](s)

## Adapts a pending result to the underlying handle pointer for FFI calls.
converter toBase*(p: ptr PendingQueryResult): ptr duckdbPendingResult =
  cast[ptr duckdbPendingResult](p)

## Adapts a pending result to the underlying handle for FFI calls.
converter toBase*(p: PendingQueryResult): duckdbPendingResult =
  cast[duckdbPendingResult](p)

proc `$`*(x: Timestamp): string =
  ## Formats a `Timestamp` using the default ISO-ish format.
  $DateTime(x)

proc toTime*(x: Timestamp): Time {.borrow.}
  ## Extracts the time-of-day component from a full Timestamp.
  ## The date portion is discarded; use `DateTime(x)` to preserve both.

## Timestamps compare by underlying `DateTime` value.
proc `==`*(x, y: Timestamp): bool {.borrow.}
proc format*(dt: Timestamp, f: string): string =
  ## Formats `dt` with the `times` module layout string `f`.
  DateTime(dt).format(f)

func duckTypeFromInt(x: int): DuckType {.inline.} =
  if x in DuckType.low.int .. DuckType.high.int:
    cast[DuckType](x)
  else:
    raise newException(OperationError, "Value not convertible to DuckType: " & $x)

proc toDuckType*(i: duckdb_logical_type): DuckType =
  ## Maps a raw DuckDB logical-type handle to its `DuckType` category.
  let id = duckdbGetTypeId(i)
  return duckTypeFromInt(id.int)

proc toDuckType*(i: LogicalType): DuckType =
  ## Convenience for `toDuckType(i.handle)`.
  return toDuckType(i.handle)

proc toDuckType*(i: enum_DUCKDB_TYPE): DuckType =
  ## Maps the C enum to the Nim enum.
  result = duckTypeFromInt(i.int)

proc toDuckType*[T](t: typedesc[T]): DuckType =
  ## The default Nim type → `DuckType` mapping used by `bindAs`, `Vector`,
  ## and the encoders. `tuple` → `Struct`, `seq` → `List`; anything unmapped
  ## yields `DuckType.Invalid`.
  when T is bool:
    DuckType.Boolean
  elif T is int8 or T is int16 or T is int32 or T is int64 or T is int or
       T is uint8 or T is uint16 or T is uint32 or T is uint64:
    when T is int8: DuckType.TinyInt
    elif T is int16: DuckType.SmallInt
    elif T is int32: DuckType.Integer
    elif T is int64 or T is int: DuckType.BigInt
    elif T is uint8: DuckType.UTinyInt
    elif T is uint16: DuckType.USmallInt
    elif T is uint32: DuckType.UInteger
    else: DuckType.UBigInt
  elif T is float32 or T is float64:
    when T is float32: DuckType.Float
    else: DuckType.Double
  elif T is string:
    DuckType.Varchar
  elif T is seq[byte]:
    DuckType.Blob
  elif T is TimeInterval:
    DuckType.Interval
  elif T is Timestamp or T is DateTime:
    DuckType.Timestamp
  elif T is Time or T is ZonedTime:
    when T is Time: DuckType.Time
    else: DuckType.TimeTz
  elif T is void:
    DuckType.SqlNull
  elif T is tuple:
    DuckType.Struct
  elif T is seq:
    DuckType.List
  else:
    DuckType.Invalid

proc newLogicalType*(i: duckdb_logical_type): LogicalType =
  ## Wraps a raw DuckDB logical-type handle. Struct/union child and member
  ## names are eagerly cached at construction so later readers never mutate
  ## the shared `LogicalType` ref concurrently (safe under ARC).
  new(result)
  result.handle = i
  # Fix #1: Eagerly populate child/member names at construction time so
  # structChildName/unionMemberName never lazily mutate a shared LogicalType
  # ref during concurrent reads — that was a data race under ARC.  This
  # one-time FFI cost is amortised over the whole QResult lifetime.
  let kind = toDuckType(result)
  if kind == DuckType.Struct:
    let n = duckdb_struct_type_child_count(i).int
    new(result.childNames)
    result.childNames[] = newSeq[string](n)
    for k in 0 ..< n:
      let cs = duckdb_struct_type_child_name(i, k.idx_t)
      result.childNames[k] = $cs
      duckdb_free(cast[pointer](cs))
  elif kind == DuckType.Union:
    let n = duckdb_union_type_member_count(i).int
    new(result.childNames)
    result.childNames[] = newSeq[string](n)
    for k in 0 ..< n:
      let cs = duckdb_union_type_member_name(i, k.idx_t)
      result.childNames[k] = $cs
      duckdb_free(cast[pointer](cs))

proc newLogicalType*(pt: DuckType): LogicalType =
  ## Builds a `LogicalType` for a plain (non-parameterized) `DuckType`.
  let tp = duckdb_type(pt.ord)
  let handle = duckdb_create_logical_type(cast[enum_DUCKDB_TYPE](tp))
  result = newLogicalType(handle)

proc `$`*(ltp: LogicalType): string =
  ## Formats the logical type's name, e.g. "VARCHAR".
  result = $toDuckType(ltp)
