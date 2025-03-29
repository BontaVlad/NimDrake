type enum_DUCKDB_TYPE* {.size: sizeof(cuint).} = enum
  DUCKDB_TYPE_INVALID = 0
  DUCKDB_TYPE_BOOLEAN = 1
  DUCKDB_TYPE_TINYINT = 2
  DUCKDB_TYPE_SMALLINT = 3
  DUCKDB_TYPE_INTEGER = 4
  DUCKDB_TYPE_BIGINT = 5
  DUCKDB_TYPE_UTINYINT = 6
  DUCKDB_TYPE_USMALLINT = 7
  DUCKDB_TYPE_UINTEGER = 8
  DUCKDB_TYPE_UBIGINT = 9
  DUCKDB_TYPE_FLOAT = 10
  DUCKDB_TYPE_DOUBLE = 11
  DUCKDB_TYPE_TIMESTAMP = 12
  DUCKDB_TYPE_DATE = 13
  DUCKDB_TYPE_TIME = 14
  DUCKDB_TYPE_INTERVAL = 15
  DUCKDB_TYPE_HUGEINT = 16
  DUCKDB_TYPE_VARCHAR = 17
  DUCKDB_TYPE_BLOB = 18
  DUCKDB_TYPE_DECIMAL = 19
  DUCKDB_TYPE_TIMESTAMP_S = 20
  DUCKDB_TYPE_TIMESTAMP_MS = 21
  DUCKDB_TYPE_TIMESTAMP_NS = 22
  DUCKDB_TYPE_ENUM = 23
  DUCKDB_TYPE_LIST = 24
  DUCKDB_TYPE_STRUCT = 25
  DUCKDB_TYPE_MAP = 26
  DUCKDB_TYPE_UUID = 27
  DUCKDB_TYPE_UNION = 28
  DUCKDB_TYPE_BIT = 29
  DUCKDB_TYPE_TIME_TZ = 30
  DUCKDB_TYPE_TIMESTAMP_TZ = 31
  DUCKDB_TYPE_UHUGEINT = 32
  DUCKDB_TYPE_ARRAY = 33
  DUCKDB_TYPE_ANY = 34
  DUCKDB_TYPE_VARINT = 35
  DUCKDB_TYPE_SQLNULL = 36
  DUCKDB_TYPE_STRING_LITERAL = 37
  DUCKDB_TYPE_INTEGER_LITERAL = 38

type enum_duckdb_state* {.size: sizeof(cuint).} = enum
  DuckDBSuccess = 0
  DuckDBError = 1

type enum_duckdb_pending_state* {.size: sizeof(cuint).} = enum
  DUCKDB_PENDING_RESULT_READY = 0
  DUCKDB_PENDING_RESULT_NOT_READY = 1
  DUCKDB_PENDING_ERROR = 2
  DUCKDB_PENDING_NO_TASKS_AVAILABLE = 3

type enum_duckdb_result_type* {.size: sizeof(cuint).} = enum
  DUCKDB_RESULT_TYPE_INVALID = 0
  DUCKDB_RESULT_TYPE_CHANGED_ROWS = 1
  DUCKDB_RESULT_TYPE_NOTHING = 2
  DUCKDB_RESULT_TYPE_QUERY_RESULT = 3

type enum_duckdb_statement_type* {.size: sizeof(cuint).} = enum
  DUCKDB_STATEMENT_TYPE_INVALID = 0
  DUCKDB_STATEMENT_TYPE_SELECT = 1
  DUCKDB_STATEMENT_TYPE_INSERT = 2
  DUCKDB_STATEMENT_TYPE_UPDATE = 3
  DUCKDB_STATEMENT_TYPE_EXPLAIN = 4
  DUCKDB_STATEMENT_TYPE_DELETE = 5
  DUCKDB_STATEMENT_TYPE_PREPARE = 6
  DUCKDB_STATEMENT_TYPE_CREATE = 7
  DUCKDB_STATEMENT_TYPE_EXECUTE = 8
  DUCKDB_STATEMENT_TYPE_ALTER = 9
  DUCKDB_STATEMENT_TYPE_TRANSACTION = 10
  DUCKDB_STATEMENT_TYPE_COPY = 11
  DUCKDB_STATEMENT_TYPE_ANALYZE = 12
  DUCKDB_STATEMENT_TYPE_VARIABLE_SET = 13
  DUCKDB_STATEMENT_TYPE_CREATE_FUNC = 14
  DUCKDB_STATEMENT_TYPE_DROP = 15
  DUCKDB_STATEMENT_TYPE_EXPORT = 16
  DUCKDB_STATEMENT_TYPE_PRAGMA = 17
  DUCKDB_STATEMENT_TYPE_VACUUM = 18
  DUCKDB_STATEMENT_TYPE_CALL = 19
  DUCKDB_STATEMENT_TYPE_SET = 20
  DUCKDB_STATEMENT_TYPE_LOAD = 21
  DUCKDB_STATEMENT_TYPE_RELATION = 22
  DUCKDB_STATEMENT_TYPE_EXTENSION = 23
  DUCKDB_STATEMENT_TYPE_LOGICAL_PLAN = 24
  DUCKDB_STATEMENT_TYPE_ATTACH = 25
  DUCKDB_STATEMENT_TYPE_DETACH = 26
  DUCKDB_STATEMENT_TYPE_MULTI = 27

type enum_duckdb_error_type* {.size: sizeof(cuint).} = enum
  DUCKDB_ERROR_INVALID = 0
  DUCKDB_ERROR_OUT_OF_RANGE = 1
  DUCKDB_ERROR_CONVERSION = 2
  DUCKDB_ERROR_UNKNOWN_TYPE = 3
  DUCKDB_ERROR_DECIMAL = 4
  DUCKDB_ERROR_MISMATCH_TYPE = 5
  DUCKDB_ERROR_DIVIDE_BY_ZERO = 6
  DUCKDB_ERROR_OBJECT_SIZE = 7
  DUCKDB_ERROR_INVALID_TYPE = 8
  DUCKDB_ERROR_SERIALIZATION = 9
  DUCKDB_ERROR_TRANSACTION = 10
  DUCKDB_ERROR_NOT_IMPLEMENTED = 11
  DUCKDB_ERROR_EXPRESSION = 12
  DUCKDB_ERROR_CATALOG = 13
  DUCKDB_ERROR_PARSER = 14
  DUCKDB_ERROR_PLANNER = 15
  DUCKDB_ERROR_SCHEDULER = 16
  DUCKDB_ERROR_EXECUTOR = 17
  DUCKDB_ERROR_CONSTRAINT = 18
  DUCKDB_ERROR_INDEX = 19
  DUCKDB_ERROR_STAT = 20
  DUCKDB_ERROR_CONNECTION = 21
  DUCKDB_ERROR_SYNTAX = 22
  DUCKDB_ERROR_SETTINGS = 23
  DUCKDB_ERROR_BINDER = 24
  DUCKDB_ERROR_NETWORK = 25
  DUCKDB_ERROR_OPTIMIZER = 26
  DUCKDB_ERROR_NULL_POINTER = 27
  DUCKDB_ERROR_IO = 28
  DUCKDB_ERROR_INTERRUPT = 29
  DUCKDB_ERROR_FATAL = 30
  DUCKDB_ERROR_INTERNAL = 31
  DUCKDB_ERROR_INVALID_INPUT = 32
  DUCKDB_ERROR_OUT_OF_MEMORY = 33
  DUCKDB_ERROR_PERMISSION = 34
  DUCKDB_ERROR_PARAMETER_NOT_RESOLVED = 35
  DUCKDB_ERROR_PARAMETER_NOT_ALLOWED = 36
  DUCKDB_ERROR_DEPENDENCY = 37
  DUCKDB_ERROR_HTTP = 38
  DUCKDB_ERROR_MISSING_EXTENSION = 39
  DUCKDB_ERROR_AUTOLOAD = 40
  DUCKDB_ERROR_SEQUENCE = 41
  DUCKDB_INVALID_CONFIGURATION = 42

type enum_duckdb_cast_mode* {.size: sizeof(cuint).} = enum
  DUCKDB_CAST_NORMAL = 0
  DUCKDB_CAST_TRY = 1

type
  duckdb_type* = enum_DUCKDB_TYPE ## Generated based on /usr/include/duckdb.h:141:3
  duckdb_state* = enum_duckdb_state ## Generated based on /usr/include/duckdb.h:143:66
  duckdb_pending_state* = enum_duckdb_pending_state
    ## Generated based on /usr/include/duckdb.h:150:3
  duckdb_result_type* = enum_duckdb_result_type
    ## Generated based on /usr/include/duckdb.h:157:3
  duckdb_statement_type* = enum_duckdb_statement_type
    ## Generated based on /usr/include/duckdb.h:188:3
  duckdb_error_type* = enum_duckdb_error_type
    ## Generated based on /usr/include/duckdb.h:234:3
  duckdb_cast_mode* = enum_duckdb_cast_mode
    ## Generated based on /usr/include/duckdb.h:236:79
  idx_t* = uint64 ## Generated based on /usr/include/duckdb.h:243:18
  duckdb_delete_callback_t* = proc(a0: pointer): void {.cdecl.}
    ## Generated based on /usr/include/duckdb.h:247:16
  duckdb_task_state* = pointer ## Generated based on /usr/include/duckdb.h:250:15
  struct_duckdb_date* {.pure, inheritable, bycopy.} = object
    days*: int32 ## Generated based on /usr/include/duckdb.h:258:9

  duckdb_date* = struct_duckdb_date ## Generated based on /usr/include/duckdb.h:260:3
  struct_duckdb_date_struct* {.pure, inheritable, bycopy.} = object
    year*: int32 ## Generated based on /usr/include/duckdb.h:261:9
    month*: int8
    day*: int8

  duckdb_date_struct* = struct_duckdb_date_struct
    ## Generated based on /usr/include/duckdb.h:265:3
  struct_duckdb_time* {.pure, inheritable, bycopy.} = object
    micros*: int64 ## Generated based on /usr/include/duckdb.h:269:9

  duckdb_time* = struct_duckdb_time ## Generated based on /usr/include/duckdb.h:271:3
  struct_duckdb_time_struct* {.pure, inheritable, bycopy.} = object
    hour*: int8 ## Generated based on /usr/include/duckdb.h:272:9
    min*: int8
    sec*: int8
    micros*: int32

  duckdb_time_struct* = struct_duckdb_time_struct
    ## Generated based on /usr/include/duckdb.h:277:3
  struct_duckdb_time_tz* {.pure, inheritable, bycopy.} = object
    bits*: uint64 ## Generated based on /usr/include/duckdb.h:280:9

  duckdb_time_tz* = struct_duckdb_time_tz
    ## Generated based on /usr/include/duckdb.h:282:3
  struct_duckdb_time_tz_struct* {.pure, inheritable, bycopy.} = object
    time*: duckdb_time_struct ## Generated based on /usr/include/duckdb.h:283:9
    offset*: int32

  duckdb_time_tz_struct* = struct_duckdb_time_tz_struct
    ## Generated based on /usr/include/duckdb.h:286:3
  struct_duckdb_timestamp* {.pure, inheritable, bycopy.} = object
    micros*: int64 ## Generated based on /usr/include/duckdb.h:290:9

  duckdb_timestamp* = struct_duckdb_timestamp
    ## Generated based on /usr/include/duckdb.h:292:3
  struct_duckdb_timestamp_s* {.pure, inheritable, bycopy.} = object
    seconds*: int64 ## Generated based on /usr/include/duckdb.h:295:9

  duckdb_timestamp_s* = struct_duckdb_timestamp_s
    ## Generated based on /usr/include/duckdb.h:297:3
  struct_duckdb_timestamp_ms* {.pure, inheritable, bycopy.} = object
    millis*: int64 ## Generated based on /usr/include/duckdb.h:300:9

  duckdb_timestamp_ms* = struct_duckdb_timestamp_ms
    ## Generated based on /usr/include/duckdb.h:302:3
  struct_duckdb_timestamp_ns* {.pure, inheritable, bycopy.} = object
    nanos*: int64 ## Generated based on /usr/include/duckdb.h:305:9

  duckdb_timestamp_ns* = struct_duckdb_timestamp_ns
    ## Generated based on /usr/include/duckdb.h:307:3
  struct_duckdb_timestamp_struct* {.pure, inheritable, bycopy.} = object
    date*: duckdb_date_struct ## Generated based on /usr/include/duckdb.h:309:9
    time*: duckdb_time_struct

  duckdb_timestamp_struct* = struct_duckdb_timestamp_struct
    ## Generated based on /usr/include/duckdb.h:312:3
  struct_duckdb_interval* {.pure, inheritable, bycopy.} = object
    months*: int32 ## Generated based on /usr/include/duckdb.h:314:9
    days*: int32
    micros*: int64

  duckdb_interval* = struct_duckdb_interval
    ## Generated based on /usr/include/duckdb.h:318:3
  struct_duckdb_hugeint* {.pure, inheritable, bycopy.} = object
    lower*: uint64 ## Generated based on /usr/include/duckdb.h:323:9
    upper*: int64

  duckdb_hugeint* = struct_duckdb_hugeint
    ## Generated based on /usr/include/duckdb.h:326:3
  struct_duckdb_uhugeint* {.pure, inheritable, bycopy.} = object
    lower*: uint64 ## Generated based on /usr/include/duckdb.h:327:9
    upper*: uint64

  duckdb_uhugeint* = struct_duckdb_uhugeint
    ## Generated based on /usr/include/duckdb.h:330:3
  struct_duckdb_decimal* {.pure, inheritable, bycopy.} = object
    width*: uint8 ## Generated based on /usr/include/duckdb.h:333:9
    scale*: uint8
    value*: duckdb_hugeint

  duckdb_decimal* = struct_duckdb_decimal
    ## Generated based on /usr/include/duckdb.h:337:3
  struct_duckdb_query_progress_type* {.pure, inheritable, bycopy.} = object
    percentage*: cdouble ## Generated based on /usr/include/duckdb.h:340:9
    rows_processed*: uint64
    total_rows_to_process*: uint64

  duckdb_query_progress_type* = struct_duckdb_query_progress_type
    ## Generated based on /usr/include/duckdb.h:344:3
  struct_duckdb_string_t_value_t_pointer_t* {.pure, inheritable, bycopy.} = object
    length*: uint32
    prefix*: array[4'i64, cschar]
    ptr_field*: cstring

  struct_duckdb_string_t_value_t_inlined_t* {.pure, inheritable, bycopy.} = object
    length*: uint32
    inlined*: array[12'i64, cschar]

  struct_duckdb_string_t_value_t* {.union, bycopy.} = object
    pointer*: struct_duckdb_string_t_value_t_pointer_t
    inlined*: struct_duckdb_string_t_value_t_inlined_t

  struct_duckdb_string_t* {.pure, inheritable, bycopy.} = object
    value*: struct_duckdb_string_t_value_t
      ## Generated based on /usr/include/duckdb.h:350:9

  duckdb_string_t* = struct_duckdb_string_t
    ## Generated based on /usr/include/duckdb.h:362:3
  struct_duckdb_list_entry* {.pure, inheritable, bycopy.} = object
    offset*: uint64 ## Generated based on /usr/include/duckdb.h:367:9
    length*: uint64

  duckdb_list_entry* = struct_duckdb_list_entry
    ## Generated based on /usr/include/duckdb.h:370:3
  struct_duckdb_column* {.pure, inheritable, bycopy.} = object
    deprecated_data*: pointer ## Generated based on /usr/include/duckdb.h:376:9
    deprecated_nullmask*: ptr bool
    deprecated_type*: duckdb_type
    deprecated_name*: cstring
    internal_data*: pointer

  duckdb_column* = struct_duckdb_column ## Generated based on /usr/include/duckdb.h:386:3
  struct_duckdb_vector* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:390:16

  duckdb_vector* = ptr struct_duckdb_vector
    ## Generated based on /usr/include/duckdb.h:392:5
  struct_duckdb_string* {.pure, inheritable, bycopy.} = object
    data*: cstring ## Generated based on /usr/include/duckdb.h:400:9
    size*: idx_t

  duckdb_string* = struct_duckdb_string ## Generated based on /usr/include/duckdb.h:403:3
  struct_duckdb_blob* {.pure, inheritable, bycopy.} = object
    data*: pointer ## Generated based on /usr/include/duckdb.h:407:9
    size*: idx_t

  duckdb_blob* = struct_duckdb_blob ## Generated based on /usr/include/duckdb.h:410:3
  struct_duckdb_bit* {.pure, inheritable, bycopy.} = object
    data*: ptr uint8 ## Generated based on /usr/include/duckdb.h:417:9
    size*: idx_t

  duckdb_bit* = struct_duckdb_bit ## Generated based on /usr/include/duckdb.h:420:3
  struct_duckdb_varint* {.pure, inheritable, bycopy.} = object
    data*: ptr uint8 ## Generated based on /usr/include/duckdb.h:425:9
    size*: idx_t
    is_negative*: bool

  duckdb_varint* = struct_duckdb_varint ## Generated based on /usr/include/duckdb.h:429:3
  struct_duckdb_result* {.pure, inheritable, bycopy.} = object
    deprecated_column_count*: idx_t ## Generated based on /usr/include/duckdb.h:433:9
    deprecated_row_count*: idx_t
    deprecated_rows_changed*: idx_t
    deprecated_columns*: ptr duckdb_column
    deprecated_error_message*: cstring
    internal_data*: pointer

  duckdb_result* = struct_duckdb_result ## Generated based on /usr/include/duckdb.h:445:3
  struct_duckdb_instance_cache* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:448:16

  duckdb_instance_cache* = ptr struct_duckdb_instance_cache
    ## Generated based on /usr/include/duckdb.h:450:5
  struct_duckdb_database* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:453:16

  duckdb_database* = ptr struct_duckdb_database
    ## Generated based on /usr/include/duckdb.h:455:5
  struct_duckdb_connection* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:458:16

  duckdb_connection* = ptr struct_duckdb_connection
    ## Generated based on /usr/include/duckdb.h:460:5
  struct_duckdb_prepared_statement* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:464:16

  duckdb_prepared_statement* = ptr struct_duckdb_prepared_statement
    ## Generated based on /usr/include/duckdb.h:466:5
  struct_duckdb_extracted_statements* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:469:16

  duckdb_extracted_statements* = ptr struct_duckdb_extracted_statements
    ## Generated based on /usr/include/duckdb.h:471:5
  struct_duckdb_pending_result* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:475:16

  duckdb_pending_result* = ptr struct_duckdb_pending_result
    ## Generated based on /usr/include/duckdb.h:477:5
  struct_duckdb_appender* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:481:16

  duckdb_appender* = ptr struct_duckdb_appender
    ## Generated based on /usr/include/duckdb.h:483:5
  struct_duckdb_table_description* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:487:16

  duckdb_table_description* = ptr struct_duckdb_table_description
    ## Generated based on /usr/include/duckdb.h:489:5
  struct_duckdb_config* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:493:16

  duckdb_config* = ptr struct_duckdb_config
    ## Generated based on /usr/include/duckdb.h:495:5
  struct_duckdb_logical_type* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:499:16

  duckdb_logical_type* = ptr struct_duckdb_logical_type
    ## Generated based on /usr/include/duckdb.h:501:5
  struct_duckdb_create_type_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:505:16

  duckdb_create_type_info* = ptr struct_duckdb_create_type_info
    ## Generated based on /usr/include/duckdb.h:507:5
  struct_duckdb_data_chunk* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:511:16

  duckdb_data_chunk* = ptr struct_duckdb_data_chunk
    ## Generated based on /usr/include/duckdb.h:513:5
  struct_duckdb_value* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:517:16

  duckdb_value* = ptr struct_duckdb_value
    ## Generated based on /usr/include/duckdb.h:519:5
  struct_duckdb_profiling_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:522:16

  duckdb_profiling_info* = ptr struct_duckdb_profiling_info
    ## Generated based on /usr/include/duckdb.h:524:5
  struct_duckdb_extension_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:530:16

  duckdb_extension_info* = ptr struct_duckdb_extension_info
    ## Generated based on /usr/include/duckdb.h:532:5
  struct_duckdb_function_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:538:16

  duckdb_function_info* = ptr struct_duckdb_function_info
    ## Generated based on /usr/include/duckdb.h:540:5
  struct_duckdb_scalar_function* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:546:16

  duckdb_scalar_function* = ptr struct_duckdb_scalar_function
    ## Generated based on /usr/include/duckdb.h:548:5
  struct_duckdb_scalar_function_set* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:551:16

  duckdb_scalar_function_set* = ptr struct_duckdb_scalar_function_set
    ## Generated based on /usr/include/duckdb.h:553:5
  duckdb_scalar_function_t* = proc(
    a0: duckdb_function_info, a1: duckdb_data_chunk, a2: duckdb_vector
  ): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:556:16
  struct_duckdb_aggregate_function* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:562:16

  duckdb_aggregate_function* = ptr struct_duckdb_aggregate_function
    ## Generated based on /usr/include/duckdb.h:564:5
  struct_duckdb_aggregate_function_set* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:567:16

  duckdb_aggregate_function_set* = ptr struct_duckdb_aggregate_function_set
    ## Generated based on /usr/include/duckdb.h:569:5
  struct_duckdb_aggregate_state* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:572:16

  duckdb_aggregate_state* = ptr struct_duckdb_aggregate_state
    ## Generated based on /usr/include/duckdb.h:574:5
  duckdb_aggregate_state_size* = proc(a0: duckdb_function_info): idx_t {.cdecl.}
    ## Generated based on /usr/include/duckdb.h:577:17
  duckdb_aggregate_init_t* =
    proc(a0: duckdb_function_info, a1: duckdb_aggregate_state): void {.cdecl.}
    ## Generated based on /usr/include/duckdb.h:579:16
  duckdb_aggregate_destroy_t* =
    proc(a0: ptr duckdb_aggregate_state, a1: idx_t): void {.cdecl.}
    ## Generated based on /usr/include/duckdb.h:581:16
  duckdb_aggregate_update_t* = proc(
    a0: duckdb_function_info, a1: duckdb_data_chunk, a2: ptr duckdb_aggregate_state
  ): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:583:16
  duckdb_aggregate_combine_t* = proc(
    a0: duckdb_function_info,
    a1: ptr duckdb_aggregate_state,
    a2: ptr duckdb_aggregate_state,
    a3: idx_t,
  ): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:586:16
  duckdb_aggregate_finalize_t* = proc(
    a0: duckdb_function_info,
    a1: ptr duckdb_aggregate_state,
    a2: duckdb_vector,
    a3: idx_t,
    a4: idx_t,
  ): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:589:16
  struct_duckdb_table_function* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:597:16

  duckdb_table_function* = ptr struct_duckdb_table_function
    ## Generated based on /usr/include/duckdb.h:599:5
  struct_duckdb_bind_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:602:16

  duckdb_bind_info* = ptr struct_duckdb_bind_info
    ## Generated based on /usr/include/duckdb.h:604:5
  struct_duckdb_init_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:607:16

  duckdb_init_info* = ptr struct_duckdb_init_info
    ## Generated based on /usr/include/duckdb.h:609:5
  duckdb_table_function_bind_t* = proc(a0: duckdb_bind_info): void {.cdecl.}
    ## Generated based on /usr/include/duckdb.h:612:16
  duckdb_table_function_init_t* = proc(a0: duckdb_init_info): void {.cdecl.}
    ## Generated based on /usr/include/duckdb.h:615:16
  duckdb_table_function_t* =
    proc(a0: duckdb_function_info, a1: duckdb_data_chunk): void {.cdecl.}
    ## Generated based on /usr/include/duckdb.h:618:16
  struct_duckdb_cast_function* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:625:16

  duckdb_cast_function* = ptr struct_duckdb_cast_function
    ## Generated based on /usr/include/duckdb.h:627:5
  duckdb_cast_function_t* = proc(
    a0: duckdb_function_info, a1: idx_t, a2: duckdb_vector, a3: duckdb_vector
  ): bool {.cdecl.} ## Generated based on /usr/include/duckdb.h:629:16
  struct_duckdb_replacement_scan_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:637:16

  duckdb_replacement_scan_info* = ptr struct_duckdb_replacement_scan_info
    ## Generated based on /usr/include/duckdb.h:639:5
  duckdb_replacement_callback_t* =
    proc(a0: duckdb_replacement_scan_info, a1: cstring, a2: pointer): void {.cdecl.}
    ## Generated based on /usr/include/duckdb.h:642:16
  struct_duckdb_arrow* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:649:16

  duckdb_arrow* = ptr struct_duckdb_arrow
    ## Generated based on /usr/include/duckdb.h:651:5
  struct_duckdb_arrow_stream* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:654:16

  duckdb_arrow_stream* = ptr struct_duckdb_arrow_stream
    ## Generated based on /usr/include/duckdb.h:656:5
  struct_duckdb_arrow_schema* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:659:16

  duckdb_arrow_schema* = ptr struct_duckdb_arrow_schema
    ## Generated based on /usr/include/duckdb.h:661:5
  struct_duckdb_arrow_array* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:664:16

  duckdb_arrow_array* = ptr struct_duckdb_arrow_array
    ## Generated based on /usr/include/duckdb.h:666:5
  struct_duckdb_extension_access* {.pure, inheritable, bycopy.} = object
    set_error*: proc(a0: duckdb_extension_info, a1: cstring): void {.cdecl.}
      ## Generated based on /usr/include/duckdb.h:672:8
    get_database*: proc(a0: duckdb_extension_info): ptr duckdb_database {.cdecl.}
    get_api*: proc(a0: duckdb_extension_info, a1: cstring): pointer {.cdecl.}

proc duckdb_create_instance_cache*(): duckdb_instance_cache {.
  cdecl, importc: "duckdb_create_instance_cache"
.}

proc duckdb_get_or_create_from_cache*(
  instance_cache: duckdb_instance_cache,
  path: cstring,
  out_database: ptr duckdb_database,
  config: duckdb_config,
  out_error: ptr cstring,
): duckdb_state {.cdecl, importc: "duckdb_get_or_create_from_cache".}

proc duckdb_destroy_instance_cache*(
  instance_cache: ptr duckdb_instance_cache
): void {.cdecl, importc: "duckdb_destroy_instance_cache".}

proc duckdb_open*(
  path: cstring, out_database: ptr duckdb_database
): duckdb_state {.cdecl, importc: "duckdb_open".}

proc duckdb_open_ext*(
  path: cstring,
  out_database: ptr duckdb_database,
  config: duckdb_config,
  out_error: ptr cstring,
): duckdb_state {.cdecl, importc: "duckdb_open_ext".}

proc duckdb_close*(
  database: ptr duckdb_database
): void {.cdecl, importc: "duckdb_close".}

proc duckdb_connect*(
  database: duckdb_database, out_connection: ptr duckdb_connection
): duckdb_state {.cdecl, importc: "duckdb_connect".}

proc duckdb_interrupt*(
  connection: duckdb_connection
): void {.cdecl, importc: "duckdb_interrupt".}

proc duckdb_query_progress*(
  connection: duckdb_connection
): duckdb_query_progress_type {.cdecl, importc: "duckdb_query_progress".}

proc duckdb_disconnect*(
  connection: ptr duckdb_connection
): void {.cdecl, importc: "duckdb_disconnect".}

proc duckdb_library_version*(): cstring {.cdecl, importc: "duckdb_library_version".}
proc duckdb_create_config*(
  out_config: ptr duckdb_config
): duckdb_state {.cdecl, importc: "duckdb_create_config".}

proc duckdb_config_count*(): csize_t {.cdecl, importc: "duckdb_config_count".}
proc duckdb_get_config_flag*(
  index: csize_t, out_name: ptr cstring, out_description: ptr cstring
): duckdb_state {.cdecl, importc: "duckdb_get_config_flag".}

proc duckdb_set_config*(
  config: duckdb_config, name: cstring, option: cstring
): duckdb_state {.cdecl, importc: "duckdb_set_config".}

proc duckdb_destroy_config*(
  config: ptr duckdb_config
): void {.cdecl, importc: "duckdb_destroy_config".}

proc duckdb_query*(
  connection: duckdb_connection, query: cstring, out_result: ptr duckdb_result
): duckdb_state {.cdecl, importc: "duckdb_query".}

proc duckdb_destroy_result*(
  result: ptr duckdb_result
): void {.cdecl, importc: "duckdb_destroy_result".}

proc duckdb_column_name*(
  result: ptr duckdb_result, col: idx_t
): cstring {.cdecl, importc: "duckdb_column_name".}

proc duckdb_column_type*(
  result: ptr duckdb_result, col: idx_t
): duckdb_type {.cdecl, importc: "duckdb_column_type".}

proc duckdb_result_statement_type*(
  result: duckdb_result
): duckdb_statement_type {.cdecl, importc: "duckdb_result_statement_type".}

proc duckdb_column_logical_type*(
  result: ptr duckdb_result, col: idx_t
): duckdb_logical_type {.cdecl, importc: "duckdb_column_logical_type".}

proc duckdb_column_count*(
  result: ptr duckdb_result
): idx_t {.cdecl, importc: "duckdb_column_count".}

proc duckdb_row_count*(
  result: ptr duckdb_result
): idx_t {.cdecl, importc: "duckdb_row_count".}

proc duckdb_rows_changed*(
  result: ptr duckdb_result
): idx_t {.cdecl, importc: "duckdb_rows_changed".}

proc duckdb_column_data*(
  result: ptr duckdb_result, col: idx_t
): pointer {.cdecl, importc: "duckdb_column_data".}

proc duckdb_nullmask_data*(
  result: ptr duckdb_result, col: idx_t
): ptr bool {.cdecl, importc: "duckdb_nullmask_data".}

proc duckdb_result_error*(
  result: ptr duckdb_result
): cstring {.cdecl, importc: "duckdb_result_error".}

proc duckdb_result_error_type*(
  result: ptr duckdb_result
): duckdb_error_type {.cdecl, importc: "duckdb_result_error_type".}

proc duckdb_result_get_chunk*(
  result: duckdb_result, chunk_index: idx_t
): duckdb_data_chunk {.cdecl, importc: "duckdb_result_get_chunk".}

proc duckdb_result_is_streaming*(
  result: duckdb_result
): bool {.cdecl, importc: "duckdb_result_is_streaming".}

proc duckdb_result_chunk_count*(
  result: duckdb_result
): idx_t {.cdecl, importc: "duckdb_result_chunk_count".}

proc duckdb_result_return_type*(
  result: duckdb_result
): duckdb_result_type {.cdecl, importc: "duckdb_result_return_type".}

proc duckdb_value_boolean*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): bool {.cdecl, importc: "duckdb_value_boolean".}

proc duckdb_value_int8*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): int8 {.cdecl, importc: "duckdb_value_int8".}

proc duckdb_value_int16*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): int16 {.cdecl, importc: "duckdb_value_int16".}

proc duckdb_value_int32*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): int32 {.cdecl, importc: "duckdb_value_int32".}

proc duckdb_value_int64*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): int64 {.cdecl, importc: "duckdb_value_int64".}

proc duckdb_value_hugeint*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): duckdb_hugeint {.cdecl, importc: "duckdb_value_hugeint".}

proc duckdb_value_uhugeint*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): duckdb_uhugeint {.cdecl, importc: "duckdb_value_uhugeint".}

proc duckdb_value_decimal*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): duckdb_decimal {.cdecl, importc: "duckdb_value_decimal".}

proc duckdb_value_uint8*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): uint8 {.cdecl, importc: "duckdb_value_uint8".}

proc duckdb_value_uint16*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): uint16 {.cdecl, importc: "duckdb_value_uint16".}

proc duckdb_value_uint32*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): uint32 {.cdecl, importc: "duckdb_value_uint32".}

proc duckdb_value_uint64*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): uint64 {.cdecl, importc: "duckdb_value_uint64".}

proc duckdb_value_float*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): cfloat {.cdecl, importc: "duckdb_value_float".}

proc duckdb_value_double*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): cdouble {.cdecl, importc: "duckdb_value_double".}

proc duckdb_value_date*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): duckdb_date {.cdecl, importc: "duckdb_value_date".}

proc duckdb_value_time*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): duckdb_time {.cdecl, importc: "duckdb_value_time".}

proc duckdb_value_timestamp*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): duckdb_timestamp {.cdecl, importc: "duckdb_value_timestamp".}

proc duckdb_value_interval*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): duckdb_interval {.cdecl, importc: "duckdb_value_interval".}

proc duckdb_value_varchar*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): cstring {.cdecl, importc: "duckdb_value_varchar".}

proc duckdb_value_string*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): duckdb_string {.cdecl, importc: "duckdb_value_string".}

proc duckdb_value_varchar_internal*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): cstring {.cdecl, importc: "duckdb_value_varchar_internal".}

proc duckdb_value_string_internal*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): duckdb_string {.cdecl, importc: "duckdb_value_string_internal".}

proc duckdb_value_blob*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): duckdb_blob {.cdecl, importc: "duckdb_value_blob".}

proc duckdb_value_is_null*(
  result: ptr duckdb_result, col: idx_t, row: idx_t
): bool {.cdecl, importc: "duckdb_value_is_null".}

proc duckdb_malloc*(size: csize_t): pointer {.cdecl, importc: "duckdb_malloc".}
proc duckdb_free*(ptr_arg: pointer): void {.cdecl, importc: "duckdb_free".}
proc duckdb_vector_size*(): idx_t {.cdecl, importc: "duckdb_vector_size".}
proc duckdb_string_is_inlined*(
  string: duckdb_string_t
): bool {.cdecl, importc: "duckdb_string_is_inlined".}

proc duckdb_string_t_length*(
  string: duckdb_string_t
): uint32 {.cdecl, importc: "duckdb_string_t_length".}

proc duckdb_string_t_data*(
  string: ptr duckdb_string_t
): cstring {.cdecl, importc: "duckdb_string_t_data".}

proc duckdb_from_date*(
  date: duckdb_date
): duckdb_date_struct {.cdecl, importc: "duckdb_from_date".}

proc duckdb_to_date*(
  date: duckdb_date_struct
): duckdb_date {.cdecl, importc: "duckdb_to_date".}

proc duckdb_is_finite_date*(
  date: duckdb_date
): bool {.cdecl, importc: "duckdb_is_finite_date".}

proc duckdb_from_time*(
  time: duckdb_time
): duckdb_time_struct {.cdecl, importc: "duckdb_from_time".}

proc duckdb_create_time_tz*(
  micros: int64, offset: int32
): duckdb_time_tz {.cdecl, importc: "duckdb_create_time_tz".}

proc duckdb_from_time_tz*(
  micros: duckdb_time_tz
): duckdb_time_tz_struct {.cdecl, importc: "duckdb_from_time_tz".}

proc duckdb_to_time*(
  time: duckdb_time_struct
): duckdb_time {.cdecl, importc: "duckdb_to_time".}

proc duckdb_from_timestamp*(
  ts: duckdb_timestamp
): duckdb_timestamp_struct {.cdecl, importc: "duckdb_from_timestamp".}

proc duckdb_to_timestamp*(
  ts: duckdb_timestamp_struct
): duckdb_timestamp {.cdecl, importc: "duckdb_to_timestamp".}

proc duckdb_is_finite_timestamp*(
  ts: duckdb_timestamp
): bool {.cdecl, importc: "duckdb_is_finite_timestamp".}

proc duckdb_is_finite_timestamp_s*(
  ts: duckdb_timestamp_s
): bool {.cdecl, importc: "duckdb_is_finite_timestamp_s".}

proc duckdb_is_finite_timestamp_ms*(
  ts: duckdb_timestamp_ms
): bool {.cdecl, importc: "duckdb_is_finite_timestamp_ms".}

proc duckdb_is_finite_timestamp_ns*(
  ts: duckdb_timestamp_ns
): bool {.cdecl, importc: "duckdb_is_finite_timestamp_ns".}

proc duckdb_hugeint_to_double*(
  val: duckdb_hugeint
): cdouble {.cdecl, importc: "duckdb_hugeint_to_double".}

proc duckdb_double_to_hugeint*(
  val: cdouble
): duckdb_hugeint {.cdecl, importc: "duckdb_double_to_hugeint".}

proc duckdb_uhugeint_to_double*(
  val: duckdb_uhugeint
): cdouble {.cdecl, importc: "duckdb_uhugeint_to_double".}

proc duckdb_double_to_uhugeint*(
  val: cdouble
): duckdb_uhugeint {.cdecl, importc: "duckdb_double_to_uhugeint".}

proc duckdb_double_to_decimal*(
  val: cdouble, width: uint8, scale: uint8
): duckdb_decimal {.cdecl, importc: "duckdb_double_to_decimal".}

proc duckdb_decimal_to_double*(
  val: duckdb_decimal
): cdouble {.cdecl, importc: "duckdb_decimal_to_double".}

proc duckdb_prepare*(
  connection: duckdb_connection,
  query: cstring,
  out_prepared_statement: ptr duckdb_prepared_statement,
): duckdb_state {.cdecl, importc: "duckdb_prepare".}

proc duckdb_destroy_prepare*(
  prepared_statement: ptr duckdb_prepared_statement
): void {.cdecl, importc: "duckdb_destroy_prepare".}

proc duckdb_prepare_error*(
  prepared_statement: duckdb_prepared_statement
): cstring {.cdecl, importc: "duckdb_prepare_error".}

proc duckdb_nparams*(
  prepared_statement: duckdb_prepared_statement
): idx_t {.cdecl, importc: "duckdb_nparams".}

proc duckdb_parameter_name*(
  prepared_statement: duckdb_prepared_statement, index: idx_t
): cstring {.cdecl, importc: "duckdb_parameter_name".}

proc duckdb_param_type*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t
): duckdb_type {.cdecl, importc: "duckdb_param_type".}

proc duckdb_param_logical_type*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t
): duckdb_logical_type {.cdecl, importc: "duckdb_param_logical_type".}

proc duckdb_clear_bindings*(
  prepared_statement: duckdb_prepared_statement
): duckdb_state {.cdecl, importc: "duckdb_clear_bindings".}

proc duckdb_prepared_statement_type*(
  statement: duckdb_prepared_statement
): duckdb_statement_type {.cdecl, importc: "duckdb_prepared_statement_type".}

proc duckdb_bind_value*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: duckdb_value
): duckdb_state {.cdecl, importc: "duckdb_bind_value".}

proc duckdb_bind_parameter_index*(
  prepared_statement: duckdb_prepared_statement, param_idx_out: ptr idx_t, name: cstring
): duckdb_state {.cdecl, importc: "duckdb_bind_parameter_index".}

proc duckdb_bind_boolean*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: bool
): duckdb_state {.cdecl, importc: "duckdb_bind_boolean".}

proc duckdb_bind_int8*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: int8
): duckdb_state {.cdecl, importc: "duckdb_bind_int8".}

proc duckdb_bind_int16*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: int16
): duckdb_state {.cdecl, importc: "duckdb_bind_int16".}

proc duckdb_bind_int32*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: int32
): duckdb_state {.cdecl, importc: "duckdb_bind_int32".}

proc duckdb_bind_int64*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: int64
): duckdb_state {.cdecl, importc: "duckdb_bind_int64".}

proc duckdb_bind_hugeint*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: duckdb_hugeint
): duckdb_state {.cdecl, importc: "duckdb_bind_hugeint".}

proc duckdb_bind_uhugeint*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: duckdb_uhugeint
): duckdb_state {.cdecl, importc: "duckdb_bind_uhugeint".}

proc duckdb_bind_decimal*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: duckdb_decimal
): duckdb_state {.cdecl, importc: "duckdb_bind_decimal".}

proc duckdb_bind_uint8*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: uint8
): duckdb_state {.cdecl, importc: "duckdb_bind_uint8".}

proc duckdb_bind_uint16*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: uint16
): duckdb_state {.cdecl, importc: "duckdb_bind_uint16".}

proc duckdb_bind_uint32*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: uint32
): duckdb_state {.cdecl, importc: "duckdb_bind_uint32".}

proc duckdb_bind_uint64*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: uint64
): duckdb_state {.cdecl, importc: "duckdb_bind_uint64".}

proc duckdb_bind_float*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: cfloat
): duckdb_state {.cdecl, importc: "duckdb_bind_float".}

proc duckdb_bind_double*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: cdouble
): duckdb_state {.cdecl, importc: "duckdb_bind_double".}

proc duckdb_bind_date*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: duckdb_date
): duckdb_state {.cdecl, importc: "duckdb_bind_date".}

proc duckdb_bind_time*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: duckdb_time
): duckdb_state {.cdecl, importc: "duckdb_bind_time".}

proc duckdb_bind_timestamp*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: duckdb_timestamp
): duckdb_state {.cdecl, importc: "duckdb_bind_timestamp".}

proc duckdb_bind_timestamp_tz*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: duckdb_timestamp
): duckdb_state {.cdecl, importc: "duckdb_bind_timestamp_tz".}

proc duckdb_bind_interval*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: duckdb_interval
): duckdb_state {.cdecl, importc: "duckdb_bind_interval".}

proc duckdb_bind_varchar*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t, val: cstring
): duckdb_state {.cdecl, importc: "duckdb_bind_varchar".}

proc duckdb_bind_varchar_length*(
  prepared_statement: duckdb_prepared_statement,
  param_idx: idx_t,
  val: cstring,
  length: idx_t,
): duckdb_state {.cdecl, importc: "duckdb_bind_varchar_length".}

proc duckdb_bind_blob*(
  prepared_statement: duckdb_prepared_statement,
  param_idx: idx_t,
  data: pointer,
  length: idx_t,
): duckdb_state {.cdecl, importc: "duckdb_bind_blob".}

proc duckdb_bind_null*(
  prepared_statement: duckdb_prepared_statement, param_idx: idx_t
): duckdb_state {.cdecl, importc: "duckdb_bind_null".}

proc duckdb_execute_prepared*(
  prepared_statement: duckdb_prepared_statement, out_result: ptr duckdb_result
): duckdb_state {.cdecl, importc: "duckdb_execute_prepared".}

proc duckdb_execute_prepared_streaming*(
  prepared_statement: duckdb_prepared_statement, out_result: ptr duckdb_result
): duckdb_state {.cdecl, importc: "duckdb_execute_prepared_streaming".}

proc duckdb_extract_statements*(
  connection: duckdb_connection,
  query: cstring,
  out_extracted_statements: ptr duckdb_extracted_statements,
): idx_t {.cdecl, importc: "duckdb_extract_statements".}

proc duckdb_prepare_extracted_statement*(
  connection: duckdb_connection,
  extracted_statements: duckdb_extracted_statements,
  index: idx_t,
  out_prepared_statement: ptr duckdb_prepared_statement,
): duckdb_state {.cdecl, importc: "duckdb_prepare_extracted_statement".}

proc duckdb_extract_statements_error*(
  extracted_statements: duckdb_extracted_statements
): cstring {.cdecl, importc: "duckdb_extract_statements_error".}

proc duckdb_destroy_extracted*(
  extracted_statements: ptr duckdb_extracted_statements
): void {.cdecl, importc: "duckdb_destroy_extracted".}

proc duckdb_pending_prepared*(
  prepared_statement: duckdb_prepared_statement, out_result: ptr duckdb_pending_result
): duckdb_state {.cdecl, importc: "duckdb_pending_prepared".}

proc duckdb_pending_prepared_streaming*(
  prepared_statement: duckdb_prepared_statement, out_result: ptr duckdb_pending_result
): duckdb_state {.cdecl, importc: "duckdb_pending_prepared_streaming".}

proc duckdb_destroy_pending*(
  pending_result: ptr duckdb_pending_result
): void {.cdecl, importc: "duckdb_destroy_pending".}

proc duckdb_pending_error*(
  pending_result: duckdb_pending_result
): cstring {.cdecl, importc: "duckdb_pending_error".}

proc duckdb_pending_execute_task*(
  pending_result: duckdb_pending_result
): duckdb_pending_state {.cdecl, importc: "duckdb_pending_execute_task".}

proc duckdb_pending_execute_check_state*(
  pending_result: duckdb_pending_result
): duckdb_pending_state {.cdecl, importc: "duckdb_pending_execute_check_state".}

proc duckdb_execute_pending*(
  pending_result: duckdb_pending_result, out_result: ptr duckdb_result
): duckdb_state {.cdecl, importc: "duckdb_execute_pending".}

proc duckdb_pending_execution_is_finished*(
  pending_state: duckdb_pending_state
): bool {.cdecl, importc: "duckdb_pending_execution_is_finished".}

proc duckdb_destroy_value*(
  value: ptr duckdb_value
): void {.cdecl, importc: "duckdb_destroy_value".}

proc duckdb_create_varchar*(
  text: cstring
): duckdb_value {.cdecl, importc: "duckdb_create_varchar".}

proc duckdb_create_varchar_length*(
  text: cstring, length: idx_t
): duckdb_value {.cdecl, importc: "duckdb_create_varchar_length".}

proc duckdb_create_bool*(
  input: bool
): duckdb_value {.cdecl, importc: "duckdb_create_bool".}

proc duckdb_create_int8*(
  input: int8
): duckdb_value {.cdecl, importc: "duckdb_create_int8".}

proc duckdb_create_uint8*(
  input: uint8
): duckdb_value {.cdecl, importc: "duckdb_create_uint8".}

proc duckdb_create_int16*(
  input: int16
): duckdb_value {.cdecl, importc: "duckdb_create_int16".}

proc duckdb_create_uint16*(
  input: uint16
): duckdb_value {.cdecl, importc: "duckdb_create_uint16".}

proc duckdb_create_int32*(
  input: int32
): duckdb_value {.cdecl, importc: "duckdb_create_int32".}

proc duckdb_create_uint32*(
  input: uint32
): duckdb_value {.cdecl, importc: "duckdb_create_uint32".}

proc duckdb_create_uint64*(
  input: uint64
): duckdb_value {.cdecl, importc: "duckdb_create_uint64".}

proc duckdb_create_int64*(
  val: int64
): duckdb_value {.cdecl, importc: "duckdb_create_int64".}

proc duckdb_create_hugeint*(
  input: duckdb_hugeint
): duckdb_value {.cdecl, importc: "duckdb_create_hugeint".}

proc duckdb_create_uhugeint*(
  input: duckdb_uhugeint
): duckdb_value {.cdecl, importc: "duckdb_create_uhugeint".}

proc duckdb_create_varint*(
  input: duckdb_varint
): duckdb_value {.cdecl, importc: "duckdb_create_varint".}

proc duckdb_create_decimal*(
  input: duckdb_decimal
): duckdb_value {.cdecl, importc: "duckdb_create_decimal".}

proc duckdb_create_float*(
  input: cfloat
): duckdb_value {.cdecl, importc: "duckdb_create_float".}

proc duckdb_create_double*(
  input: cdouble
): duckdb_value {.cdecl, importc: "duckdb_create_double".}

proc duckdb_create_date*(
  input: duckdb_date
): duckdb_value {.cdecl, importc: "duckdb_create_date".}

proc duckdb_create_time*(
  input: duckdb_time
): duckdb_value {.cdecl, importc: "duckdb_create_time".}

proc duckdb_create_time_tz_value*(
  value: duckdb_time_tz
): duckdb_value {.cdecl, importc: "duckdb_create_time_tz_value".}

proc duckdb_create_timestamp*(
  input: duckdb_timestamp
): duckdb_value {.cdecl, importc: "duckdb_create_timestamp".}

proc duckdb_create_timestamp_tz*(
  input: duckdb_timestamp
): duckdb_value {.cdecl, importc: "duckdb_create_timestamp_tz".}

proc duckdb_create_timestamp_s*(
  input: duckdb_timestamp_s
): duckdb_value {.cdecl, importc: "duckdb_create_timestamp_s".}

proc duckdb_create_timestamp_ms*(
  input: duckdb_timestamp_ms
): duckdb_value {.cdecl, importc: "duckdb_create_timestamp_ms".}

proc duckdb_create_timestamp_ns*(
  input: duckdb_timestamp_ns
): duckdb_value {.cdecl, importc: "duckdb_create_timestamp_ns".}

proc duckdb_create_interval*(
  input: duckdb_interval
): duckdb_value {.cdecl, importc: "duckdb_create_interval".}

proc duckdb_create_blob*(
  data: ptr uint8, length: idx_t
): duckdb_value {.cdecl, importc: "duckdb_create_blob".}

proc duckdb_create_bit*(
  input: duckdb_bit
): duckdb_value {.cdecl, importc: "duckdb_create_bit".}

proc duckdb_create_uuid*(
  input: duckdb_uhugeint
): duckdb_value {.cdecl, importc: "duckdb_create_uuid".}

proc duckdb_get_bool*(val: duckdb_value): bool {.cdecl, importc: "duckdb_get_bool".}
proc duckdb_get_int8*(val: duckdb_value): int8 {.cdecl, importc: "duckdb_get_int8".}
proc duckdb_get_uint8*(val: duckdb_value): uint8 {.cdecl, importc: "duckdb_get_uint8".}
proc duckdb_get_int16*(val: duckdb_value): int16 {.cdecl, importc: "duckdb_get_int16".}
proc duckdb_get_uint16*(
  val: duckdb_value
): uint16 {.cdecl, importc: "duckdb_get_uint16".}

proc duckdb_get_int32*(val: duckdb_value): int32 {.cdecl, importc: "duckdb_get_int32".}
proc duckdb_get_uint32*(
  val: duckdb_value
): uint32 {.cdecl, importc: "duckdb_get_uint32".}

proc duckdb_get_int64*(val: duckdb_value): int64 {.cdecl, importc: "duckdb_get_int64".}
proc duckdb_get_uint64*(
  val: duckdb_value
): uint64 {.cdecl, importc: "duckdb_get_uint64".}

proc duckdb_get_hugeint*(
  val: duckdb_value
): duckdb_hugeint {.cdecl, importc: "duckdb_get_hugeint".}

proc duckdb_get_uhugeint*(
  val: duckdb_value
): duckdb_uhugeint {.cdecl, importc: "duckdb_get_uhugeint".}

proc duckdb_get_varint*(
  val: duckdb_value
): duckdb_varint {.cdecl, importc: "duckdb_get_varint".}

proc duckdb_get_decimal*(
  val: duckdb_value
): duckdb_decimal {.cdecl, importc: "duckdb_get_decimal".}

proc duckdb_get_float*(val: duckdb_value): cfloat {.cdecl, importc: "duckdb_get_float".}
proc duckdb_get_double*(
  val: duckdb_value
): cdouble {.cdecl, importc: "duckdb_get_double".}

proc duckdb_get_date*(
  val: duckdb_value
): duckdb_date {.cdecl, importc: "duckdb_get_date".}

proc duckdb_get_time*(
  val: duckdb_value
): duckdb_time {.cdecl, importc: "duckdb_get_time".}

proc duckdb_get_time_tz*(
  val: duckdb_value
): duckdb_time_tz {.cdecl, importc: "duckdb_get_time_tz".}

proc duckdb_get_timestamp*(
  val: duckdb_value
): duckdb_timestamp {.cdecl, importc: "duckdb_get_timestamp".}

proc duckdb_get_timestamp_tz*(
  val: duckdb_value
): duckdb_timestamp {.cdecl, importc: "duckdb_get_timestamp_tz".}

proc duckdb_get_timestamp_s*(
  val: duckdb_value
): duckdb_timestamp_s {.cdecl, importc: "duckdb_get_timestamp_s".}

proc duckdb_get_timestamp_ms*(
  val: duckdb_value
): duckdb_timestamp_ms {.cdecl, importc: "duckdb_get_timestamp_ms".}

proc duckdb_get_timestamp_ns*(
  val: duckdb_value
): duckdb_timestamp_ns {.cdecl, importc: "duckdb_get_timestamp_ns".}

proc duckdb_get_interval*(
  val: duckdb_value
): duckdb_interval {.cdecl, importc: "duckdb_get_interval".}

proc duckdb_get_value_type*(
  val: duckdb_value
): duckdb_logical_type {.cdecl, importc: "duckdb_get_value_type".}

proc duckdb_get_blob*(
  val: duckdb_value
): duckdb_blob {.cdecl, importc: "duckdb_get_blob".}

proc duckdb_get_bit*(val: duckdb_value): duckdb_bit {.cdecl, importc: "duckdb_get_bit".}
proc duckdb_get_uuid*(
  val: duckdb_value
): duckdb_uhugeint {.cdecl, importc: "duckdb_get_uuid".}

proc duckdb_get_varchar*(
  value: duckdb_value
): cstring {.cdecl, importc: "duckdb_get_varchar".}

proc duckdb_create_struct_value*(
  type_arg: duckdb_logical_type, values: ptr duckdb_value
): duckdb_value {.cdecl, importc: "duckdb_create_struct_value".}

proc duckdb_create_list_value*(
  type_arg: duckdb_logical_type, values: ptr duckdb_value, value_count: idx_t
): duckdb_value {.cdecl, importc: "duckdb_create_list_value".}

proc duckdb_create_array_value*(
  type_arg: duckdb_logical_type, values: ptr duckdb_value, value_count: idx_t
): duckdb_value {.cdecl, importc: "duckdb_create_array_value".}

proc duckdb_get_map_size*(
  value: duckdb_value
): idx_t {.cdecl, importc: "duckdb_get_map_size".}

proc duckdb_get_map_key*(
  value: duckdb_value, index: idx_t
): duckdb_value {.cdecl, importc: "duckdb_get_map_key".}

proc duckdb_get_map_value*(
  value: duckdb_value, index: idx_t
): duckdb_value {.cdecl, importc: "duckdb_get_map_value".}

proc duckdb_is_null_value*(
  value: duckdb_value
): bool {.cdecl, importc: "duckdb_is_null_value".}

proc duckdb_create_null_value*(): duckdb_value {.
  cdecl, importc: "duckdb_create_null_value"
.}

proc duckdb_get_list_size*(
  value: duckdb_value
): idx_t {.cdecl, importc: "duckdb_get_list_size".}

proc duckdb_get_list_child*(
  value: duckdb_value, index: idx_t
): duckdb_value {.cdecl, importc: "duckdb_get_list_child".}

proc duckdb_create_enum_value*(
  type_arg: duckdb_logical_type, value: uint64
): duckdb_value {.cdecl, importc: "duckdb_create_enum_value".}

proc duckdb_get_enum_value*(
  value: duckdb_value
): uint64 {.cdecl, importc: "duckdb_get_enum_value".}

proc duckdb_get_struct_child*(
  value: duckdb_value, index: idx_t
): duckdb_value {.cdecl, importc: "duckdb_get_struct_child".}

proc duckdb_create_logical_type*(
  type_arg: duckdb_type
): duckdb_logical_type {.cdecl, importc: "duckdb_create_logical_type".}

proc duckdb_logical_type_get_alias*(
  type_arg: duckdb_logical_type
): cstring {.cdecl, importc: "duckdb_logical_type_get_alias".}

proc duckdb_logical_type_set_alias*(
  type_arg: duckdb_logical_type, alias: cstring
): void {.cdecl, importc: "duckdb_logical_type_set_alias".}

proc duckdb_create_list_type*(
  type_arg: duckdb_logical_type
): duckdb_logical_type {.cdecl, importc: "duckdb_create_list_type".}

proc duckdb_create_array_type*(
  type_arg: duckdb_logical_type, array_size: idx_t
): duckdb_logical_type {.cdecl, importc: "duckdb_create_array_type".}

proc duckdb_create_map_type*(
  key_type: duckdb_logical_type, value_type: duckdb_logical_type
): duckdb_logical_type {.cdecl, importc: "duckdb_create_map_type".}

proc duckdb_create_union_type*(
  member_types: ptr duckdb_logical_type, member_names: ptr cstring, member_count: idx_t
): duckdb_logical_type {.cdecl, importc: "duckdb_create_union_type".}

proc duckdb_create_struct_type*(
  member_types: ptr duckdb_logical_type, member_names: ptr cstring, member_count: idx_t
): duckdb_logical_type {.cdecl, importc: "duckdb_create_struct_type".}

proc duckdb_create_enum_type*(
  member_names: ptr cstring, member_count: idx_t
): duckdb_logical_type {.cdecl, importc: "duckdb_create_enum_type".}

proc duckdb_create_decimal_type*(
  width: uint8, scale: uint8
): duckdb_logical_type {.cdecl, importc: "duckdb_create_decimal_type".}

proc duckdb_get_type_id*(
  type_arg: duckdb_logical_type
): duckdb_type {.cdecl, importc: "duckdb_get_type_id".}

proc duckdb_decimal_width*(
  type_arg: duckdb_logical_type
): uint8 {.cdecl, importc: "duckdb_decimal_width".}

proc duckdb_decimal_scale*(
  type_arg: duckdb_logical_type
): uint8 {.cdecl, importc: "duckdb_decimal_scale".}

proc duckdb_decimal_internal_type*(
  type_arg: duckdb_logical_type
): duckdb_type {.cdecl, importc: "duckdb_decimal_internal_type".}

proc duckdb_enum_internal_type*(
  type_arg: duckdb_logical_type
): duckdb_type {.cdecl, importc: "duckdb_enum_internal_type".}

proc duckdb_enum_dictionary_size*(
  type_arg: duckdb_logical_type
): uint32 {.cdecl, importc: "duckdb_enum_dictionary_size".}

proc duckdb_enum_dictionary_value*(
  type_arg: duckdb_logical_type, index: idx_t
): cstring {.cdecl, importc: "duckdb_enum_dictionary_value".}

proc duckdb_list_type_child_type*(
  type_arg: duckdb_logical_type
): duckdb_logical_type {.cdecl, importc: "duckdb_list_type_child_type".}

proc duckdb_array_type_child_type*(
  type_arg: duckdb_logical_type
): duckdb_logical_type {.cdecl, importc: "duckdb_array_type_child_type".}

proc duckdb_array_type_array_size*(
  type_arg: duckdb_logical_type
): idx_t {.cdecl, importc: "duckdb_array_type_array_size".}

proc duckdb_map_type_key_type*(
  type_arg: duckdb_logical_type
): duckdb_logical_type {.cdecl, importc: "duckdb_map_type_key_type".}

proc duckdb_map_type_value_type*(
  type_arg: duckdb_logical_type
): duckdb_logical_type {.cdecl, importc: "duckdb_map_type_value_type".}

proc duckdb_struct_type_child_count*(
  type_arg: duckdb_logical_type
): idx_t {.cdecl, importc: "duckdb_struct_type_child_count".}

proc duckdb_struct_type_child_name*(
  type_arg: duckdb_logical_type, index: idx_t
): cstring {.cdecl, importc: "duckdb_struct_type_child_name".}

proc duckdb_struct_type_child_type*(
  type_arg: duckdb_logical_type, index: idx_t
): duckdb_logical_type {.cdecl, importc: "duckdb_struct_type_child_type".}

proc duckdb_union_type_member_count*(
  type_arg: duckdb_logical_type
): idx_t {.cdecl, importc: "duckdb_union_type_member_count".}

proc duckdb_union_type_member_name*(
  type_arg: duckdb_logical_type, index: idx_t
): cstring {.cdecl, importc: "duckdb_union_type_member_name".}

proc duckdb_union_type_member_type*(
  type_arg: duckdb_logical_type, index: idx_t
): duckdb_logical_type {.cdecl, importc: "duckdb_union_type_member_type".}

proc duckdb_destroy_logical_type*(
  type_arg: ptr duckdb_logical_type
): void {.cdecl, importc: "duckdb_destroy_logical_type".}

proc duckdb_register_logical_type*(
  con: duckdb_connection, type_arg: duckdb_logical_type, info: duckdb_create_type_info
): duckdb_state {.cdecl, importc: "duckdb_register_logical_type".}

proc duckdb_create_data_chunk*(
  types: ptr duckdb_logical_type, column_count: idx_t
): duckdb_data_chunk {.cdecl, importc: "duckdb_create_data_chunk".}

proc duckdb_destroy_data_chunk*(
  chunk: ptr duckdb_data_chunk
): void {.cdecl, importc: "duckdb_destroy_data_chunk".}

proc duckdb_data_chunk_reset*(
  chunk: duckdb_data_chunk
): void {.cdecl, importc: "duckdb_data_chunk_reset".}

proc duckdb_data_chunk_get_column_count*(
  chunk: duckdb_data_chunk
): idx_t {.cdecl, importc: "duckdb_data_chunk_get_column_count".}

proc duckdb_data_chunk_get_vector*(
  chunk: duckdb_data_chunk, col_idx: idx_t
): duckdb_vector {.cdecl, importc: "duckdb_data_chunk_get_vector".}

proc duckdb_data_chunk_get_size*(
  chunk: duckdb_data_chunk
): idx_t {.cdecl, importc: "duckdb_data_chunk_get_size".}

proc duckdb_data_chunk_set_size*(
  chunk: duckdb_data_chunk, size: idx_t
): void {.cdecl, importc: "duckdb_data_chunk_set_size".}

proc duckdb_vector_get_column_type*(
  vector: duckdb_vector
): duckdb_logical_type {.cdecl, importc: "duckdb_vector_get_column_type".}

proc duckdb_vector_get_data*(
  vector: duckdb_vector
): pointer {.cdecl, importc: "duckdb_vector_get_data".}

proc duckdb_vector_get_validity*(
  vector: duckdb_vector
): ptr uint64 {.cdecl, importc: "duckdb_vector_get_validity".}

proc duckdb_vector_ensure_validity_writable*(
  vector: duckdb_vector
): void {.cdecl, importc: "duckdb_vector_ensure_validity_writable".}

proc duckdb_vector_assign_string_element*(
  vector: duckdb_vector, index: idx_t, str: cstring
): void {.cdecl, importc: "duckdb_vector_assign_string_element".}

proc duckdb_vector_assign_string_element_len*(
  vector: duckdb_vector, index: idx_t, str: cstring, str_len: idx_t
): void {.cdecl, importc: "duckdb_vector_assign_string_element_len".}

proc duckdb_list_vector_get_child*(
  vector: duckdb_vector
): duckdb_vector {.cdecl, importc: "duckdb_list_vector_get_child".}

proc duckdb_list_vector_get_size*(
  vector: duckdb_vector
): idx_t {.cdecl, importc: "duckdb_list_vector_get_size".}

proc duckdb_list_vector_set_size*(
  vector: duckdb_vector, size: idx_t
): duckdb_state {.cdecl, importc: "duckdb_list_vector_set_size".}

proc duckdb_list_vector_reserve*(
  vector: duckdb_vector, required_capacity: idx_t
): duckdb_state {.cdecl, importc: "duckdb_list_vector_reserve".}

proc duckdb_struct_vector_get_child*(
  vector: duckdb_vector, index: idx_t
): duckdb_vector {.cdecl, importc: "duckdb_struct_vector_get_child".}

proc duckdb_array_vector_get_child*(
  vector: duckdb_vector
): duckdb_vector {.cdecl, importc: "duckdb_array_vector_get_child".}

proc duckdb_validity_row_is_valid*(
  validity: ptr uint64, row: idx_t
): bool {.cdecl, importc: "duckdb_validity_row_is_valid".}

proc duckdb_validity_set_row_validity*(
  validity: ptr uint64, row: idx_t, valid: bool
): void {.cdecl, importc: "duckdb_validity_set_row_validity".}

proc duckdb_validity_set_row_invalid*(
  validity: ptr uint64, row: idx_t
): void {.cdecl, importc: "duckdb_validity_set_row_invalid".}

proc duckdb_validity_set_row_valid*(
  validity: ptr uint64, row: idx_t
): void {.cdecl, importc: "duckdb_validity_set_row_valid".}

proc duckdb_create_scalar_function*(): duckdb_scalar_function {.
  cdecl, importc: "duckdb_create_scalar_function"
.}

proc duckdb_destroy_scalar_function*(
  scalar_function: ptr duckdb_scalar_function
): void {.cdecl, importc: "duckdb_destroy_scalar_function".}

proc duckdb_scalar_function_set_name*(
  scalar_function: duckdb_scalar_function, name: cstring
): void {.cdecl, importc: "duckdb_scalar_function_set_name".}

proc duckdb_scalar_function_set_varargs*(
  scalar_function: duckdb_scalar_function, type_arg: duckdb_logical_type
): void {.cdecl, importc: "duckdb_scalar_function_set_varargs".}

proc duckdb_scalar_function_set_special_handling*(
  scalar_function: duckdb_scalar_function
): void {.cdecl, importc: "duckdb_scalar_function_set_special_handling".}

proc duckdb_scalar_function_set_volatile*(
  scalar_function: duckdb_scalar_function
): void {.cdecl, importc: "duckdb_scalar_function_set_volatile".}

proc duckdb_scalar_function_add_parameter*(
  scalar_function: duckdb_scalar_function, type_arg: duckdb_logical_type
): void {.cdecl, importc: "duckdb_scalar_function_add_parameter".}

proc duckdb_scalar_function_set_return_type*(
  scalar_function: duckdb_scalar_function, type_arg: duckdb_logical_type
): void {.cdecl, importc: "duckdb_scalar_function_set_return_type".}

proc duckdb_scalar_function_set_extra_info*(
  scalar_function: duckdb_scalar_function,
  extra_info: pointer,
  destroy: duckdb_delete_callback_t,
): void {.cdecl, importc: "duckdb_scalar_function_set_extra_info".}

proc duckdb_scalar_function_set_function*(
  scalar_function: duckdb_scalar_function, function: duckdb_scalar_function_t
): void {.cdecl, importc: "duckdb_scalar_function_set_function".}

proc duckdb_register_scalar_function*(
  con: duckdb_connection, scalar_function: duckdb_scalar_function
): duckdb_state {.cdecl, importc: "duckdb_register_scalar_function".}

proc duckdb_scalar_function_get_extra_info*(
  info: duckdb_function_info
): pointer {.cdecl, importc: "duckdb_scalar_function_get_extra_info".}

proc duckdb_scalar_function_set_error*(
  info: duckdb_function_info, error: cstring
): void {.cdecl, importc: "duckdb_scalar_function_set_error".}

proc duckdb_create_scalar_function_set*(
  name: cstring
): duckdb_scalar_function_set {.cdecl, importc: "duckdb_create_scalar_function_set".}

proc duckdb_destroy_scalar_function_set*(
  scalar_function_set: ptr duckdb_scalar_function_set
): void {.cdecl, importc: "duckdb_destroy_scalar_function_set".}

proc duckdb_add_scalar_function_to_set*(
  set: duckdb_scalar_function_set, function: duckdb_scalar_function
): duckdb_state {.cdecl, importc: "duckdb_add_scalar_function_to_set".}

proc duckdb_register_scalar_function_set*(
  con: duckdb_connection, set: duckdb_scalar_function_set
): duckdb_state {.cdecl, importc: "duckdb_register_scalar_function_set".}

proc duckdb_create_aggregate_function*(): duckdb_aggregate_function {.
  cdecl, importc: "duckdb_create_aggregate_function"
.}

proc duckdb_destroy_aggregate_function*(
  aggregate_function: ptr duckdb_aggregate_function
): void {.cdecl, importc: "duckdb_destroy_aggregate_function".}

proc duckdb_aggregate_function_set_name*(
  aggregate_function: duckdb_aggregate_function, name: cstring
): void {.cdecl, importc: "duckdb_aggregate_function_set_name".}

proc duckdb_aggregate_function_add_parameter*(
  aggregate_function: duckdb_aggregate_function, type_arg: duckdb_logical_type
): void {.cdecl, importc: "duckdb_aggregate_function_add_parameter".}

proc duckdb_aggregate_function_set_return_type*(
  aggregate_function: duckdb_aggregate_function, type_arg: duckdb_logical_type
): void {.cdecl, importc: "duckdb_aggregate_function_set_return_type".}

proc duckdb_aggregate_function_set_functions*(
  aggregate_function: duckdb_aggregate_function,
  state_size: duckdb_aggregate_state_size,
  state_init: duckdb_aggregate_init_t,
  update: duckdb_aggregate_update_t,
  combine: duckdb_aggregate_combine_t,
  finalize: duckdb_aggregate_finalize_t,
): void {.cdecl, importc: "duckdb_aggregate_function_set_functions".}

proc duckdb_aggregate_function_set_destructor*(
  aggregate_function: duckdb_aggregate_function, destroy: duckdb_aggregate_destroy_t
): void {.cdecl, importc: "duckdb_aggregate_function_set_destructor".}

proc duckdb_register_aggregate_function*(
  con: duckdb_connection, aggregate_function: duckdb_aggregate_function
): duckdb_state {.cdecl, importc: "duckdb_register_aggregate_function".}

proc duckdb_aggregate_function_set_special_handling*(
  aggregate_function: duckdb_aggregate_function
): void {.cdecl, importc: "duckdb_aggregate_function_set_special_handling".}

proc duckdb_aggregate_function_set_extra_info*(
  aggregate_function: duckdb_aggregate_function,
  extra_info: pointer,
  destroy: duckdb_delete_callback_t,
): void {.cdecl, importc: "duckdb_aggregate_function_set_extra_info".}

proc duckdb_aggregate_function_get_extra_info*(
  info: duckdb_function_info
): pointer {.cdecl, importc: "duckdb_aggregate_function_get_extra_info".}

proc duckdb_aggregate_function_set_error*(
  info: duckdb_function_info, error: cstring
): void {.cdecl, importc: "duckdb_aggregate_function_set_error".}

proc duckdb_create_aggregate_function_set*(
  name: cstring
): duckdb_aggregate_function_set {.
  cdecl, importc: "duckdb_create_aggregate_function_set"
.}

proc duckdb_destroy_aggregate_function_set*(
  aggregate_function_set: ptr duckdb_aggregate_function_set
): void {.cdecl, importc: "duckdb_destroy_aggregate_function_set".}

proc duckdb_add_aggregate_function_to_set*(
  set: duckdb_aggregate_function_set, function: duckdb_aggregate_function
): duckdb_state {.cdecl, importc: "duckdb_add_aggregate_function_to_set".}

proc duckdb_register_aggregate_function_set*(
  con: duckdb_connection, set: duckdb_aggregate_function_set
): duckdb_state {.cdecl, importc: "duckdb_register_aggregate_function_set".}

proc duckdb_create_table_function*(): duckdb_table_function {.
  cdecl, importc: "duckdb_create_table_function"
.}

proc duckdb_destroy_table_function*(
  table_function: ptr duckdb_table_function
): void {.cdecl, importc: "duckdb_destroy_table_function".}

proc duckdb_table_function_set_name*(
  table_function: duckdb_table_function, name: cstring
): void {.cdecl, importc: "duckdb_table_function_set_name".}

proc duckdb_table_function_add_parameter*(
  table_function: duckdb_table_function, type_arg: duckdb_logical_type
): void {.cdecl, importc: "duckdb_table_function_add_parameter".}

proc duckdb_table_function_add_named_parameter*(
  table_function: duckdb_table_function, name: cstring, type_arg: duckdb_logical_type
): void {.cdecl, importc: "duckdb_table_function_add_named_parameter".}

proc duckdb_table_function_set_extra_info*(
  table_function: duckdb_table_function,
  extra_info: pointer,
  destroy: duckdb_delete_callback_t,
): void {.cdecl, importc: "duckdb_table_function_set_extra_info".}

proc duckdb_table_function_set_bind*(
  table_function: duckdb_table_function, bind_arg: duckdb_table_function_bind_t
): void {.cdecl, importc: "duckdb_table_function_set_bind".}

proc duckdb_table_function_set_init*(
  table_function: duckdb_table_function, init: duckdb_table_function_init_t
): void {.cdecl, importc: "duckdb_table_function_set_init".}

proc duckdb_table_function_set_local_init*(
  table_function: duckdb_table_function, init: duckdb_table_function_init_t
): void {.cdecl, importc: "duckdb_table_function_set_local_init".}

proc duckdb_table_function_set_function*(
  table_function: duckdb_table_function, function: duckdb_table_function_t
): void {.cdecl, importc: "duckdb_table_function_set_function".}

proc duckdb_table_function_supports_projection_pushdown*(
  table_function: duckdb_table_function, pushdown: bool
): void {.cdecl, importc: "duckdb_table_function_supports_projection_pushdown".}

proc duckdb_register_table_function*(
  con: duckdb_connection, function: duckdb_table_function
): duckdb_state {.cdecl, importc: "duckdb_register_table_function".}

proc duckdb_bind_get_extra_info*(
  info: duckdb_bind_info
): pointer {.cdecl, importc: "duckdb_bind_get_extra_info".}

proc duckdb_bind_add_result_column*(
  info: duckdb_bind_info, name: cstring, type_arg: duckdb_logical_type
): void {.cdecl, importc: "duckdb_bind_add_result_column".}

proc duckdb_bind_get_parameter_count*(
  info: duckdb_bind_info
): idx_t {.cdecl, importc: "duckdb_bind_get_parameter_count".}

proc duckdb_bind_get_parameter*(
  info: duckdb_bind_info, index: idx_t
): duckdb_value {.cdecl, importc: "duckdb_bind_get_parameter".}

proc duckdb_bind_get_named_parameter*(
  info: duckdb_bind_info, name: cstring
): duckdb_value {.cdecl, importc: "duckdb_bind_get_named_parameter".}

proc duckdb_bind_set_bind_data*(
  info: duckdb_bind_info, bind_data: pointer, destroy: duckdb_delete_callback_t
): void {.cdecl, importc: "duckdb_bind_set_bind_data".}

proc duckdb_bind_set_cardinality*(
  info: duckdb_bind_info, cardinality: idx_t, is_exact: bool
): void {.cdecl, importc: "duckdb_bind_set_cardinality".}

proc duckdb_bind_set_error*(
  info: duckdb_bind_info, error: cstring
): void {.cdecl, importc: "duckdb_bind_set_error".}

proc duckdb_init_get_extra_info*(
  info: duckdb_init_info
): pointer {.cdecl, importc: "duckdb_init_get_extra_info".}

proc duckdb_init_get_bind_data*(
  info: duckdb_init_info
): pointer {.cdecl, importc: "duckdb_init_get_bind_data".}

proc duckdb_init_set_init_data*(
  info: duckdb_init_info, init_data: pointer, destroy: duckdb_delete_callback_t
): void {.cdecl, importc: "duckdb_init_set_init_data".}

proc duckdb_init_get_column_count*(
  info: duckdb_init_info
): idx_t {.cdecl, importc: "duckdb_init_get_column_count".}

proc duckdb_init_get_column_index*(
  info: duckdb_init_info, column_index: idx_t
): idx_t {.cdecl, importc: "duckdb_init_get_column_index".}

proc duckdb_init_set_max_threads*(
  info: duckdb_init_info, max_threads: idx_t
): void {.cdecl, importc: "duckdb_init_set_max_threads".}

proc duckdb_init_set_error*(
  info: duckdb_init_info, error: cstring
): void {.cdecl, importc: "duckdb_init_set_error".}

proc duckdb_function_get_extra_info*(
  info: duckdb_function_info
): pointer {.cdecl, importc: "duckdb_function_get_extra_info".}

proc duckdb_function_get_bind_data*(
  info: duckdb_function_info
): pointer {.cdecl, importc: "duckdb_function_get_bind_data".}

proc duckdb_function_get_init_data*(
  info: duckdb_function_info
): pointer {.cdecl, importc: "duckdb_function_get_init_data".}

proc duckdb_function_get_local_init_data*(
  info: duckdb_function_info
): pointer {.cdecl, importc: "duckdb_function_get_local_init_data".}

proc duckdb_function_set_error*(
  info: duckdb_function_info, error: cstring
): void {.cdecl, importc: "duckdb_function_set_error".}

proc duckdb_add_replacement_scan*(
  db: duckdb_database,
  replacement: duckdb_replacement_callback_t,
  extra_data: pointer,
  delete_callback: duckdb_delete_callback_t,
): void {.cdecl, importc: "duckdb_add_replacement_scan".}

proc duckdb_replacement_scan_set_function_name*(
  info: duckdb_replacement_scan_info, function_name: cstring
): void {.cdecl, importc: "duckdb_replacement_scan_set_function_name".}

proc duckdb_replacement_scan_add_parameter*(
  info: duckdb_replacement_scan_info, parameter: duckdb_value
): void {.cdecl, importc: "duckdb_replacement_scan_add_parameter".}

proc duckdb_replacement_scan_set_error*(
  info: duckdb_replacement_scan_info, error: cstring
): void {.cdecl, importc: "duckdb_replacement_scan_set_error".}

proc duckdb_get_profiling_info*(
  connection: duckdb_connection
): duckdb_profiling_info {.cdecl, importc: "duckdb_get_profiling_info".}

proc duckdb_profiling_info_get_value*(
  info: duckdb_profiling_info, key: cstring
): duckdb_value {.cdecl, importc: "duckdb_profiling_info_get_value".}

proc duckdb_profiling_info_get_metrics*(
  info: duckdb_profiling_info
): duckdb_value {.cdecl, importc: "duckdb_profiling_info_get_metrics".}

proc duckdb_profiling_info_get_child_count*(
  info: duckdb_profiling_info
): idx_t {.cdecl, importc: "duckdb_profiling_info_get_child_count".}

proc duckdb_profiling_info_get_child*(
  info: duckdb_profiling_info, index: idx_t
): duckdb_profiling_info {.cdecl, importc: "duckdb_profiling_info_get_child".}

proc duckdb_appender_create*(
  connection: duckdb_connection,
  schema: cstring,
  table: cstring,
  out_appender: ptr duckdb_appender,
): duckdb_state {.cdecl, importc: "duckdb_appender_create".}

proc duckdb_appender_create_ext*(
  connection: duckdb_connection,
  catalog: cstring,
  schema: cstring,
  table: cstring,
  out_appender: ptr duckdb_appender,
): duckdb_state {.cdecl, importc: "duckdb_appender_create_ext".}

proc duckdb_appender_column_count*(
  appender: duckdb_appender
): idx_t {.cdecl, importc: "duckdb_appender_column_count".}

proc duckdb_appender_column_type*(
  appender: duckdb_appender, col_idx: idx_t
): duckdb_logical_type {.cdecl, importc: "duckdb_appender_column_type".}

proc duckdb_appender_error*(
  appender: duckdb_appender
): cstring {.cdecl, importc: "duckdb_appender_error".}

proc duckdb_appender_flush*(
  appender: duckdb_appender
): duckdb_state {.cdecl, importc: "duckdb_appender_flush".}

proc duckdb_appender_close*(
  appender: duckdb_appender
): duckdb_state {.cdecl, importc: "duckdb_appender_close".}

proc duckdb_appender_destroy*(
  appender: ptr duckdb_appender
): duckdb_state {.cdecl, importc: "duckdb_appender_destroy".}

proc duckdb_appender_add_column*(
  appender: duckdb_appender, name: cstring
): duckdb_state {.cdecl, importc: "duckdb_appender_add_column".}

proc duckdb_appender_clear_columns*(
  appender: duckdb_appender
): duckdb_state {.cdecl, importc: "duckdb_appender_clear_columns".}

proc duckdb_appender_begin_row*(
  appender: duckdb_appender
): duckdb_state {.cdecl, importc: "duckdb_appender_begin_row".}

proc duckdb_appender_end_row*(
  appender: duckdb_appender
): duckdb_state {.cdecl, importc: "duckdb_appender_end_row".}

proc duckdb_append_default*(
  appender: duckdb_appender
): duckdb_state {.cdecl, importc: "duckdb_append_default".}

proc duckdb_append_default_to_chunk*(
  appender: duckdb_appender, chunk: duckdb_data_chunk, col: idx_t, row: idx_t
): duckdb_state {.cdecl, importc: "duckdb_append_default_to_chunk".}

proc duckdb_append_bool*(
  appender: duckdb_appender, value: bool
): duckdb_state {.cdecl, importc: "duckdb_append_bool".}

proc duckdb_append_int8*(
  appender: duckdb_appender, value: int8
): duckdb_state {.cdecl, importc: "duckdb_append_int8".}

proc duckdb_append_int16*(
  appender: duckdb_appender, value: int16
): duckdb_state {.cdecl, importc: "duckdb_append_int16".}

proc duckdb_append_int32*(
  appender: duckdb_appender, value: int32
): duckdb_state {.cdecl, importc: "duckdb_append_int32".}

proc duckdb_append_int64*(
  appender: duckdb_appender, value: int64
): duckdb_state {.cdecl, importc: "duckdb_append_int64".}

proc duckdb_append_hugeint*(
  appender: duckdb_appender, value: duckdb_hugeint
): duckdb_state {.cdecl, importc: "duckdb_append_hugeint".}

proc duckdb_append_uint8*(
  appender: duckdb_appender, value: uint8
): duckdb_state {.cdecl, importc: "duckdb_append_uint8".}

proc duckdb_append_uint16*(
  appender: duckdb_appender, value: uint16
): duckdb_state {.cdecl, importc: "duckdb_append_uint16".}

proc duckdb_append_uint32*(
  appender: duckdb_appender, value: uint32
): duckdb_state {.cdecl, importc: "duckdb_append_uint32".}

proc duckdb_append_uint64*(
  appender: duckdb_appender, value: uint64
): duckdb_state {.cdecl, importc: "duckdb_append_uint64".}

proc duckdb_append_uhugeint*(
  appender: duckdb_appender, value: duckdb_uhugeint
): duckdb_state {.cdecl, importc: "duckdb_append_uhugeint".}

proc duckdb_append_float*(
  appender: duckdb_appender, value: cfloat
): duckdb_state {.cdecl, importc: "duckdb_append_float".}

proc duckdb_append_double*(
  appender: duckdb_appender, value: cdouble
): duckdb_state {.cdecl, importc: "duckdb_append_double".}

proc duckdb_append_date*(
  appender: duckdb_appender, value: duckdb_date
): duckdb_state {.cdecl, importc: "duckdb_append_date".}

proc duckdb_append_time*(
  appender: duckdb_appender, value: duckdb_time
): duckdb_state {.cdecl, importc: "duckdb_append_time".}

proc duckdb_append_timestamp*(
  appender: duckdb_appender, value: duckdb_timestamp
): duckdb_state {.cdecl, importc: "duckdb_append_timestamp".}

proc duckdb_append_interval*(
  appender: duckdb_appender, value: duckdb_interval
): duckdb_state {.cdecl, importc: "duckdb_append_interval".}

proc duckdb_append_varchar*(
  appender: duckdb_appender, val: cstring
): duckdb_state {.cdecl, importc: "duckdb_append_varchar".}

proc duckdb_append_varchar_length*(
  appender: duckdb_appender, val: cstring, length: idx_t
): duckdb_state {.cdecl, importc: "duckdb_append_varchar_length".}

proc duckdb_append_blob*(
  appender: duckdb_appender, data: pointer, length: idx_t
): duckdb_state {.cdecl, importc: "duckdb_append_blob".}

proc duckdb_append_null*(
  appender: duckdb_appender
): duckdb_state {.cdecl, importc: "duckdb_append_null".}

proc duckdb_append_value*(
  appender: duckdb_appender, value: duckdb_value
): duckdb_state {.cdecl, importc: "duckdb_append_value".}

proc duckdb_append_data_chunk*(
  appender: duckdb_appender, chunk: duckdb_data_chunk
): duckdb_state {.cdecl, importc: "duckdb_append_data_chunk".}

proc duckdb_table_description_create*(
  connection: duckdb_connection,
  schema: cstring,
  table: cstring,
  out_arg: ptr duckdb_table_description,
): duckdb_state {.cdecl, importc: "duckdb_table_description_create".}

proc duckdb_table_description_create_ext*(
  connection: duckdb_connection,
  catalog: cstring,
  schema: cstring,
  table: cstring,
  out_arg: ptr duckdb_table_description,
): duckdb_state {.cdecl, importc: "duckdb_table_description_create_ext".}

proc duckdb_table_description_destroy*(
  table_description: ptr duckdb_table_description
): void {.cdecl, importc: "duckdb_table_description_destroy".}

proc duckdb_table_description_error*(
  table_description: duckdb_table_description
): cstring {.cdecl, importc: "duckdb_table_description_error".}

proc duckdb_column_has_default*(
  table_description: duckdb_table_description, index: idx_t, out_arg: ptr bool
): duckdb_state {.cdecl, importc: "duckdb_column_has_default".}

proc duckdb_table_description_get_column_name*(
  table_description: duckdb_table_description, index: idx_t
): cstring {.cdecl, importc: "duckdb_table_description_get_column_name".}

proc duckdb_query_arrow*(
  connection: duckdb_connection, query: cstring, out_result: ptr duckdb_arrow
): duckdb_state {.cdecl, importc: "duckdb_query_arrow".}

proc duckdb_query_arrow_schema*(
  result: duckdb_arrow, out_schema: ptr duckdb_arrow_schema
): duckdb_state {.cdecl, importc: "duckdb_query_arrow_schema".}

proc duckdb_prepared_arrow_schema*(
  prepared: duckdb_prepared_statement, out_schema: ptr duckdb_arrow_schema
): duckdb_state {.cdecl, importc: "duckdb_prepared_arrow_schema".}

proc duckdb_result_arrow_array*(
  result: duckdb_result, chunk: duckdb_data_chunk, out_array: ptr duckdb_arrow_array
): void {.cdecl, importc: "duckdb_result_arrow_array".}

proc duckdb_query_arrow_array*(
  result: duckdb_arrow, out_array: ptr duckdb_arrow_array
): duckdb_state {.cdecl, importc: "duckdb_query_arrow_array".}

proc duckdb_arrow_column_count*(
  result: duckdb_arrow
): idx_t {.cdecl, importc: "duckdb_arrow_column_count".}

proc duckdb_arrow_row_count*(
  result: duckdb_arrow
): idx_t {.cdecl, importc: "duckdb_arrow_row_count".}

proc duckdb_arrow_rows_changed*(
  result: duckdb_arrow
): idx_t {.cdecl, importc: "duckdb_arrow_rows_changed".}

proc duckdb_query_arrow_error*(
  result: duckdb_arrow
): cstring {.cdecl, importc: "duckdb_query_arrow_error".}

proc duckdb_destroy_arrow*(
  result: ptr duckdb_arrow
): void {.cdecl, importc: "duckdb_destroy_arrow".}

proc duckdb_destroy_arrow_stream*(
  stream_p: ptr duckdb_arrow_stream
): void {.cdecl, importc: "duckdb_destroy_arrow_stream".}

proc duckdb_execute_prepared_arrow*(
  prepared_statement: duckdb_prepared_statement, out_result: ptr duckdb_arrow
): duckdb_state {.cdecl, importc: "duckdb_execute_prepared_arrow".}

proc duckdb_arrow_scan*(
  connection: duckdb_connection, table_name: cstring, arrow: duckdb_arrow_stream
): duckdb_state {.cdecl, importc: "duckdb_arrow_scan".}

proc duckdb_arrow_array_scan*(
  connection: duckdb_connection,
  table_name: cstring,
  arrow_schema: duckdb_arrow_schema,
  arrow_array: duckdb_arrow_array,
  out_stream: ptr duckdb_arrow_stream,
): duckdb_state {.cdecl, importc: "duckdb_arrow_array_scan".}

proc duckdb_execute_tasks*(
  database: duckdb_database, max_tasks: idx_t
): void {.cdecl, importc: "duckdb_execute_tasks".}

proc duckdb_create_task_state*(
  database: duckdb_database
): duckdb_task_state {.cdecl, importc: "duckdb_create_task_state".}

proc duckdb_execute_tasks_state*(
  state: duckdb_task_state
): void {.cdecl, importc: "duckdb_execute_tasks_state".}

proc duckdb_execute_n_tasks_state*(
  state: duckdb_task_state, max_tasks: idx_t
): idx_t {.cdecl, importc: "duckdb_execute_n_tasks_state".}

proc duckdb_finish_execution*(
  state: duckdb_task_state
): void {.cdecl, importc: "duckdb_finish_execution".}

proc duckdb_task_state_is_finished*(
  state: duckdb_task_state
): bool {.cdecl, importc: "duckdb_task_state_is_finished".}

proc duckdb_destroy_task_state*(
  state: duckdb_task_state
): void {.cdecl, importc: "duckdb_destroy_task_state".}

proc duckdb_execution_is_finished*(
  con: duckdb_connection
): bool {.cdecl, importc: "duckdb_execution_is_finished".}

proc duckdb_stream_fetch_chunk*(
  result: duckdb_result
): duckdb_data_chunk {.cdecl, importc: "duckdb_stream_fetch_chunk".}

proc duckdb_fetch_chunk*(
  result: duckdb_result
): duckdb_data_chunk {.cdecl, importc: "duckdb_fetch_chunk".}

proc duckdb_create_cast_function*(): duckdb_cast_function {.
  cdecl, importc: "duckdb_create_cast_function"
.}

proc duckdb_cast_function_set_source_type*(
  cast_function: duckdb_cast_function, source_type: duckdb_logical_type
): void {.cdecl, importc: "duckdb_cast_function_set_source_type".}

proc duckdb_cast_function_set_target_type*(
  cast_function: duckdb_cast_function, target_type: duckdb_logical_type
): void {.cdecl, importc: "duckdb_cast_function_set_target_type".}

proc duckdb_cast_function_set_implicit_cast_cost*(
  cast_function: duckdb_cast_function, cost: int64
): void {.cdecl, importc: "duckdb_cast_function_set_implicit_cast_cost".}

proc duckdb_cast_function_set_function*(
  cast_function: duckdb_cast_function, function: duckdb_cast_function_t
): void {.cdecl, importc: "duckdb_cast_function_set_function".}

proc duckdb_cast_function_set_extra_info*(
  cast_function: duckdb_cast_function,
  extra_info: pointer,
  destroy: duckdb_delete_callback_t,
): void {.cdecl, importc: "duckdb_cast_function_set_extra_info".}

proc duckdb_cast_function_get_extra_info*(
  info: duckdb_function_info
): pointer {.cdecl, importc: "duckdb_cast_function_get_extra_info".}

proc duckdb_cast_function_get_cast_mode*(
  info: duckdb_function_info
): duckdb_cast_mode {.cdecl, importc: "duckdb_cast_function_get_cast_mode".}

proc duckdb_cast_function_set_error*(
  info: duckdb_function_info, error: cstring
): void {.cdecl, importc: "duckdb_cast_function_set_error".}

proc duckdb_cast_function_set_row_error*(
  info: duckdb_function_info, error: cstring, row: idx_t, output: duckdb_vector
): void {.cdecl, importc: "duckdb_cast_function_set_row_error".}

proc duckdb_register_cast_function*(
  con: duckdb_connection, cast_function: duckdb_cast_function
): duckdb_state {.cdecl, importc: "duckdb_register_cast_function".}

proc duckdb_destroy_cast_function*(
  cast_function: ptr duckdb_cast_function
): void {.cdecl, importc: "duckdb_destroy_cast_function".}
