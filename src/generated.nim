
type
  enum_DUCKDB_TYPE* {.size: sizeof(cuint).} = enum
    DUCKDB_TYPE_INVALID = 0, DUCKDB_TYPE_BOOLEAN = 1, DUCKDB_TYPE_TINYINT = 2,
    DUCKDB_TYPE_SMALLINT = 3, DUCKDB_TYPE_INTEGER = 4, DUCKDB_TYPE_BIGINT = 5,
    DUCKDB_TYPE_UTINYINT = 6, DUCKDB_TYPE_USMALLINT = 7,
    DUCKDB_TYPE_UINTEGER = 8, DUCKDB_TYPE_UBIGINT = 9, DUCKDB_TYPE_FLOAT = 10,
    DUCKDB_TYPE_DOUBLE = 11, DUCKDB_TYPE_TIMESTAMP = 12, DUCKDB_TYPE_DATE = 13,
    DUCKDB_TYPE_TIME = 14, DUCKDB_TYPE_INTERVAL = 15, DUCKDB_TYPE_HUGEINT = 16,
    DUCKDB_TYPE_VARCHAR = 17, DUCKDB_TYPE_BLOB = 18, DUCKDB_TYPE_DECIMAL = 19,
    DUCKDB_TYPE_TIMESTAMP_S = 20, DUCKDB_TYPE_TIMESTAMP_MS = 21,
    DUCKDB_TYPE_TIMESTAMP_NS = 22, DUCKDB_TYPE_ENUM = 23, DUCKDB_TYPE_LIST = 24,
    DUCKDB_TYPE_STRUCT = 25, DUCKDB_TYPE_MAP = 26, DUCKDB_TYPE_UUID = 27,
    DUCKDB_TYPE_UNION = 28, DUCKDB_TYPE_BIT = 29, DUCKDB_TYPE_TIME_TZ = 30,
    DUCKDB_TYPE_TIMESTAMP_TZ = 31, DUCKDB_TYPE_UHUGEINT = 32,
    DUCKDB_TYPE_ARRAY = 33, DUCKDB_TYPE_ANY = 34, DUCKDB_TYPE_BIGNUM = 35,
    DUCKDB_TYPE_SQLNULL = 36, DUCKDB_TYPE_STRING_LITERAL = 37,
    DUCKDB_TYPE_INTEGER_LITERAL = 38, DUCKDB_TYPE_TIME_NS = 39,
    DUCKDB_TYPE_GEOMETRY = 40, DUCKDB_TYPE_VARIANT = 41
type
  enum_duckdb_state* {.size: sizeof(cuint).} = enum
    DuckDBSuccess = 0, DuckDBError = 1
type
  enum_duckdb_pending_state* {.size: sizeof(cuint).} = enum
    DUCKDB_PENDING_RESULT_READY = 0, DUCKDB_PENDING_RESULT_NOT_READY = 1,
    DUCKDB_PENDING_ERROR = 2, DUCKDB_PENDING_NO_TASKS_AVAILABLE = 3
type
  enum_duckdb_result_type* {.size: sizeof(cuint).} = enum
    DUCKDB_RESULT_TYPE_INVALID = 0, DUCKDB_RESULT_TYPE_CHANGED_ROWS = 1,
    DUCKDB_RESULT_TYPE_NOTHING = 2, DUCKDB_RESULT_TYPE_QUERY_RESULT = 3
type
  enum_duckdb_statement_type* {.size: sizeof(cuint).} = enum
    DUCKDB_STATEMENT_TYPE_INVALID = 0, DUCKDB_STATEMENT_TYPE_SELECT = 1,
    DUCKDB_STATEMENT_TYPE_INSERT = 2, DUCKDB_STATEMENT_TYPE_UPDATE = 3,
    DUCKDB_STATEMENT_TYPE_EXPLAIN = 4, DUCKDB_STATEMENT_TYPE_DELETE = 5,
    DUCKDB_STATEMENT_TYPE_PREPARE = 6, DUCKDB_STATEMENT_TYPE_CREATE = 7,
    DUCKDB_STATEMENT_TYPE_EXECUTE = 8, DUCKDB_STATEMENT_TYPE_ALTER = 9,
    DUCKDB_STATEMENT_TYPE_TRANSACTION = 10, DUCKDB_STATEMENT_TYPE_COPY = 11,
    DUCKDB_STATEMENT_TYPE_ANALYZE = 12, DUCKDB_STATEMENT_TYPE_VARIABLE_SET = 13,
    DUCKDB_STATEMENT_TYPE_CREATE_FUNC = 14, DUCKDB_STATEMENT_TYPE_DROP = 15,
    DUCKDB_STATEMENT_TYPE_EXPORT = 16, DUCKDB_STATEMENT_TYPE_PRAGMA = 17,
    DUCKDB_STATEMENT_TYPE_VACUUM = 18, DUCKDB_STATEMENT_TYPE_CALL = 19,
    DUCKDB_STATEMENT_TYPE_SET = 20, DUCKDB_STATEMENT_TYPE_LOAD = 21,
    DUCKDB_STATEMENT_TYPE_RELATION = 22, DUCKDB_STATEMENT_TYPE_EXTENSION = 23,
    DUCKDB_STATEMENT_TYPE_LOGICAL_PLAN = 24, DUCKDB_STATEMENT_TYPE_ATTACH = 25,
    DUCKDB_STATEMENT_TYPE_DETACH = 26, DUCKDB_STATEMENT_TYPE_MULTI = 27
type
  enum_duckdb_error_type* {.size: sizeof(cuint).} = enum
    DUCKDB_ERROR_INVALID = 0, DUCKDB_ERROR_OUT_OF_RANGE = 1,
    DUCKDB_ERROR_CONVERSION = 2, DUCKDB_ERROR_UNKNOWN_TYPE = 3,
    DUCKDB_ERROR_DECIMAL = 4, DUCKDB_ERROR_MISMATCH_TYPE = 5,
    DUCKDB_ERROR_DIVIDE_BY_ZERO = 6, DUCKDB_ERROR_OBJECT_SIZE = 7,
    DUCKDB_ERROR_INVALID_TYPE = 8, DUCKDB_ERROR_SERIALIZATION = 9,
    DUCKDB_ERROR_TRANSACTION = 10, DUCKDB_ERROR_NOT_IMPLEMENTED = 11,
    DUCKDB_ERROR_EXPRESSION = 12, DUCKDB_ERROR_CATALOG = 13,
    DUCKDB_ERROR_PARSER = 14, DUCKDB_ERROR_PLANNER = 15,
    DUCKDB_ERROR_SCHEDULER = 16, DUCKDB_ERROR_EXECUTOR = 17,
    DUCKDB_ERROR_CONSTRAINT = 18, DUCKDB_ERROR_INDEX = 19,
    DUCKDB_ERROR_STAT = 20, DUCKDB_ERROR_CONNECTION = 21,
    DUCKDB_ERROR_SYNTAX = 22, DUCKDB_ERROR_SETTINGS = 23,
    DUCKDB_ERROR_BINDER = 24, DUCKDB_ERROR_NETWORK = 25,
    DUCKDB_ERROR_OPTIMIZER = 26, DUCKDB_ERROR_NULL_POINTER = 27,
    DUCKDB_ERROR_IO = 28, DUCKDB_ERROR_INTERRUPT = 29, DUCKDB_ERROR_FATAL = 30,
    DUCKDB_ERROR_INTERNAL = 31, DUCKDB_ERROR_INVALID_INPUT = 32,
    DUCKDB_ERROR_OUT_OF_MEMORY = 33, DUCKDB_ERROR_PERMISSION = 34,
    DUCKDB_ERROR_PARAMETER_NOT_RESOLVED = 35,
    DUCKDB_ERROR_PARAMETER_NOT_ALLOWED = 36, DUCKDB_ERROR_DEPENDENCY = 37,
    DUCKDB_ERROR_HTTP = 38, DUCKDB_ERROR_MISSING_EXTENSION = 39,
    DUCKDB_ERROR_AUTOLOAD = 40, DUCKDB_ERROR_SEQUENCE = 41,
    DUCKDB_INVALID_CONFIGURATION = 42
type
  enum_duckdb_cast_mode* {.size: sizeof(cuint).} = enum
    DUCKDB_CAST_NORMAL = 0, DUCKDB_CAST_TRY = 1
type
  enum_duckdb_file_flag* {.size: sizeof(cuint).} = enum
    DUCKDB_FILE_FLAG_INVALID = 0, DUCKDB_FILE_FLAG_READ = 1,
    DUCKDB_FILE_FLAG_WRITE = 2, DUCKDB_FILE_FLAG_CREATE = 3,
    DUCKDB_FILE_FLAG_CREATE_NEW = 4, DUCKDB_FILE_FLAG_APPEND = 5
type
  enum_duckdb_config_option_scope* {.size: sizeof(cuint).} = enum
    DUCKDB_CONFIG_OPTION_SCOPE_INVALID = 0,
    DUCKDB_CONFIG_OPTION_SCOPE_LOCAL = 1,
    DUCKDB_CONFIG_OPTION_SCOPE_SESSION = 2,
    DUCKDB_CONFIG_OPTION_SCOPE_GLOBAL = 3
type
  enum_duckdb_catalog_entry_type* {.size: sizeof(cuint).} = enum
    DUCKDB_CATALOG_ENTRY_TYPE_INVALID = 0, DUCKDB_CATALOG_ENTRY_TYPE_TABLE = 1,
    DUCKDB_CATALOG_ENTRY_TYPE_SCHEMA = 2, DUCKDB_CATALOG_ENTRY_TYPE_VIEW = 3,
    DUCKDB_CATALOG_ENTRY_TYPE_INDEX = 4,
    DUCKDB_CATALOG_ENTRY_TYPE_PREPARED_STATEMENT = 5,
    DUCKDB_CATALOG_ENTRY_TYPE_SEQUENCE = 6,
    DUCKDB_CATALOG_ENTRY_TYPE_COLLATION = 7, DUCKDB_CATALOG_ENTRY_TYPE_TYPE = 8,
    DUCKDB_CATALOG_ENTRY_TYPE_DATABASE = 9
type
  compiler_WCHAR_MIN* = object
type
  compiler_U32_TYPE* = object
type
  compiler_REDIRECT* = object
type
  compiler_SWORD_TYPE* = object
type
  compiler_SLONGWORD_TYPE* = object
type
  struct_ArrowArray* = object
type
  compiler_restrict* = object
type
  typedef* = object
type
  compiler_ULONGWORD_TYPE* = object
type
  compiler_WCHAR_MAX_private* = object
type
  compiler_SQUAD_TYPE* = object
type
  compiler_REDIRECT_NTH* = object
type
  struct_ArrowSchema* = object
type
  compiler_UQUAD_TYPE* = object
type
  compiler_u_char* = uint8   ## Generated based on /usr/include/bits/types.h:31:23
  compiler_u_short* = cushort ## Generated based on /usr/include/bits/types.h:32:28
  compiler_u_int* = cuint    ## Generated based on /usr/include/bits/types.h:33:22
  compiler_u_long* = culong  ## Generated based on /usr/include/bits/types.h:34:27
  compiler_int8_t* = cschar  ## Generated based on /usr/include/bits/types.h:37:21
  compiler_uint8_t* = uint8  ## Generated based on /usr/include/bits/types.h:38:23
  compiler_int16_t* = cshort ## Generated based on /usr/include/bits/types.h:39:26
  compiler_uint16_t* = cushort ## Generated based on /usr/include/bits/types.h:40:28
  compiler_int32_t* = cint   ## Generated based on /usr/include/bits/types.h:41:20
  compiler_uint32_t* = cuint ## Generated based on /usr/include/bits/types.h:42:22
  compiler_int64_t* = clong  ## Generated based on /usr/include/bits/types.h:44:25
  compiler_uint64_t* = culong ## Generated based on /usr/include/bits/types.h:45:27
  compiler_int_least8_t* = compiler_int8_t ## Generated based on /usr/include/bits/types.h:52:18
  compiler_uint_least8_t* = compiler_uint8_t ## Generated based on /usr/include/bits/types.h:53:19
  compiler_int_least16_t* = compiler_int16_t ## Generated based on /usr/include/bits/types.h:54:19
  compiler_uint_least16_t* = compiler_uint16_t ## Generated based on /usr/include/bits/types.h:55:20
  compiler_int_least32_t* = compiler_int32_t ## Generated based on /usr/include/bits/types.h:56:19
  compiler_uint_least32_t* = compiler_uint32_t ## Generated based on /usr/include/bits/types.h:57:20
  compiler_int_least64_t* = compiler_int64_t ## Generated based on /usr/include/bits/types.h:58:19
  compiler_uint_least64_t* = compiler_uint64_t ## Generated based on /usr/include/bits/types.h:59:20
  compiler_quad_t* = clong   ## Generated based on /usr/include/bits/types.h:63:18
  compiler_u_quad_t* = culong ## Generated based on /usr/include/bits/types.h:64:27
  compiler_intmax_t* = clong ## Generated based on /usr/include/bits/types.h:72:18
  compiler_uintmax_t* = culong ## Generated based on /usr/include/bits/types.h:73:27
  compiler_dev_t* = culong   ## Generated based on /usr/include/bits/types.h:145:25
  compiler_uid_t* = cuint    ## Generated based on /usr/include/bits/types.h:146:25
  compiler_gid_t* = cuint    ## Generated based on /usr/include/bits/types.h:147:25
  compiler_ino_t* = culong   ## Generated based on /usr/include/bits/types.h:148:25
  compiler_ino64_t* = culong ## Generated based on /usr/include/bits/types.h:149:27
  compiler_mode_t* = cuint   ## Generated based on /usr/include/bits/types.h:150:26
  compiler_nlink_t* = culong ## Generated based on /usr/include/bits/types.h:151:27
  compiler_off_t* = clong    ## Generated based on /usr/include/bits/types.h:152:25
  compiler_off64_t* = clong  ## Generated based on /usr/include/bits/types.h:153:27
  compiler_pid_t* = cint     ## Generated based on /usr/include/bits/types.h:154:25
  struct_fsid_t* {.pure, inheritable, bycopy.} = object
    compiler_val*: array[2'i64, cint] ## Generated based on /usr/include/bits/types.h:155:12
  compiler_fsid_t* = struct_fsid_t ## Generated based on /usr/include/bits/types.h:155:26
  compiler_clock_t* = clong  ## Generated based on /usr/include/bits/types.h:156:27
  compiler_rlim_t* = culong  ## Generated based on /usr/include/bits/types.h:157:26
  compiler_rlim64_t* = culong ## Generated based on /usr/include/bits/types.h:158:28
  compiler_id_t* = cuint     ## Generated based on /usr/include/bits/types.h:159:24
  compiler_time_t* = clong   ## Generated based on /usr/include/bits/types.h:160:26
  compiler_useconds_t* = cuint ## Generated based on /usr/include/bits/types.h:161:30
  compiler_suseconds_t* = clong ## Generated based on /usr/include/bits/types.h:162:31
  compiler_suseconds64_t* = clong ## Generated based on /usr/include/bits/types.h:163:33
  compiler_daddr_t* = cint   ## Generated based on /usr/include/bits/types.h:165:27
  compiler_key_t* = cint     ## Generated based on /usr/include/bits/types.h:166:25
  compiler_clockid_t* = cint ## Generated based on /usr/include/bits/types.h:169:29
  compiler_timer_t* = pointer ## Generated based on /usr/include/bits/types.h:172:27
  compiler_blksize_t* = clong ## Generated based on /usr/include/bits/types.h:175:29
  compiler_blkcnt_t* = clong ## Generated based on /usr/include/bits/types.h:180:28
  compiler_blkcnt64_t* = clong ## Generated based on /usr/include/bits/types.h:181:30
  compiler_fsblkcnt_t* = culong ## Generated based on /usr/include/bits/types.h:184:30
  compiler_fsblkcnt64_t* = culong ## Generated based on /usr/include/bits/types.h:185:32
  compiler_fsfilcnt_t* = culong ## Generated based on /usr/include/bits/types.h:188:30
  compiler_fsfilcnt64_t* = culong ## Generated based on /usr/include/bits/types.h:189:32
  compiler_fsword_t* = clong ## Generated based on /usr/include/bits/types.h:192:28
  compiler_ssize_t* = clong  ## Generated based on /usr/include/bits/types.h:194:27
  compiler_syscall_slong_t* = clong ## Generated based on /usr/include/bits/types.h:197:33
  compiler_syscall_ulong_t* = culong ## Generated based on /usr/include/bits/types.h:199:33
  compiler_loff_t* = compiler_off64_t ## Generated based on /usr/include/bits/types.h:203:19
  compiler_caddr_t* = cstring ## Generated based on /usr/include/bits/types.h:204:15
  compiler_intptr_t* = clong ## Generated based on /usr/include/bits/types.h:207:25
  compiler_socklen_t* = cuint ## Generated based on /usr/include/bits/types.h:210:23
  compiler_sig_atomic_t* = cint ## Generated based on /usr/include/bits/types.h:215:13
  int8_t* = compiler_int8_t  ## Generated based on /usr/include/bits/stdint-intn.h:24:18
  int16_t* = compiler_int16_t ## Generated based on /usr/include/bits/stdint-intn.h:25:19
  int32_t* = compiler_int32_t ## Generated based on /usr/include/bits/stdint-intn.h:26:19
  int64_t* = compiler_int64_t ## Generated based on /usr/include/bits/stdint-intn.h:27:19
  uint8_t* = compiler_uint8_t ## Generated based on /usr/include/bits/stdint-uintn.h:24:19
  uint16_t* = compiler_uint16_t ## Generated based on /usr/include/bits/stdint-uintn.h:25:20
  uint32_t* = compiler_uint32_t ## Generated based on /usr/include/bits/stdint-uintn.h:26:20
  uint64_t* = compiler_uint64_t ## Generated based on /usr/include/bits/stdint-uintn.h:27:20
  int_least8_t* = compiler_int_least8_t ## Generated based on /usr/include/bits/stdint-least.h:25:24
  int_least16_t* = compiler_int_least16_t ## Generated based on /usr/include/bits/stdint-least.h:26:25
  int_least32_t* = compiler_int_least32_t ## Generated based on /usr/include/bits/stdint-least.h:27:25
  int_least64_t* = compiler_int_least64_t ## Generated based on /usr/include/bits/stdint-least.h:28:25
  uint_least8_t* = compiler_uint_least8_t ## Generated based on /usr/include/bits/stdint-least.h:31:25
  uint_least16_t* = compiler_uint_least16_t ## Generated based on /usr/include/bits/stdint-least.h:32:26
  uint_least32_t* = compiler_uint_least32_t ## Generated based on /usr/include/bits/stdint-least.h:33:26
  uint_least64_t* = compiler_uint_least64_t ## Generated based on /usr/include/bits/stdint-least.h:34:26
  int_fast8_t* = cschar      ## Generated based on /usr/include/stdint.h:51:22
  int_fast16_t* = clong      ## Generated based on /usr/include/stdint.h:53:19
  int_fast32_t* = clong      ## Generated based on /usr/include/stdint.h:54:19
  int_fast64_t* = clong      ## Generated based on /usr/include/stdint.h:55:19
  uint_fast8_t* = uint8      ## Generated based on /usr/include/stdint.h:64:24
  uint_fast16_t* = culong    ## Generated based on /usr/include/stdint.h:66:27
  uint_fast32_t* = culong    ## Generated based on /usr/include/stdint.h:67:27
  uint_fast64_t* = culong    ## Generated based on /usr/include/stdint.h:68:27
  intptr_t* = clong          ## Generated based on /usr/include/stdint.h:80:19
  uintptr_t* = culong        ## Generated based on /usr/include/stdint.h:83:27
  intmax_t* = compiler_intmax_t ## Generated based on /usr/include/stdint.h:94:21
  uintmax_t* = compiler_uintmax_t ## Generated based on /usr/include/stdint.h:95:22
  duckdb_type* = enum_DUCKDB_TYPE ## Generated based on /usr/include/duckdb.h:145:3
  duckdb_state* = enum_duckdb_state ## Generated based on /usr/include/duckdb.h:148:66
  duckdb_pending_state* = enum_duckdb_pending_state ## Generated based on /usr/include/duckdb.h:156:3
  duckdb_result_type* = enum_duckdb_result_type ## Generated based on /usr/include/duckdb.h:164:3
  duckdb_statement_type* = enum_duckdb_statement_type ## Generated based on /usr/include/duckdb.h:196:3
  duckdb_error_type* = enum_duckdb_error_type ## Generated based on /usr/include/duckdb.h:243:3
  duckdb_cast_mode* = enum_duckdb_cast_mode ## Generated based on /usr/include/duckdb.h:246:79
  duckdb_file_flag* = enum_duckdb_file_flag ## Generated based on /usr/include/duckdb.h:260:3
  duckdb_config_option_scope* = enum_duckdb_config_option_scope ## Generated based on /usr/include/duckdb.h:275:3
  duckdb_catalog_entry_type* = enum_duckdb_catalog_entry_type ## Generated based on /usr/include/duckdb.h:289:3
  idx_t* = uint64            ## Generated based on /usr/include/duckdb.h:296:18
  sel_t* = uint32            ## Generated based on /usr/include/duckdb.h:299:18
  duckdb_delete_callback_t* = proc (a0: pointer): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:303:16
  duckdb_copy_callback_t* = proc (a0: pointer): pointer {.cdecl.} ## Generated based on /usr/include/duckdb.h:306:17
  duckdb_task_state* = pointer ## Generated based on /usr/include/duckdb.h:310:15
  struct_duckdb_date* {.pure, inheritable, bycopy.} = object
    days*: int32             ## Generated based on /usr/include/duckdb.h:318:9
  duckdb_date* = struct_duckdb_date ## Generated based on /usr/include/duckdb.h:320:3
  struct_duckdb_date_struct* {.pure, inheritable, bycopy.} = object
    year*: int32             ## Generated based on /usr/include/duckdb.h:322:9
    month*: int8
    day*: int8
  duckdb_date_struct* = struct_duckdb_date_struct ## Generated based on /usr/include/duckdb.h:326:3
  struct_duckdb_time* {.pure, inheritable, bycopy.} = object
    micros*: int64           ## Generated based on /usr/include/duckdb.h:330:9
  duckdb_time* = struct_duckdb_time ## Generated based on /usr/include/duckdb.h:332:3
  struct_duckdb_time_struct* {.pure, inheritable, bycopy.} = object
    hour*: int8              ## Generated based on /usr/include/duckdb.h:334:9
    min*: int8
    sec*: int8
    micros*: int32
  duckdb_time_struct* = struct_duckdb_time_struct ## Generated based on /usr/include/duckdb.h:339:3
  struct_duckdb_time_ns* {.pure, inheritable, bycopy.} = object
    nanos*: int64            ## Generated based on /usr/include/duckdb.h:342:9
  duckdb_time_ns* = struct_duckdb_time_ns ## Generated based on /usr/include/duckdb.h:344:3
  struct_duckdb_time_tz* {.pure, inheritable, bycopy.} = object
    bits*: uint64            ## Generated based on /usr/include/duckdb.h:348:9
  duckdb_time_tz* = struct_duckdb_time_tz ## Generated based on /usr/include/duckdb.h:350:3
  struct_duckdb_time_tz_struct* {.pure, inheritable, bycopy.} = object
    time*: duckdb_time_struct ## Generated based on /usr/include/duckdb.h:352:9
    offset*: int32
  duckdb_time_tz_struct* = struct_duckdb_time_tz_struct ## Generated based on /usr/include/duckdb.h:355:3
  struct_duckdb_timestamp* {.pure, inheritable, bycopy.} = object
    micros*: int64           ## Generated based on /usr/include/duckdb.h:359:9
  duckdb_timestamp* = struct_duckdb_timestamp ## Generated based on /usr/include/duckdb.h:361:3
  struct_duckdb_timestamp_struct* {.pure, inheritable, bycopy.} = object
    date*: duckdb_date_struct ## Generated based on /usr/include/duckdb.h:363:9
    time*: duckdb_time_struct
  duckdb_timestamp_struct* = struct_duckdb_timestamp_struct ## Generated based on /usr/include/duckdb.h:366:3
  struct_duckdb_timestamp_s* {.pure, inheritable, bycopy.} = object
    seconds*: int64          ## Generated based on /usr/include/duckdb.h:369:9
  duckdb_timestamp_s* = struct_duckdb_timestamp_s ## Generated based on /usr/include/duckdb.h:371:3
  struct_duckdb_timestamp_ms* {.pure, inheritable, bycopy.} = object
    millis*: int64           ## Generated based on /usr/include/duckdb.h:374:9
  duckdb_timestamp_ms* = struct_duckdb_timestamp_ms ## Generated based on /usr/include/duckdb.h:376:3
  struct_duckdb_timestamp_ns* {.pure, inheritable, bycopy.} = object
    nanos*: int64            ## Generated based on /usr/include/duckdb.h:379:9
  duckdb_timestamp_ns* = struct_duckdb_timestamp_ns ## Generated based on /usr/include/duckdb.h:381:3
  struct_duckdb_interval* {.pure, inheritable, bycopy.} = object
    months*: int32           ## Generated based on /usr/include/duckdb.h:384:9
    days*: int32
    micros*: int64
  duckdb_interval* = struct_duckdb_interval ## Generated based on /usr/include/duckdb.h:388:3
  struct_duckdb_hugeint* {.pure, inheritable, bycopy.} = object
    lower*: uint64           ## Generated based on /usr/include/duckdb.h:393:9
    upper*: int64
  duckdb_hugeint* = struct_duckdb_hugeint ## Generated based on /usr/include/duckdb.h:396:3
  struct_duckdb_uhugeint* {.pure, inheritable, bycopy.} = object
    lower*: uint64           ## Generated based on /usr/include/duckdb.h:401:9
    upper*: uint64
  duckdb_uhugeint* = struct_duckdb_uhugeint ## Generated based on /usr/include/duckdb.h:404:3
  struct_duckdb_decimal* {.pure, inheritable, bycopy.} = object
    width*: uint8            ## Generated based on /usr/include/duckdb.h:408:9
    scale*: uint8
    value*: duckdb_hugeint
  duckdb_decimal* = struct_duckdb_decimal ## Generated based on /usr/include/duckdb.h:412:3
  struct_duckdb_query_progress_type* {.pure, inheritable, bycopy.} = object
    percentage*: cdouble     ## Generated based on /usr/include/duckdb.h:415:9
    rows_processed*: uint64
    total_rows_to_process*: uint64
  duckdb_query_progress_type* = struct_duckdb_query_progress_type ## Generated based on /usr/include/duckdb.h:419:3
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
    value*: struct_duckdb_string_t_value_t ## Generated based on /usr/include/duckdb.h:425:9
  duckdb_string_t* = struct_duckdb_string_t ## Generated based on /usr/include/duckdb.h:437:3
  struct_duckdb_list_entry* {.pure, inheritable, bycopy.} = object
    offset*: uint64          ## Generated based on /usr/include/duckdb.h:443:9
    length*: uint64
  duckdb_list_entry* = struct_duckdb_list_entry ## Generated based on /usr/include/duckdb.h:446:3
  struct_duckdb_column* {.pure, inheritable, bycopy.} = object
    deprecated_data*: pointer ## Generated based on /usr/include/duckdb.h:451:9
    deprecated_nullmask*: ptr bool
    deprecated_type*: duckdb_type
    deprecated_name*: cstring
    internal_data*: pointer
  duckdb_column* = struct_duckdb_column ## Generated based on /usr/include/duckdb.h:461:3
  struct_duckdb_vector* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:465:16
  duckdb_vector* = ptr struct_duckdb_vector ## Generated based on /usr/include/duckdb.h:467:5
  struct_duckdb_selection_vector* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:472:16
  duckdb_selection_vector* = ptr struct_duckdb_selection_vector ## Generated based on /usr/include/duckdb.h:474:5
  struct_duckdb_string* {.pure, inheritable, bycopy.} = object
    data*: cstring           ## Generated based on /usr/include/duckdb.h:482:9
    size*: idx_t
  duckdb_string* = struct_duckdb_string ## Generated based on /usr/include/duckdb.h:485:3
  struct_duckdb_blob* {.pure, inheritable, bycopy.} = object
    data*: pointer           ## Generated based on /usr/include/duckdb.h:489:9
    size*: idx_t
  duckdb_blob* = struct_duckdb_blob ## Generated based on /usr/include/duckdb.h:492:3
  struct_duckdb_bit* {.pure, inheritable, bycopy.} = object
    data*: ptr uint8         ## Generated based on /usr/include/duckdb.h:499:9
    size*: idx_t
  duckdb_bit* = struct_duckdb_bit ## Generated based on /usr/include/duckdb.h:502:3
  struct_duckdb_bignum* {.pure, inheritable, bycopy.} = object
    data*: ptr uint8         ## Generated based on /usr/include/duckdb.h:507:9
    size*: idx_t
    is_negative*: bool
  duckdb_bignum* = struct_duckdb_bignum ## Generated based on /usr/include/duckdb.h:511:3
  struct_duckdb_result* {.pure, inheritable, bycopy.} = object
    deprecated_column_count*: idx_t ## Generated based on /usr/include/duckdb.h:515:9
    deprecated_row_count*: idx_t
    deprecated_rows_changed*: idx_t
    deprecated_columns*: ptr duckdb_column
    deprecated_error_message*: cstring
    internal_data*: pointer
  duckdb_result* = struct_duckdb_result ## Generated based on /usr/include/duckdb.h:527:3
  struct_duckdb_instance_cache* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:530:16
  duckdb_instance_cache* = ptr struct_duckdb_instance_cache ## Generated based on /usr/include/duckdb.h:532:5
  struct_duckdb_database* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:535:16
  duckdb_database* = ptr struct_duckdb_database ## Generated based on /usr/include/duckdb.h:537:5
  struct_duckdb_connection* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:540:16
  duckdb_connection* = ptr struct_duckdb_connection ## Generated based on /usr/include/duckdb.h:542:5
  struct_duckdb_client_context* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:545:16
  duckdb_client_context* = ptr struct_duckdb_client_context ## Generated based on /usr/include/duckdb.h:547:5
  struct_duckdb_prepared_statement* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:551:16
  duckdb_prepared_statement* = ptr struct_duckdb_prepared_statement ## Generated based on /usr/include/duckdb.h:553:5
  struct_duckdb_extracted_statements* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:556:16
  duckdb_extracted_statements* = ptr struct_duckdb_extracted_statements ## Generated based on /usr/include/duckdb.h:558:5
  struct_duckdb_pending_result* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:562:16
  duckdb_pending_result* = ptr struct_duckdb_pending_result ## Generated based on /usr/include/duckdb.h:564:5
  struct_duckdb_appender* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:568:16
  duckdb_appender* = ptr struct_duckdb_appender ## Generated based on /usr/include/duckdb.h:570:5
  struct_duckdb_table_description* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:574:16
  duckdb_table_description* = ptr struct_duckdb_table_description ## Generated based on /usr/include/duckdb.h:576:5
  struct_duckdb_config* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:580:16
  duckdb_config* = ptr struct_duckdb_config ## Generated based on /usr/include/duckdb.h:582:5
  struct_duckdb_config_option* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:586:16
  duckdb_config_option* = ptr struct_duckdb_config_option ## Generated based on /usr/include/duckdb.h:588:5
  struct_duckdb_logical_type* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:592:16
  duckdb_logical_type* = ptr struct_duckdb_logical_type ## Generated based on /usr/include/duckdb.h:594:5
  struct_duckdb_create_type_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:598:16
  duckdb_create_type_info* = ptr struct_duckdb_create_type_info ## Generated based on /usr/include/duckdb.h:600:5
  struct_duckdb_data_chunk* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:604:16
  duckdb_data_chunk* = ptr struct_duckdb_data_chunk ## Generated based on /usr/include/duckdb.h:606:5
  struct_duckdb_value* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:610:16
  duckdb_value* = ptr struct_duckdb_value ## Generated based on /usr/include/duckdb.h:612:5
  struct_duckdb_profiling_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:616:16
  duckdb_profiling_info* = ptr struct_duckdb_profiling_info ## Generated based on /usr/include/duckdb.h:618:5
  struct_duckdb_error_data* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:622:16
  duckdb_error_data* = ptr struct_duckdb_error_data ## Generated based on /usr/include/duckdb.h:624:5
  struct_duckdb_expression* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:628:16
  duckdb_expression* = ptr struct_duckdb_expression ## Generated based on /usr/include/duckdb.h:630:5
  struct_duckdb_extension_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:637:16
  duckdb_extension_info* = ptr struct_duckdb_extension_info ## Generated based on /usr/include/duckdb.h:639:5
  struct_duckdb_function_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:647:16
  duckdb_function_info* = ptr struct_duckdb_function_info ## Generated based on /usr/include/duckdb.h:649:5
  struct_duckdb_bind_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:653:16
  duckdb_bind_info* = ptr struct_duckdb_bind_info ## Generated based on /usr/include/duckdb.h:655:5
  struct_duckdb_init_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:659:16
  duckdb_init_info* = ptr struct_duckdb_init_info ## Generated based on /usr/include/duckdb.h:661:5
  struct_duckdb_scalar_function* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:668:16
  duckdb_scalar_function* = ptr struct_duckdb_scalar_function ## Generated based on /usr/include/duckdb.h:670:5
  struct_duckdb_scalar_function_set* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:673:16
  duckdb_scalar_function_set* = ptr struct_duckdb_scalar_function_set ## Generated based on /usr/include/duckdb.h:675:5
  duckdb_scalar_function_bind_t* = proc (a0: duckdb_bind_info): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:678:16
  duckdb_scalar_function_init_t* = proc (a0: duckdb_init_info): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:681:16
  duckdb_scalar_function_t* = proc (a0: duckdb_function_info;
                                    a1: duckdb_data_chunk; a2: duckdb_vector): void {.
      cdecl.}                ## Generated based on /usr/include/duckdb.h:684:16
  struct_duckdb_aggregate_function* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:691:16
  duckdb_aggregate_function* = ptr struct_duckdb_aggregate_function ## Generated based on /usr/include/duckdb.h:693:5
  struct_duckdb_aggregate_function_set* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:696:16
  duckdb_aggregate_function_set* = ptr struct_duckdb_aggregate_function_set ## Generated based on /usr/include/duckdb.h:698:5
  struct_duckdb_aggregate_state* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:701:16
  duckdb_aggregate_state* = ptr struct_duckdb_aggregate_state ## Generated based on /usr/include/duckdb.h:703:5
  duckdb_aggregate_state_size* = proc (a0: duckdb_function_info): idx_t {.cdecl.} ## Generated based on /usr/include/duckdb.h:706:17
  duckdb_aggregate_init_t* = proc (a0: duckdb_function_info;
                                   a1: duckdb_aggregate_state): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:709:16
  duckdb_aggregate_destroy_t* = proc (a0: ptr duckdb_aggregate_state; a1: idx_t): void {.
      cdecl.}                ## Generated based on /usr/include/duckdb.h:712:16
  duckdb_aggregate_update_t* = proc (a0: duckdb_function_info;
                                     a1: duckdb_data_chunk;
                                     a2: ptr duckdb_aggregate_state): void {.
      cdecl.}                ## Generated based on /usr/include/duckdb.h:715:16
  duckdb_aggregate_combine_t* = proc (a0: duckdb_function_info;
                                      a1: ptr duckdb_aggregate_state;
                                      a2: ptr duckdb_aggregate_state; a3: idx_t): void {.
      cdecl.}                ## Generated based on /usr/include/duckdb.h:719:16
  duckdb_aggregate_finalize_t* = proc (a0: duckdb_function_info;
                                       a1: ptr duckdb_aggregate_state;
                                       a2: duckdb_vector; a3: idx_t; a4: idx_t): void {.
      cdecl.}                ## Generated based on /usr/include/duckdb.h:723:16
  struct_duckdb_table_function* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:731:16
  duckdb_table_function* = ptr struct_duckdb_table_function ## Generated based on /usr/include/duckdb.h:733:5
  duckdb_table_function_bind_t* = proc (a0: duckdb_bind_info): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:736:16
  duckdb_table_function_init_t* = proc (a0: duckdb_init_info): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:739:16
  duckdb_table_function_t* = proc (a0: duckdb_function_info;
                                   a1: duckdb_data_chunk): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:742:16
  struct_duckdb_copy_function* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:749:16
  duckdb_copy_function* = ptr struct_duckdb_copy_function ## Generated based on /usr/include/duckdb.h:751:5
  struct_duckdb_copy_function_bind_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:754:16
  duckdb_copy_function_bind_info* = ptr struct_duckdb_copy_function_bind_info ## Generated based on /usr/include/duckdb.h:756:5
  struct_duckdb_copy_function_global_init_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:759:16
  duckdb_copy_function_global_init_info* = ptr struct_duckdb_copy_function_global_init_info ## Generated based on /usr/include/duckdb.h:761:5
  struct_duckdb_copy_function_sink_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:764:16
  duckdb_copy_function_sink_info* = ptr struct_duckdb_copy_function_sink_info ## Generated based on /usr/include/duckdb.h:766:5
  struct_duckdb_copy_function_finalize_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:769:16
  duckdb_copy_function_finalize_info* = ptr struct_duckdb_copy_function_finalize_info ## Generated based on /usr/include/duckdb.h:771:5
  duckdb_copy_function_bind_t* = proc (a0: duckdb_copy_function_bind_info): void {.
      cdecl.}                ## Generated based on /usr/include/duckdb.h:774:16
  duckdb_copy_function_global_init_t* = proc (
      a0: duckdb_copy_function_global_init_info): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:777:16
  duckdb_copy_function_sink_t* = proc (a0: duckdb_copy_function_sink_info;
                                       a1: duckdb_data_chunk): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:780:16
  duckdb_copy_function_finalize_t* = proc (
      a0: duckdb_copy_function_finalize_info): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:783:16
  struct_duckdb_cast_function* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:790:16
  duckdb_cast_function* = ptr struct_duckdb_cast_function ## Generated based on /usr/include/duckdb.h:792:5
  duckdb_cast_function_t* = proc (a0: duckdb_function_info; a1: idx_t;
                                  a2: duckdb_vector; a3: duckdb_vector): bool {.
      cdecl.}                ## Generated based on /usr/include/duckdb.h:795:16
  struct_duckdb_replacement_scan_info* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:803:16
  duckdb_replacement_scan_info* = ptr struct_duckdb_replacement_scan_info ## Generated based on /usr/include/duckdb.h:805:5
  duckdb_replacement_callback_t* = proc (a0: duckdb_replacement_scan_info;
      a1: cstring; a2: pointer): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:808:16
  struct_duckdb_arrow* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:823:16
  duckdb_arrow* = ptr struct_duckdb_arrow ## Generated based on /usr/include/duckdb.h:825:5
  struct_duckdb_arrow_stream* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:828:16
  duckdb_arrow_stream* = ptr struct_duckdb_arrow_stream ## Generated based on /usr/include/duckdb.h:830:5
  struct_duckdb_arrow_schema* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:833:16
  duckdb_arrow_schema* = ptr struct_duckdb_arrow_schema ## Generated based on /usr/include/duckdb.h:835:5
  struct_duckdb_arrow_converted_schema* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:841:16
  duckdb_arrow_converted_schema* = ptr struct_duckdb_arrow_converted_schema ## Generated based on /usr/include/duckdb.h:843:5
  struct_duckdb_arrow_array* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:846:16
  duckdb_arrow_array* = ptr struct_duckdb_arrow_array ## Generated based on /usr/include/duckdb.h:848:5
  struct_duckdb_arrow_options* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:852:16
  duckdb_arrow_options* = ptr struct_duckdb_arrow_options ## Generated based on /usr/include/duckdb.h:854:5
  struct_duckdb_file_open_options* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:860:16
  duckdb_file_open_options* = ptr struct_duckdb_file_open_options ## Generated based on /usr/include/duckdb.h:862:5
  struct_duckdb_file_system* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:864:16
  duckdb_file_system* = ptr struct_duckdb_file_system ## Generated based on /usr/include/duckdb.h:866:5
  struct_duckdb_file_handle* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:868:16
  duckdb_file_handle* = ptr struct_duckdb_file_handle ## Generated based on /usr/include/duckdb.h:870:5
  struct_duckdb_catalog* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:878:16
  duckdb_catalog* = ptr struct_duckdb_catalog ## Generated based on /usr/include/duckdb.h:880:5
  struct_duckdb_catalog_entry* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:884:16
  duckdb_catalog_entry* = ptr struct_duckdb_catalog_entry ## Generated based on /usr/include/duckdb.h:886:5
  struct_duckdb_log_storage* {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer   ## Generated based on /usr/include/duckdb.h:893:16
  duckdb_log_storage* = ptr struct_duckdb_log_storage ## Generated based on /usr/include/duckdb.h:895:5
  duckdb_logger_write_log_entry_t* = proc (a0: pointer;
      a1: ptr duckdb_timestamp; a2: cstring; a3: cstring; a4: cstring): void {.
      cdecl.}                ## Generated based on /usr/include/duckdb.h:898:16
  struct_duckdb_extension_access* {.pure, inheritable, bycopy.} = object
    set_error*: proc (a0: duckdb_extension_info; a1: cstring): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:906:8
    get_database*: proc (a0: duckdb_extension_info): ptr duckdb_database {.cdecl.}
    get_api*: proc (a0: duckdb_extension_info; a1: cstring): pointer {.cdecl.}
when 1 is static:
  const
    internal_STDINT_H* = 1   ## Generated based on /usr/include/stdint.h:23:9
else:
  let internal_STDINT_H* = 1 ## Generated based on /usr/include/stdint.h:23:9
when 1 is static:
  const
    internal_FEATURES_H* = 1 ## Generated based on /usr/include/features.h:19:9
else:
  let internal_FEATURES_H* = 1 ## Generated based on /usr/include/features.h:19:9
when 1 is static:
  const
    internal_DEFAULT_SOURCE* = 1 ## Generated based on /usr/include/features.h:256:10
else:
  let internal_DEFAULT_SOURCE* = 1 ## Generated based on /usr/include/features.h:256:10
when 0 is static:
  const
    compiler_GLIBC_USE_ISOC2Y* = 0 ## Generated based on /usr/include/features.h:264:10
else:
  let compiler_GLIBC_USE_ISOC2Y* = 0 ## Generated based on /usr/include/features.h:264:10
when 0 is static:
  const
    compiler_GLIBC_USE_ISOC23* = 0 ## Generated based on /usr/include/features.h:272:10
else:
  let compiler_GLIBC_USE_ISOC23* = 0 ## Generated based on /usr/include/features.h:272:10
when 1 is static:
  const
    compiler_USE_ISOC11* = 1 ## Generated based on /usr/include/features.h:279:10
else:
  let compiler_USE_ISOC11* = 1 ## Generated based on /usr/include/features.h:279:10
when 1 is static:
  const
    compiler_USE_ISOC99* = 1 ## Generated based on /usr/include/features.h:376:10
else:
  let compiler_USE_ISOC99* = 1 ## Generated based on /usr/include/features.h:376:10
when 1 is static:
  const
    compiler_USE_ISOC95* = 1 ## Generated based on /usr/include/features.h:374:10
else:
  let compiler_USE_ISOC95* = 1 ## Generated based on /usr/include/features.h:374:10
when 1 is static:
  const
    compiler_USE_POSIX_IMPLICITLY* = 1 ## Generated based on /usr/include/features.h:314:11
else:
  let compiler_USE_POSIX_IMPLICITLY* = 1 ## Generated based on /usr/include/features.h:314:11
when 1 is static:
  const
    internal_POSIX_SOURCE* = 1 ## Generated based on /usr/include/features.h:317:10
else:
  let internal_POSIX_SOURCE* = 1 ## Generated based on /usr/include/features.h:317:10
when cast[clong](202405'i64) is static:
  const
    internal_POSIX_C_SOURCE* = cast[clong](202405'i64) ## Generated based on /usr/include/features.h:319:10
else:
  let internal_POSIX_C_SOURCE* = cast[clong](202405'i64) ## Generated based on /usr/include/features.h:319:10
when 1 is static:
  const
    compiler_USE_POSIX* = 1  ## Generated based on /usr/include/features.h:356:10
else:
  let compiler_USE_POSIX* = 1 ## Generated based on /usr/include/features.h:356:10
when 1 is static:
  const
    compiler_USE_POSIX2* = 1 ## Generated based on /usr/include/features.h:360:10
else:
  let compiler_USE_POSIX2* = 1 ## Generated based on /usr/include/features.h:360:10
when 1 is static:
  const
    compiler_USE_POSIX199309* = 1 ## Generated based on /usr/include/features.h:364:10
else:
  let compiler_USE_POSIX199309* = 1 ## Generated based on /usr/include/features.h:364:10
when 1 is static:
  const
    compiler_USE_POSIX199506* = 1 ## Generated based on /usr/include/features.h:368:10
else:
  let compiler_USE_POSIX199506* = 1 ## Generated based on /usr/include/features.h:368:10
when 1 is static:
  const
    compiler_USE_XOPEN2K* = 1 ## Generated based on /usr/include/features.h:372:10
else:
  let compiler_USE_XOPEN2K* = 1 ## Generated based on /usr/include/features.h:372:10
when 1 is static:
  const
    compiler_USE_XOPEN2K8* = 1 ## Generated based on /usr/include/features.h:380:10
else:
  let compiler_USE_XOPEN2K8* = 1 ## Generated based on /usr/include/features.h:380:10
when 1 is static:
  const
    internal_ATFILE_SOURCE* = 1 ## Generated based on /usr/include/features.h:382:10
else:
  let internal_ATFILE_SOURCE* = 1 ## Generated based on /usr/include/features.h:382:10
when 1 is static:
  const
    compiler_USE_XOPEN2K24* = 1 ## Generated based on /usr/include/features.h:386:10
else:
  let compiler_USE_XOPEN2K24* = 1 ## Generated based on /usr/include/features.h:386:10
when 64 is static:
  const
    compiler_WORDSIZE* = 64  ## Generated based on /usr/include/bits/wordsize.h:4:10
else:
  let compiler_WORDSIZE* = 64 ## Generated based on /usr/include/bits/wordsize.h:4:10
when 1 is static:
  const
    compiler_WORDSIZE_TIME64_COMPAT32* = 1 ## Generated based on /usr/include/bits/wordsize.h:11:9
else:
  let compiler_WORDSIZE_TIME64_COMPAT32* = 1 ## Generated based on /usr/include/bits/wordsize.h:11:9
when 64 is static:
  const
    compiler_SYSCALL_WORDSIZE* = 64 ## Generated based on /usr/include/bits/wordsize.h:15:10
else:
  let compiler_SYSCALL_WORDSIZE* = 64 ## Generated based on /usr/include/bits/wordsize.h:15:10
when compiler_WORDSIZE is typedesc:
  type
    compiler_TIMESIZE* = compiler_WORDSIZE ## Generated based on /usr/include/bits/timesize.h:26:10
else:
  when compiler_WORDSIZE is static:
    const
      compiler_TIMESIZE* = compiler_WORDSIZE ## Generated based on /usr/include/bits/timesize.h:26:10
  else:
    let compiler_TIMESIZE* = compiler_WORDSIZE ## Generated based on /usr/include/bits/timesize.h:26:10
when 1 is static:
  const
    compiler_USE_TIME_BITS64* = 1 ## Generated based on /usr/include/features-time64.h:37:10
else:
  let compiler_USE_TIME_BITS64* = 1 ## Generated based on /usr/include/features-time64.h:37:10
when 1 is static:
  const
    compiler_USE_MISC* = 1   ## Generated based on /usr/include/features.h:434:10
else:
  let compiler_USE_MISC* = 1 ## Generated based on /usr/include/features.h:434:10
when 1 is static:
  const
    compiler_USE_ATFILE* = 1 ## Generated based on /usr/include/features.h:438:10
else:
  let compiler_USE_ATFILE* = 1 ## Generated based on /usr/include/features.h:438:10
when 0 is static:
  const
    compiler_USE_FORTIFY_LEVEL* = 0 ## Generated based on /usr/include/features.h:471:10
else:
  let compiler_USE_FORTIFY_LEVEL* = 0 ## Generated based on /usr/include/features.h:471:10
when 0 is static:
  const
    compiler_GLIBC_USE_DEPRECATED_GETS* = 0 ## Generated based on /usr/include/features.h:479:10
else:
  let compiler_GLIBC_USE_DEPRECATED_GETS* = 0 ## Generated based on /usr/include/features.h:479:10
when 0 is static:
  const
    compiler_GLIBC_USE_DEPRECATED_SCANF* = 0 ## Generated based on /usr/include/features.h:502:10
else:
  let compiler_GLIBC_USE_DEPRECATED_SCANF* = 0 ## Generated based on /usr/include/features.h:502:10
when 0 is static:
  const
    compiler_GLIBC_USE_C23_STRTOL* = 0 ## Generated based on /usr/include/features.h:513:10
else:
  let compiler_GLIBC_USE_C23_STRTOL* = 0 ## Generated based on /usr/include/features.h:513:10
when 1 is static:
  const
    internal_STDC_PREDEF_H* = 1 ## Generated based on /usr/include/stdc-predef.h:19:9
else:
  let internal_STDC_PREDEF_H* = 1 ## Generated based on /usr/include/stdc-predef.h:19:9
when 1 is static:
  const
    compiler_STDC_IEC_559_private* = 1 ## Generated based on /usr/include/stdc-predef.h:42:10
else:
  let compiler_STDC_IEC_559_private* = 1 ## Generated based on /usr/include/stdc-predef.h:42:10
when cast[clong](201404'i64) is static:
  const
    compiler_STDC_IEC_60559_BFP_private* = cast[clong](201404'i64) ## Generated based on /usr/include/stdc-predef.h:43:10
else:
  let compiler_STDC_IEC_60559_BFP_private* = cast[clong](201404'i64) ## Generated based on /usr/include/stdc-predef.h:43:10
when 1 is static:
  const
    compiler_STDC_IEC_559_COMPLEX_private* = 1 ## Generated based on /usr/include/stdc-predef.h:52:10
else:
  let compiler_STDC_IEC_559_COMPLEX_private* = 1 ## Generated based on /usr/include/stdc-predef.h:52:10
when cast[clong](201404'i64) is static:
  const
    compiler_STDC_IEC_60559_COMPLEX_private* = cast[clong](201404'i64) ## Generated based on /usr/include/stdc-predef.h:53:10
else:
  let compiler_STDC_IEC_60559_COMPLEX_private* = cast[clong](201404'i64) ## Generated based on /usr/include/stdc-predef.h:53:10
when cast[clong](201706'i64) is static:
  const
    compiler_STDC_ISO_10646_private* = cast[clong](201706'i64) ## Generated based on /usr/include/stdc-predef.h:62:9
else:
  let compiler_STDC_ISO_10646_private* = cast[clong](201706'i64) ## Generated based on /usr/include/stdc-predef.h:62:9
when 6 is static:
  const
    compiler_GNU_LIBRARY_private* = 6 ## Generated based on /usr/include/features.h:527:9
else:
  let compiler_GNU_LIBRARY_private* = 6 ## Generated based on /usr/include/features.h:527:9
when 2 is static:
  const
    compiler_GLIBC_private* = 2 ## Generated based on /usr/include/features.h:531:9
else:
  let compiler_GLIBC_private* = 2 ## Generated based on /usr/include/features.h:531:9
when 43 is static:
  const
    compiler_GLIBC_MINOR_private* = 43 ## Generated based on /usr/include/features.h:532:9
else:
  let compiler_GLIBC_MINOR_private* = 43 ## Generated based on /usr/include/features.h:532:9
when 1 is static:
  const
    internal_SYS_CDEFS_H* = 1 ## Generated based on /usr/include/sys/cdefs.h:20:9
else:
  let internal_SYS_CDEFS_H* = 1 ## Generated based on /usr/include/sys/cdefs.h:20:9
when 1 is static:
  const
    compiler_glibc_c99_flexarr_available* = 1 ## Generated based on /usr/include/sys/cdefs.h:380:10
else:
  let compiler_glibc_c99_flexarr_available* = 1 ## Generated based on /usr/include/sys/cdefs.h:380:10
when 0 is static:
  const
    compiler_LDOUBLE_REDIRECTS_TO_FLOAT128_ABI* = 0 ## Generated based on /usr/include/bits/long-double.h:21:9
else:
  let compiler_LDOUBLE_REDIRECTS_TO_FLOAT128_ABI* = 0 ## Generated based on /usr/include/bits/long-double.h:21:9
when 1 is static:
  const
    compiler_HAVE_GENERIC_SELECTION* = 1 ## Generated based on /usr/include/sys/cdefs.h:826:10
else:
  let compiler_HAVE_GENERIC_SELECTION* = 1 ## Generated based on /usr/include/sys/cdefs.h:826:10
when 0 is static:
  const
    compiler_GLIBC_USE_LIB_EXT2* = 0 ## Generated based on /usr/include/bits/libc-header-start.h:42:10
else:
  let compiler_GLIBC_USE_LIB_EXT2* = 0 ## Generated based on /usr/include/bits/libc-header-start.h:42:10
when 0 is static:
  const
    compiler_GLIBC_USE_IEC_60559_BFP_EXT* = 0 ## Generated based on /usr/include/bits/libc-header-start.h:71:10
else:
  let compiler_GLIBC_USE_IEC_60559_BFP_EXT* = 0 ## Generated based on /usr/include/bits/libc-header-start.h:71:10
when 0 is static:
  const
    compiler_GLIBC_USE_IEC_60559_BFP_EXT_C23* = 0 ## Generated based on /usr/include/bits/libc-header-start.h:77:10
else:
  let compiler_GLIBC_USE_IEC_60559_BFP_EXT_C23* = 0 ## Generated based on /usr/include/bits/libc-header-start.h:77:10
when 0 is static:
  const
    compiler_GLIBC_USE_IEC_60559_EXT* = 0 ## Generated based on /usr/include/bits/libc-header-start.h:83:10
else:
  let compiler_GLIBC_USE_IEC_60559_EXT* = 0 ## Generated based on /usr/include/bits/libc-header-start.h:83:10
when 0 is static:
  const
    compiler_GLIBC_USE_IEC_60559_FUNCS_EXT* = 0 ## Generated based on /usr/include/bits/libc-header-start.h:94:10
else:
  let compiler_GLIBC_USE_IEC_60559_FUNCS_EXT* = 0 ## Generated based on /usr/include/bits/libc-header-start.h:94:10
when 0 is static:
  const
    compiler_GLIBC_USE_IEC_60559_FUNCS_EXT_C23* = 0 ## Generated based on /usr/include/bits/libc-header-start.h:100:10
else:
  let compiler_GLIBC_USE_IEC_60559_FUNCS_EXT_C23* = 0 ## Generated based on /usr/include/bits/libc-header-start.h:100:10
when 0 is static:
  const
    compiler_GLIBC_USE_IEC_60559_TYPES_EXT* = 0 ## Generated based on /usr/include/bits/libc-header-start.h:109:10
else:
  let compiler_GLIBC_USE_IEC_60559_TYPES_EXT* = 0 ## Generated based on /usr/include/bits/libc-header-start.h:109:10
when 1 is static:
  const
    internal_BITS_TYPES_H* = 1 ## Generated based on /usr/include/bits/types.h:24:9
else:
  let internal_BITS_TYPES_H* = 1 ## Generated based on /usr/include/bits/types.h:24:9
when int is typedesc:
  type
    compiler_S32_TYPE* = int ## Generated based on /usr/include/bits/types.h:111:9
else:
  when int is static:
    const
      compiler_S32_TYPE* = int ## Generated based on /usr/include/bits/types.h:111:9
  else:
    let compiler_S32_TYPE* = int ## Generated based on /usr/include/bits/types.h:111:9
when int is typedesc:
  type
    compiler_SLONG32_TYPE* = int ## Generated based on /usr/include/bits/types.h:132:10
else:
  when int is static:
    const
      compiler_SLONG32_TYPE* = int ## Generated based on /usr/include/bits/types.h:132:10
  else:
    let compiler_SLONG32_TYPE* = int ## Generated based on /usr/include/bits/types.h:132:10
when typedef is typedesc:
  type
    compiler_STD_TYPE* = typedef ## Generated based on /usr/include/bits/types.h:137:10
else:
  when typedef is static:
    const
      compiler_STD_TYPE* = typedef ## Generated based on /usr/include/bits/types.h:137:10
  else:
    let compiler_STD_TYPE* = typedef ## Generated based on /usr/include/bits/types.h:137:10
when 1 is static:
  const
    internal_BITS_TYPESIZES_H* = 1 ## Generated based on /usr/include/bits/typesizes.h:24:9
else:
  let internal_BITS_TYPESIZES_H* = 1 ## Generated based on /usr/include/bits/typesizes.h:24:9
when 1 is static:
  const
    compiler_OFF_T_MATCHES_OFF64_T* = 1 ## Generated based on /usr/include/bits/typesizes.h:81:10
else:
  let compiler_OFF_T_MATCHES_OFF64_T* = 1 ## Generated based on /usr/include/bits/typesizes.h:81:10
when 1 is static:
  const
    compiler_INO_T_MATCHES_INO64_T* = 1 ## Generated based on /usr/include/bits/typesizes.h:84:10
else:
  let compiler_INO_T_MATCHES_INO64_T* = 1 ## Generated based on /usr/include/bits/typesizes.h:84:10
when 1 is static:
  const
    compiler_RLIM_T_MATCHES_RLIM64_T* = 1 ## Generated based on /usr/include/bits/typesizes.h:87:10
else:
  let compiler_RLIM_T_MATCHES_RLIM64_T* = 1 ## Generated based on /usr/include/bits/typesizes.h:87:10
when 1 is static:
  const
    compiler_STATFS_MATCHES_STATFS64* = 1 ## Generated based on /usr/include/bits/typesizes.h:90:10
else:
  let compiler_STATFS_MATCHES_STATFS64* = 1 ## Generated based on /usr/include/bits/typesizes.h:90:10
when 1 is static:
  const
    compiler_KERNEL_OLD_TIMEVAL_MATCHES_TIMEVAL64* = 1 ## Generated based on /usr/include/bits/typesizes.h:93:10
else:
  let compiler_KERNEL_OLD_TIMEVAL_MATCHES_TIMEVAL64* = 1 ## Generated based on /usr/include/bits/typesizes.h:93:10
when 1024 is static:
  const
    compiler_FD_SETSIZE* = 1024 ## Generated based on /usr/include/bits/typesizes.h:103:9
else:
  let compiler_FD_SETSIZE* = 1024 ## Generated based on /usr/include/bits/typesizes.h:103:9
when 1 is static:
  const
    internal_BITS_TIME64_H* = 1 ## Generated based on /usr/include/bits/time64.h:24:9
else:
  let internal_BITS_TIME64_H* = 1 ## Generated based on /usr/include/bits/time64.h:24:9
when 1 is static:
  const
    internal_BITS_WCHAR_H* = 1 ## Generated based on /usr/include/bits/wchar.h:20:9
else:
  let internal_BITS_WCHAR_H* = 1 ## Generated based on /usr/include/bits/wchar.h:20:9
when 1 is static:
  const
    internal_BITS_STDINT_INTN_H* = 1 ## Generated based on /usr/include/bits/stdint-intn.h:20:9
else:
  let internal_BITS_STDINT_INTN_H* = 1 ## Generated based on /usr/include/bits/stdint-intn.h:20:9
when 1 is static:
  const
    internal_BITS_STDINT_UINTN_H* = 1 ## Generated based on /usr/include/bits/stdint-uintn.h:20:9
else:
  let internal_BITS_STDINT_UINTN_H* = 1 ## Generated based on /usr/include/bits/stdint-uintn.h:20:9
when 1 is static:
  const
    internal_BITS_STDINT_LEAST_H* = 1 ## Generated based on /usr/include/bits/stdint-least.h:20:9
else:
  let internal_BITS_STDINT_LEAST_H* = 1 ## Generated based on /usr/include/bits/stdint-least.h:20:9
when -128 is static:
  const
    INT8_MIN* = -128         ## Generated based on /usr/include/stdint.h:111:10
else:
  let INT8_MIN* = -128       ## Generated based on /usr/include/stdint.h:111:10
when 127 is static:
  const
    INT8_MAX* = 127          ## Generated based on /usr/include/stdint.h:116:10
else:
  let INT8_MAX* = 127        ## Generated based on /usr/include/stdint.h:116:10
when 32767 is static:
  const
    INT16_MAX* = 32767       ## Generated based on /usr/include/stdint.h:117:10
else:
  let INT16_MAX* = 32767     ## Generated based on /usr/include/stdint.h:117:10
when 2147483647 is static:
  const
    INT32_MAX* = 2147483647  ## Generated based on /usr/include/stdint.h:118:10
else:
  let INT32_MAX* = 2147483647 ## Generated based on /usr/include/stdint.h:118:10
when 255 is static:
  const
    UINT8_MAX* = 255         ## Generated based on /usr/include/stdint.h:122:10
else:
  let UINT8_MAX* = 255       ## Generated based on /usr/include/stdint.h:122:10
when 65535 is static:
  const
    UINT16_MAX* = 65535      ## Generated based on /usr/include/stdint.h:123:10
else:
  let UINT16_MAX* = 65535    ## Generated based on /usr/include/stdint.h:123:10
when cast[cuint](4294967295'i64) is static:
  const
    UINT32_MAX* = cast[cuint](4294967295'i64) ## Generated based on /usr/include/stdint.h:124:10
else:
  let UINT32_MAX* = cast[cuint](4294967295'i64) ## Generated based on /usr/include/stdint.h:124:10
when -128 is static:
  const
    INT_LEAST8_MIN* = -128   ## Generated based on /usr/include/stdint.h:129:10
else:
  let INT_LEAST8_MIN* = -128 ## Generated based on /usr/include/stdint.h:129:10
when 127 is static:
  const
    INT_LEAST8_MAX* = 127    ## Generated based on /usr/include/stdint.h:134:10
else:
  let INT_LEAST8_MAX* = 127  ## Generated based on /usr/include/stdint.h:134:10
when 32767 is static:
  const
    INT_LEAST16_MAX* = 32767 ## Generated based on /usr/include/stdint.h:135:10
else:
  let INT_LEAST16_MAX* = 32767 ## Generated based on /usr/include/stdint.h:135:10
when 2147483647 is static:
  const
    INT_LEAST32_MAX* = 2147483647 ## Generated based on /usr/include/stdint.h:136:10
else:
  let INT_LEAST32_MAX* = 2147483647 ## Generated based on /usr/include/stdint.h:136:10
when 255 is static:
  const
    UINT_LEAST8_MAX* = 255   ## Generated based on /usr/include/stdint.h:140:10
else:
  let UINT_LEAST8_MAX* = 255 ## Generated based on /usr/include/stdint.h:140:10
when 65535 is static:
  const
    UINT_LEAST16_MAX* = 65535 ## Generated based on /usr/include/stdint.h:141:10
else:
  let UINT_LEAST16_MAX* = 65535 ## Generated based on /usr/include/stdint.h:141:10
when cast[cuint](4294967295'i64) is static:
  const
    UINT_LEAST32_MAX* = cast[cuint](4294967295'i64) ## Generated based on /usr/include/stdint.h:142:10
else:
  let UINT_LEAST32_MAX* = cast[cuint](4294967295'i64) ## Generated based on /usr/include/stdint.h:142:10
when -128 is static:
  const
    INT_FAST8_MIN* = -128    ## Generated based on /usr/include/stdint.h:147:10
else:
  let INT_FAST8_MIN* = -128  ## Generated based on /usr/include/stdint.h:147:10
when 127 is static:
  const
    INT_FAST8_MAX* = 127     ## Generated based on /usr/include/stdint.h:157:10
else:
  let INT_FAST8_MAX* = 127   ## Generated based on /usr/include/stdint.h:157:10
when cast[clong](9223372036854775807'i64) is static:
  const
    INT_FAST16_MAX* = cast[clong](9223372036854775807'i64) ## Generated based on /usr/include/stdint.h:159:11
else:
  let INT_FAST16_MAX* = cast[clong](9223372036854775807'i64) ## Generated based on /usr/include/stdint.h:159:11
when cast[clong](9223372036854775807'i64) is static:
  const
    INT_FAST32_MAX* = cast[clong](9223372036854775807'i64) ## Generated based on /usr/include/stdint.h:160:11
else:
  let INT_FAST32_MAX* = cast[clong](9223372036854775807'i64) ## Generated based on /usr/include/stdint.h:160:11
when 255 is static:
  const
    UINT_FAST8_MAX* = 255    ## Generated based on /usr/include/stdint.h:168:10
else:
  let UINT_FAST8_MAX* = 255  ## Generated based on /usr/include/stdint.h:168:10
when cast[culong](18446744073709551615'u) is static:
  const
    UINT_FAST16_MAX* = cast[culong](18446744073709551615'u) ## Generated based on /usr/include/stdint.h:170:11
else:
  let UINT_FAST16_MAX* = cast[culong](18446744073709551615'u) ## Generated based on /usr/include/stdint.h:170:11
when cast[culong](18446744073709551615'u) is static:
  const
    UINT_FAST32_MAX* = cast[culong](18446744073709551615'u) ## Generated based on /usr/include/stdint.h:171:11
else:
  let UINT_FAST32_MAX* = cast[culong](18446744073709551615'u) ## Generated based on /usr/include/stdint.h:171:11
when cast[clong](9223372036854775807'i64) is static:
  const
    INTPTR_MAX* = cast[clong](9223372036854775807'i64) ## Generated based on /usr/include/stdint.h:182:11
else:
  let INTPTR_MAX* = cast[clong](9223372036854775807'i64) ## Generated based on /usr/include/stdint.h:182:11
when cast[culong](18446744073709551615'u) is static:
  const
    UINTPTR_MAX* = cast[culong](18446744073709551615'u) ## Generated based on /usr/include/stdint.h:183:11
else:
  let UINTPTR_MAX* = cast[culong](18446744073709551615'u) ## Generated based on /usr/include/stdint.h:183:11
when cast[clong](9223372036854775807'i64) is static:
  const
    PTRDIFF_MAX* = cast[clong](9223372036854775807'i64) ## Generated based on /usr/include/stdint.h:205:11
else:
  let PTRDIFF_MAX* = cast[clong](9223372036854775807'i64) ## Generated based on /usr/include/stdint.h:205:11
when 2147483647 is static:
  const
    SIG_ATOMIC_MAX* = 2147483647 ## Generated based on /usr/include/stdint.h:218:10
else:
  let SIG_ATOMIC_MAX* = 2147483647 ## Generated based on /usr/include/stdint.h:218:10
when cast[culong](18446744073709551615'u) is static:
  const
    SIZE_MAX* = cast[culong](18446744073709551615'u) ## Generated based on /usr/include/stdint.h:222:11
else:
  let SIZE_MAX* = cast[culong](18446744073709551615'u) ## Generated based on /usr/include/stdint.h:222:11
when cast[cuint](0'i64) is static:
  const
    WINT_MIN* = cast[cuint](0'i64) ## Generated based on /usr/include/stdint.h:239:10
else:
  let WINT_MIN* = cast[cuint](0'i64) ## Generated based on /usr/include/stdint.h:239:10
when cast[cuint](4294967295'i64) is static:
  const
    WINT_MAX* = cast[cuint](4294967295'i64) ## Generated based on /usr/include/stdint.h:240:10
else:
  let WINT_MAX* = cast[cuint](4294967295'i64) ## Generated based on /usr/include/stdint.h:240:10
proc duckdb_create_instance_cache*(): duckdb_instance_cache {.cdecl,
    importc: "duckdb_create_instance_cache".}
proc duckdb_get_or_create_from_cache*(instance_cache: duckdb_instance_cache;
                                      path: cstring;
                                      out_database: ptr duckdb_database;
                                      config: duckdb_config;
                                      out_error: ptr cstring): duckdb_state {.
    cdecl, importc: "duckdb_get_or_create_from_cache".}
proc duckdb_destroy_instance_cache*(instance_cache: ptr duckdb_instance_cache): void {.
    cdecl, importc: "duckdb_destroy_instance_cache".}
proc duckdb_open*(path: cstring; out_database: ptr duckdb_database): duckdb_state {.
    cdecl, importc: "duckdb_open".}
proc duckdb_open_ext*(path: cstring; out_database: ptr duckdb_database;
                      config: duckdb_config; out_error: ptr cstring): duckdb_state {.
    cdecl, importc: "duckdb_open_ext".}
proc duckdb_close*(database: ptr duckdb_database): void {.cdecl,
    importc: "duckdb_close".}
proc duckdb_connect*(database: duckdb_database;
                     out_connection: ptr duckdb_connection): duckdb_state {.
    cdecl, importc: "duckdb_connect".}
proc duckdb_interrupt*(connection: duckdb_connection): void {.cdecl,
    importc: "duckdb_interrupt".}
proc duckdb_query_progress*(connection: duckdb_connection): duckdb_query_progress_type {.
    cdecl, importc: "duckdb_query_progress".}
proc duckdb_disconnect*(connection: ptr duckdb_connection): void {.cdecl,
    importc: "duckdb_disconnect".}
proc duckdb_connection_get_client_context*(connection: duckdb_connection;
    out_context: ptr duckdb_client_context): void {.cdecl,
    importc: "duckdb_connection_get_client_context".}
proc duckdb_connection_get_arrow_options*(connection: duckdb_connection;
    out_arrow_options: ptr duckdb_arrow_options): void {.cdecl,
    importc: "duckdb_connection_get_arrow_options".}
proc duckdb_client_context_get_connection_id*(context: duckdb_client_context): idx_t {.
    cdecl, importc: "duckdb_client_context_get_connection_id".}
proc duckdb_destroy_client_context*(context: ptr duckdb_client_context): void {.
    cdecl, importc: "duckdb_destroy_client_context".}
proc duckdb_destroy_arrow_options*(arrow_options: ptr duckdb_arrow_options): void {.
    cdecl, importc: "duckdb_destroy_arrow_options".}
proc duckdb_library_version*(): cstring {.cdecl,
    importc: "duckdb_library_version".}
proc duckdb_get_table_names*(connection: duckdb_connection; query: cstring;
                             qualified: bool): duckdb_value {.cdecl,
    importc: "duckdb_get_table_names".}
proc duckdb_create_config*(out_config: ptr duckdb_config): duckdb_state {.cdecl,
    importc: "duckdb_create_config".}
proc duckdb_config_count*(): csize_t {.cdecl, importc: "duckdb_config_count".}
proc duckdb_get_config_flag*(index: csize_t; out_name: ptr cstring;
                             out_description: ptr cstring): duckdb_state {.
    cdecl, importc: "duckdb_get_config_flag".}
proc duckdb_set_config*(config: duckdb_config; name: cstring; option: cstring): duckdb_state {.
    cdecl, importc: "duckdb_set_config".}
proc duckdb_destroy_config*(config: ptr duckdb_config): void {.cdecl,
    importc: "duckdb_destroy_config".}
proc duckdb_create_error_data*(type_arg: duckdb_error_type; message: cstring): duckdb_error_data {.
    cdecl, importc: "duckdb_create_error_data".}
proc duckdb_destroy_error_data*(error_data: ptr duckdb_error_data): void {.
    cdecl, importc: "duckdb_destroy_error_data".}
proc duckdb_error_data_error_type*(error_data: duckdb_error_data): duckdb_error_type {.
    cdecl, importc: "duckdb_error_data_error_type".}
proc duckdb_error_data_message*(error_data: duckdb_error_data): cstring {.cdecl,
    importc: "duckdb_error_data_message".}
proc duckdb_error_data_has_error*(error_data: duckdb_error_data): bool {.cdecl,
    importc: "duckdb_error_data_has_error".}
proc duckdb_query*(connection: duckdb_connection; query: cstring;
                   out_result: ptr duckdb_result): duckdb_state {.cdecl,
    importc: "duckdb_query".}
proc duckdb_destroy_result*(result: ptr duckdb_result): void {.cdecl,
    importc: "duckdb_destroy_result".}
proc duckdb_column_name*(result: ptr duckdb_result; col: idx_t): cstring {.
    cdecl, importc: "duckdb_column_name".}
proc duckdb_column_type*(result: ptr duckdb_result; col: idx_t): duckdb_type {.
    cdecl, importc: "duckdb_column_type".}
proc duckdb_result_statement_type*(result: duckdb_result): duckdb_statement_type {.
    cdecl, importc: "duckdb_result_statement_type".}
proc duckdb_column_logical_type*(result: ptr duckdb_result; col: idx_t): duckdb_logical_type {.
    cdecl, importc: "duckdb_column_logical_type".}
proc duckdb_result_get_arrow_options*(result: ptr duckdb_result): duckdb_arrow_options {.
    cdecl, importc: "duckdb_result_get_arrow_options".}
proc duckdb_column_count*(result: ptr duckdb_result): idx_t {.cdecl,
    importc: "duckdb_column_count".}
proc duckdb_row_count*(result: ptr duckdb_result): idx_t {.cdecl,
    importc: "duckdb_row_count".}
proc duckdb_rows_changed*(result: ptr duckdb_result): idx_t {.cdecl,
    importc: "duckdb_rows_changed".}
proc duckdb_column_data*(result: ptr duckdb_result; col: idx_t): pointer {.
    cdecl, importc: "duckdb_column_data".}
proc duckdb_nullmask_data*(result: ptr duckdb_result; col: idx_t): ptr bool {.
    cdecl, importc: "duckdb_nullmask_data".}
proc duckdb_result_error*(result: ptr duckdb_result): cstring {.cdecl,
    importc: "duckdb_result_error".}
proc duckdb_result_error_type*(result: ptr duckdb_result): duckdb_error_type {.
    cdecl, importc: "duckdb_result_error_type".}
proc duckdb_result_get_chunk*(result: duckdb_result; chunk_index: idx_t): duckdb_data_chunk {.
    cdecl, importc: "duckdb_result_get_chunk".}
proc duckdb_result_is_streaming*(result: duckdb_result): bool {.cdecl,
    importc: "duckdb_result_is_streaming".}
proc duckdb_result_chunk_count*(result: duckdb_result): idx_t {.cdecl,
    importc: "duckdb_result_chunk_count".}
proc duckdb_result_return_type*(result: duckdb_result): duckdb_result_type {.
    cdecl, importc: "duckdb_result_return_type".}
proc duckdb_value_boolean*(result: ptr duckdb_result; col: idx_t; row: idx_t): bool {.
    cdecl, importc: "duckdb_value_boolean".}
proc duckdb_value_int8*(result: ptr duckdb_result; col: idx_t; row: idx_t): int8 {.
    cdecl, importc: "duckdb_value_int8".}
proc duckdb_value_int16*(result: ptr duckdb_result; col: idx_t; row: idx_t): int16 {.
    cdecl, importc: "duckdb_value_int16".}
proc duckdb_value_int32*(result: ptr duckdb_result; col: idx_t; row: idx_t): int32 {.
    cdecl, importc: "duckdb_value_int32".}
proc duckdb_value_int64*(result: ptr duckdb_result; col: idx_t; row: idx_t): int64 {.
    cdecl, importc: "duckdb_value_int64".}
proc duckdb_value_hugeint*(result: ptr duckdb_result; col: idx_t; row: idx_t): duckdb_hugeint {.
    cdecl, importc: "duckdb_value_hugeint".}
proc duckdb_value_uhugeint*(result: ptr duckdb_result; col: idx_t; row: idx_t): duckdb_uhugeint {.
    cdecl, importc: "duckdb_value_uhugeint".}
proc duckdb_value_decimal*(result: ptr duckdb_result; col: idx_t; row: idx_t): duckdb_decimal {.
    cdecl, importc: "duckdb_value_decimal".}
proc duckdb_value_uint8*(result: ptr duckdb_result; col: idx_t; row: idx_t): uint8 {.
    cdecl, importc: "duckdb_value_uint8".}
proc duckdb_value_uint16*(result: ptr duckdb_result; col: idx_t; row: idx_t): uint16 {.
    cdecl, importc: "duckdb_value_uint16".}
proc duckdb_value_uint32*(result: ptr duckdb_result; col: idx_t; row: idx_t): uint32 {.
    cdecl, importc: "duckdb_value_uint32".}
proc duckdb_value_uint64*(result: ptr duckdb_result; col: idx_t; row: idx_t): uint64 {.
    cdecl, importc: "duckdb_value_uint64".}
proc duckdb_value_float*(result: ptr duckdb_result; col: idx_t; row: idx_t): cfloat {.
    cdecl, importc: "duckdb_value_float".}
proc duckdb_value_double*(result: ptr duckdb_result; col: idx_t; row: idx_t): cdouble {.
    cdecl, importc: "duckdb_value_double".}
proc duckdb_value_date*(result: ptr duckdb_result; col: idx_t; row: idx_t): duckdb_date {.
    cdecl, importc: "duckdb_value_date".}
proc duckdb_value_time*(result: ptr duckdb_result; col: idx_t; row: idx_t): duckdb_time {.
    cdecl, importc: "duckdb_value_time".}
proc duckdb_value_timestamp*(result: ptr duckdb_result; col: idx_t; row: idx_t): duckdb_timestamp {.
    cdecl, importc: "duckdb_value_timestamp".}
proc duckdb_value_interval*(result: ptr duckdb_result; col: idx_t; row: idx_t): duckdb_interval {.
    cdecl, importc: "duckdb_value_interval".}
proc duckdb_value_varchar*(result: ptr duckdb_result; col: idx_t; row: idx_t): cstring {.
    cdecl, importc: "duckdb_value_varchar".}
proc duckdb_value_string*(result: ptr duckdb_result; col: idx_t; row: idx_t): duckdb_string {.
    cdecl, importc: "duckdb_value_string".}
proc duckdb_value_varchar_internal*(result: ptr duckdb_result; col: idx_t;
                                    row: idx_t): cstring {.cdecl,
    importc: "duckdb_value_varchar_internal".}
proc duckdb_value_string_internal*(result: ptr duckdb_result; col: idx_t;
                                   row: idx_t): duckdb_string {.cdecl,
    importc: "duckdb_value_string_internal".}
proc duckdb_value_blob*(result: ptr duckdb_result; col: idx_t; row: idx_t): duckdb_blob {.
    cdecl, importc: "duckdb_value_blob".}
proc duckdb_value_is_null*(result: ptr duckdb_result; col: idx_t; row: idx_t): bool {.
    cdecl, importc: "duckdb_value_is_null".}
proc duckdb_malloc*(size: csize_t): pointer {.cdecl, importc: "duckdb_malloc".}
proc duckdb_free*(ptr_arg: pointer): void {.cdecl, importc: "duckdb_free".}
proc duckdb_vector_size*(): idx_t {.cdecl, importc: "duckdb_vector_size".}
proc duckdb_string_is_inlined*(string: duckdb_string_t): bool {.cdecl,
    importc: "duckdb_string_is_inlined".}
proc duckdb_string_t_length*(string: duckdb_string_t): uint32 {.cdecl,
    importc: "duckdb_string_t_length".}
proc duckdb_string_t_data*(string: ptr duckdb_string_t): cstring {.cdecl,
    importc: "duckdb_string_t_data".}
proc duckdb_valid_utf8_check*(str: cstring; len: idx_t): duckdb_error_data {.
    cdecl, importc: "duckdb_valid_utf8_check".}
proc duckdb_from_date*(date: duckdb_date): duckdb_date_struct {.cdecl,
    importc: "duckdb_from_date".}
proc duckdb_to_date*(date: duckdb_date_struct): duckdb_date {.cdecl,
    importc: "duckdb_to_date".}
proc duckdb_is_finite_date*(date: duckdb_date): bool {.cdecl,
    importc: "duckdb_is_finite_date".}
proc duckdb_from_time*(time: duckdb_time): duckdb_time_struct {.cdecl,
    importc: "duckdb_from_time".}
proc duckdb_create_time_tz*(micros: int64; offset: int32): duckdb_time_tz {.
    cdecl, importc: "duckdb_create_time_tz".}
proc duckdb_from_time_tz*(micros: duckdb_time_tz): duckdb_time_tz_struct {.
    cdecl, importc: "duckdb_from_time_tz".}
proc duckdb_to_time*(time: duckdb_time_struct): duckdb_time {.cdecl,
    importc: "duckdb_to_time".}
proc duckdb_from_timestamp*(ts: duckdb_timestamp): duckdb_timestamp_struct {.
    cdecl, importc: "duckdb_from_timestamp".}
proc duckdb_to_timestamp*(ts: duckdb_timestamp_struct): duckdb_timestamp {.
    cdecl, importc: "duckdb_to_timestamp".}
proc duckdb_is_finite_timestamp*(ts: duckdb_timestamp): bool {.cdecl,
    importc: "duckdb_is_finite_timestamp".}
proc duckdb_is_finite_timestamp_s*(ts: duckdb_timestamp_s): bool {.cdecl,
    importc: "duckdb_is_finite_timestamp_s".}
proc duckdb_is_finite_timestamp_ms*(ts: duckdb_timestamp_ms): bool {.cdecl,
    importc: "duckdb_is_finite_timestamp_ms".}
proc duckdb_is_finite_timestamp_ns*(ts: duckdb_timestamp_ns): bool {.cdecl,
    importc: "duckdb_is_finite_timestamp_ns".}
proc duckdb_hugeint_to_double*(val: duckdb_hugeint): cdouble {.cdecl,
    importc: "duckdb_hugeint_to_double".}
proc duckdb_double_to_hugeint*(val: cdouble): duckdb_hugeint {.cdecl,
    importc: "duckdb_double_to_hugeint".}
proc duckdb_uhugeint_to_double*(val: duckdb_uhugeint): cdouble {.cdecl,
    importc: "duckdb_uhugeint_to_double".}
proc duckdb_double_to_uhugeint*(val: cdouble): duckdb_uhugeint {.cdecl,
    importc: "duckdb_double_to_uhugeint".}
proc duckdb_double_to_decimal*(val: cdouble; width: uint8; scale: uint8): duckdb_decimal {.
    cdecl, importc: "duckdb_double_to_decimal".}
proc duckdb_decimal_to_double*(val: duckdb_decimal): cdouble {.cdecl,
    importc: "duckdb_decimal_to_double".}
proc duckdb_prepare*(connection: duckdb_connection; query: cstring;
                     out_prepared_statement: ptr duckdb_prepared_statement): duckdb_state {.
    cdecl, importc: "duckdb_prepare".}
proc duckdb_destroy_prepare*(prepared_statement: ptr duckdb_prepared_statement): void {.
    cdecl, importc: "duckdb_destroy_prepare".}
proc duckdb_prepare_error*(prepared_statement: duckdb_prepared_statement): cstring {.
    cdecl, importc: "duckdb_prepare_error".}
proc duckdb_nparams*(prepared_statement: duckdb_prepared_statement): idx_t {.
    cdecl, importc: "duckdb_nparams".}
proc duckdb_parameter_name*(prepared_statement: duckdb_prepared_statement;
                            index: idx_t): cstring {.cdecl,
    importc: "duckdb_parameter_name".}
proc duckdb_param_type*(prepared_statement: duckdb_prepared_statement;
                        param_idx: idx_t): duckdb_type {.cdecl,
    importc: "duckdb_param_type".}
proc duckdb_param_logical_type*(prepared_statement: duckdb_prepared_statement;
                                param_idx: idx_t): duckdb_logical_type {.cdecl,
    importc: "duckdb_param_logical_type".}
proc duckdb_clear_bindings*(prepared_statement: duckdb_prepared_statement): duckdb_state {.
    cdecl, importc: "duckdb_clear_bindings".}
proc duckdb_prepared_statement_type*(statement: duckdb_prepared_statement): duckdb_statement_type {.
    cdecl, importc: "duckdb_prepared_statement_type".}
proc duckdb_prepared_statement_column_count*(
    prepared_statement: duckdb_prepared_statement): idx_t {.cdecl,
    importc: "duckdb_prepared_statement_column_count".}
proc duckdb_prepared_statement_column_name*(
    prepared_statement: duckdb_prepared_statement; col_idx: idx_t): cstring {.
    cdecl, importc: "duckdb_prepared_statement_column_name".}
proc duckdb_prepared_statement_column_logical_type*(
    prepared_statement: duckdb_prepared_statement; col_idx: idx_t): duckdb_logical_type {.
    cdecl, importc: "duckdb_prepared_statement_column_logical_type".}
proc duckdb_prepared_statement_column_type*(
    prepared_statement: duckdb_prepared_statement; col_idx: idx_t): duckdb_type {.
    cdecl, importc: "duckdb_prepared_statement_column_type".}
proc duckdb_bind_value*(prepared_statement: duckdb_prepared_statement;
                        param_idx: idx_t; val: duckdb_value): duckdb_state {.
    cdecl, importc: "duckdb_bind_value".}
proc duckdb_bind_parameter_index*(prepared_statement: duckdb_prepared_statement;
                                  param_idx_out: ptr idx_t; name: cstring): duckdb_state {.
    cdecl, importc: "duckdb_bind_parameter_index".}
proc duckdb_bind_boolean*(prepared_statement: duckdb_prepared_statement;
                          param_idx: idx_t; val: bool): duckdb_state {.cdecl,
    importc: "duckdb_bind_boolean".}
proc duckdb_bind_int8*(prepared_statement: duckdb_prepared_statement;
                       param_idx: idx_t; val: int8): duckdb_state {.cdecl,
    importc: "duckdb_bind_int8".}
proc duckdb_bind_int16*(prepared_statement: duckdb_prepared_statement;
                        param_idx: idx_t; val: int16): duckdb_state {.cdecl,
    importc: "duckdb_bind_int16".}
proc duckdb_bind_int32*(prepared_statement: duckdb_prepared_statement;
                        param_idx: idx_t; val: int32): duckdb_state {.cdecl,
    importc: "duckdb_bind_int32".}
proc duckdb_bind_int64*(prepared_statement: duckdb_prepared_statement;
                        param_idx: idx_t; val: int64): duckdb_state {.cdecl,
    importc: "duckdb_bind_int64".}
proc duckdb_bind_hugeint*(prepared_statement: duckdb_prepared_statement;
                          param_idx: idx_t; val: duckdb_hugeint): duckdb_state {.
    cdecl, importc: "duckdb_bind_hugeint".}
proc duckdb_bind_uhugeint*(prepared_statement: duckdb_prepared_statement;
                           param_idx: idx_t; val: duckdb_uhugeint): duckdb_state {.
    cdecl, importc: "duckdb_bind_uhugeint".}
proc duckdb_bind_decimal*(prepared_statement: duckdb_prepared_statement;
                          param_idx: idx_t; val: duckdb_decimal): duckdb_state {.
    cdecl, importc: "duckdb_bind_decimal".}
proc duckdb_bind_uint8*(prepared_statement: duckdb_prepared_statement;
                        param_idx: idx_t; val: uint8): duckdb_state {.cdecl,
    importc: "duckdb_bind_uint8".}
proc duckdb_bind_uint16*(prepared_statement: duckdb_prepared_statement;
                         param_idx: idx_t; val: uint16): duckdb_state {.cdecl,
    importc: "duckdb_bind_uint16".}
proc duckdb_bind_uint32*(prepared_statement: duckdb_prepared_statement;
                         param_idx: idx_t; val: uint32): duckdb_state {.cdecl,
    importc: "duckdb_bind_uint32".}
proc duckdb_bind_uint64*(prepared_statement: duckdb_prepared_statement;
                         param_idx: idx_t; val: uint64): duckdb_state {.cdecl,
    importc: "duckdb_bind_uint64".}
proc duckdb_bind_float*(prepared_statement: duckdb_prepared_statement;
                        param_idx: idx_t; val: cfloat): duckdb_state {.cdecl,
    importc: "duckdb_bind_float".}
proc duckdb_bind_double*(prepared_statement: duckdb_prepared_statement;
                         param_idx: idx_t; val: cdouble): duckdb_state {.cdecl,
    importc: "duckdb_bind_double".}
proc duckdb_bind_date*(prepared_statement: duckdb_prepared_statement;
                       param_idx: idx_t; val: duckdb_date): duckdb_state {.
    cdecl, importc: "duckdb_bind_date".}
proc duckdb_bind_time*(prepared_statement: duckdb_prepared_statement;
                       param_idx: idx_t; val: duckdb_time): duckdb_state {.
    cdecl, importc: "duckdb_bind_time".}
proc duckdb_bind_timestamp*(prepared_statement: duckdb_prepared_statement;
                            param_idx: idx_t; val: duckdb_timestamp): duckdb_state {.
    cdecl, importc: "duckdb_bind_timestamp".}
proc duckdb_bind_timestamp_tz*(prepared_statement: duckdb_prepared_statement;
                               param_idx: idx_t; val: duckdb_timestamp): duckdb_state {.
    cdecl, importc: "duckdb_bind_timestamp_tz".}
proc duckdb_bind_interval*(prepared_statement: duckdb_prepared_statement;
                           param_idx: idx_t; val: duckdb_interval): duckdb_state {.
    cdecl, importc: "duckdb_bind_interval".}
proc duckdb_bind_varchar*(prepared_statement: duckdb_prepared_statement;
                          param_idx: idx_t; val: cstring): duckdb_state {.cdecl,
    importc: "duckdb_bind_varchar".}
proc duckdb_bind_varchar_length*(prepared_statement: duckdb_prepared_statement;
                                 param_idx: idx_t; val: cstring; length: idx_t): duckdb_state {.
    cdecl, importc: "duckdb_bind_varchar_length".}
proc duckdb_bind_blob*(prepared_statement: duckdb_prepared_statement;
                       param_idx: idx_t; data: pointer; length: idx_t): duckdb_state {.
    cdecl, importc: "duckdb_bind_blob".}
proc duckdb_bind_null*(prepared_statement: duckdb_prepared_statement;
                       param_idx: idx_t): duckdb_state {.cdecl,
    importc: "duckdb_bind_null".}
proc duckdb_execute_prepared*(prepared_statement: duckdb_prepared_statement;
                              out_result: ptr duckdb_result): duckdb_state {.
    cdecl, importc: "duckdb_execute_prepared".}
proc duckdb_execute_prepared_streaming*(prepared_statement: duckdb_prepared_statement;
                                        out_result: ptr duckdb_result): duckdb_state {.
    cdecl, importc: "duckdb_execute_prepared_streaming".}
proc duckdb_extract_statements*(connection: duckdb_connection; query: cstring;
    out_extracted_statements: ptr duckdb_extracted_statements): idx_t {.cdecl,
    importc: "duckdb_extract_statements".}
proc duckdb_prepare_extracted_statement*(connection: duckdb_connection;
    extracted_statements: duckdb_extracted_statements; index: idx_t;
    out_prepared_statement: ptr duckdb_prepared_statement): duckdb_state {.
    cdecl, importc: "duckdb_prepare_extracted_statement".}
proc duckdb_extract_statements_error*(extracted_statements: duckdb_extracted_statements): cstring {.
    cdecl, importc: "duckdb_extract_statements_error".}
proc duckdb_destroy_extracted*(extracted_statements: ptr duckdb_extracted_statements): void {.
    cdecl, importc: "duckdb_destroy_extracted".}
proc duckdb_pending_prepared*(prepared_statement: duckdb_prepared_statement;
                              out_result: ptr duckdb_pending_result): duckdb_state {.
    cdecl, importc: "duckdb_pending_prepared".}
proc duckdb_pending_prepared_streaming*(prepared_statement: duckdb_prepared_statement;
                                        out_result: ptr duckdb_pending_result): duckdb_state {.
    cdecl, importc: "duckdb_pending_prepared_streaming".}
proc duckdb_destroy_pending*(pending_result: ptr duckdb_pending_result): void {.
    cdecl, importc: "duckdb_destroy_pending".}
proc duckdb_pending_error*(pending_result: duckdb_pending_result): cstring {.
    cdecl, importc: "duckdb_pending_error".}
proc duckdb_pending_execute_task*(pending_result: duckdb_pending_result): duckdb_pending_state {.
    cdecl, importc: "duckdb_pending_execute_task".}
proc duckdb_pending_execute_check_state*(pending_result: duckdb_pending_result): duckdb_pending_state {.
    cdecl, importc: "duckdb_pending_execute_check_state".}
proc duckdb_execute_pending*(pending_result: duckdb_pending_result;
                             out_result: ptr duckdb_result): duckdb_state {.
    cdecl, importc: "duckdb_execute_pending".}
proc duckdb_pending_execution_is_finished*(pending_state: duckdb_pending_state): bool {.
    cdecl, importc: "duckdb_pending_execution_is_finished".}
proc duckdb_destroy_value*(value: ptr duckdb_value): void {.cdecl,
    importc: "duckdb_destroy_value".}
proc duckdb_create_varchar*(text: cstring): duckdb_value {.cdecl,
    importc: "duckdb_create_varchar".}
proc duckdb_create_varchar_length*(text: cstring; length: idx_t): duckdb_value {.
    cdecl, importc: "duckdb_create_varchar_length".}
proc duckdb_create_bool*(input: bool): duckdb_value {.cdecl,
    importc: "duckdb_create_bool".}
proc duckdb_create_int8*(input: int8): duckdb_value {.cdecl,
    importc: "duckdb_create_int8".}
proc duckdb_create_uint8*(input: uint8): duckdb_value {.cdecl,
    importc: "duckdb_create_uint8".}
proc duckdb_create_int16*(input: int16): duckdb_value {.cdecl,
    importc: "duckdb_create_int16".}
proc duckdb_create_uint16*(input: uint16): duckdb_value {.cdecl,
    importc: "duckdb_create_uint16".}
proc duckdb_create_int32*(input: int32): duckdb_value {.cdecl,
    importc: "duckdb_create_int32".}
proc duckdb_create_uint32*(input: uint32): duckdb_value {.cdecl,
    importc: "duckdb_create_uint32".}
proc duckdb_create_uint64*(input: uint64): duckdb_value {.cdecl,
    importc: "duckdb_create_uint64".}
proc duckdb_create_int64*(val: int64): duckdb_value {.cdecl,
    importc: "duckdb_create_int64".}
proc duckdb_create_hugeint*(input: duckdb_hugeint): duckdb_value {.cdecl,
    importc: "duckdb_create_hugeint".}
proc duckdb_create_uhugeint*(input: duckdb_uhugeint): duckdb_value {.cdecl,
    importc: "duckdb_create_uhugeint".}
proc duckdb_create_bignum*(input: duckdb_bignum): duckdb_value {.cdecl,
    importc: "duckdb_create_bignum".}
proc duckdb_create_decimal*(input: duckdb_decimal): duckdb_value {.cdecl,
    importc: "duckdb_create_decimal".}
proc duckdb_create_float*(input: cfloat): duckdb_value {.cdecl,
    importc: "duckdb_create_float".}
proc duckdb_create_double*(input: cdouble): duckdb_value {.cdecl,
    importc: "duckdb_create_double".}
proc duckdb_create_date*(input: duckdb_date): duckdb_value {.cdecl,
    importc: "duckdb_create_date".}
proc duckdb_create_time*(input: duckdb_time): duckdb_value {.cdecl,
    importc: "duckdb_create_time".}
proc duckdb_create_time_ns*(input: duckdb_time_ns): duckdb_value {.cdecl,
    importc: "duckdb_create_time_ns".}
proc duckdb_create_time_tz_value*(value: duckdb_time_tz): duckdb_value {.cdecl,
    importc: "duckdb_create_time_tz_value".}
proc duckdb_create_timestamp*(input: duckdb_timestamp): duckdb_value {.cdecl,
    importc: "duckdb_create_timestamp".}
proc duckdb_create_timestamp_tz*(input: duckdb_timestamp): duckdb_value {.cdecl,
    importc: "duckdb_create_timestamp_tz".}
proc duckdb_create_timestamp_s*(input: duckdb_timestamp_s): duckdb_value {.
    cdecl, importc: "duckdb_create_timestamp_s".}
proc duckdb_create_timestamp_ms*(input: duckdb_timestamp_ms): duckdb_value {.
    cdecl, importc: "duckdb_create_timestamp_ms".}
proc duckdb_create_timestamp_ns*(input: duckdb_timestamp_ns): duckdb_value {.
    cdecl, importc: "duckdb_create_timestamp_ns".}
proc duckdb_create_interval*(input: duckdb_interval): duckdb_value {.cdecl,
    importc: "duckdb_create_interval".}
proc duckdb_create_blob*(data: ptr uint8; length: idx_t): duckdb_value {.cdecl,
    importc: "duckdb_create_blob".}
proc duckdb_create_bit*(input: duckdb_bit): duckdb_value {.cdecl,
    importc: "duckdb_create_bit".}
proc duckdb_create_uuid*(input: duckdb_uhugeint): duckdb_value {.cdecl,
    importc: "duckdb_create_uuid".}
proc duckdb_get_bool*(val: duckdb_value): bool {.cdecl,
    importc: "duckdb_get_bool".}
proc duckdb_get_int8*(val: duckdb_value): int8 {.cdecl,
    importc: "duckdb_get_int8".}
proc duckdb_get_uint8*(val: duckdb_value): uint8 {.cdecl,
    importc: "duckdb_get_uint8".}
proc duckdb_get_int16*(val: duckdb_value): int16 {.cdecl,
    importc: "duckdb_get_int16".}
proc duckdb_get_uint16*(val: duckdb_value): uint16 {.cdecl,
    importc: "duckdb_get_uint16".}
proc duckdb_get_int32*(val: duckdb_value): int32 {.cdecl,
    importc: "duckdb_get_int32".}
proc duckdb_get_uint32*(val: duckdb_value): uint32 {.cdecl,
    importc: "duckdb_get_uint32".}
proc duckdb_get_int64*(val: duckdb_value): int64 {.cdecl,
    importc: "duckdb_get_int64".}
proc duckdb_get_uint64*(val: duckdb_value): uint64 {.cdecl,
    importc: "duckdb_get_uint64".}
proc duckdb_get_hugeint*(val: duckdb_value): duckdb_hugeint {.cdecl,
    importc: "duckdb_get_hugeint".}
proc duckdb_get_uhugeint*(val: duckdb_value): duckdb_uhugeint {.cdecl,
    importc: "duckdb_get_uhugeint".}
proc duckdb_get_bignum*(val: duckdb_value): duckdb_bignum {.cdecl,
    importc: "duckdb_get_bignum".}
proc duckdb_get_decimal*(val: duckdb_value): duckdb_decimal {.cdecl,
    importc: "duckdb_get_decimal".}
proc duckdb_get_float*(val: duckdb_value): cfloat {.cdecl,
    importc: "duckdb_get_float".}
proc duckdb_get_double*(val: duckdb_value): cdouble {.cdecl,
    importc: "duckdb_get_double".}
proc duckdb_get_date*(val: duckdb_value): duckdb_date {.cdecl,
    importc: "duckdb_get_date".}
proc duckdb_get_time*(val: duckdb_value): duckdb_time {.cdecl,
    importc: "duckdb_get_time".}
proc duckdb_get_time_ns*(val: duckdb_value): duckdb_time_ns {.cdecl,
    importc: "duckdb_get_time_ns".}
proc duckdb_get_time_tz*(val: duckdb_value): duckdb_time_tz {.cdecl,
    importc: "duckdb_get_time_tz".}
proc duckdb_get_timestamp*(val: duckdb_value): duckdb_timestamp {.cdecl,
    importc: "duckdb_get_timestamp".}
proc duckdb_get_timestamp_tz*(val: duckdb_value): duckdb_timestamp {.cdecl,
    importc: "duckdb_get_timestamp_tz".}
proc duckdb_get_timestamp_s*(val: duckdb_value): duckdb_timestamp_s {.cdecl,
    importc: "duckdb_get_timestamp_s".}
proc duckdb_get_timestamp_ms*(val: duckdb_value): duckdb_timestamp_ms {.cdecl,
    importc: "duckdb_get_timestamp_ms".}
proc duckdb_get_timestamp_ns*(val: duckdb_value): duckdb_timestamp_ns {.cdecl,
    importc: "duckdb_get_timestamp_ns".}
proc duckdb_get_interval*(val: duckdb_value): duckdb_interval {.cdecl,
    importc: "duckdb_get_interval".}
proc duckdb_get_value_type*(val: duckdb_value): duckdb_logical_type {.cdecl,
    importc: "duckdb_get_value_type".}
proc duckdb_get_blob*(val: duckdb_value): duckdb_blob {.cdecl,
    importc: "duckdb_get_blob".}
proc duckdb_get_bit*(val: duckdb_value): duckdb_bit {.cdecl,
    importc: "duckdb_get_bit".}
proc duckdb_get_uuid*(val: duckdb_value): duckdb_uhugeint {.cdecl,
    importc: "duckdb_get_uuid".}
proc duckdb_get_varchar*(value: duckdb_value): cstring {.cdecl,
    importc: "duckdb_get_varchar".}
proc duckdb_create_struct_value*(type_arg: duckdb_logical_type;
                                 values: ptr duckdb_value): duckdb_value {.
    cdecl, importc: "duckdb_create_struct_value".}
proc duckdb_create_list_value*(type_arg: duckdb_logical_type;
                               values: ptr duckdb_value; value_count: idx_t): duckdb_value {.
    cdecl, importc: "duckdb_create_list_value".}
proc duckdb_create_array_value*(type_arg: duckdb_logical_type;
                                values: ptr duckdb_value; value_count: idx_t): duckdb_value {.
    cdecl, importc: "duckdb_create_array_value".}
proc duckdb_create_map_value*(map_type: duckdb_logical_type;
                              keys: ptr duckdb_value; values: ptr duckdb_value;
                              entry_count: idx_t): duckdb_value {.cdecl,
    importc: "duckdb_create_map_value".}
proc duckdb_create_union_value*(union_type: duckdb_logical_type;
                                tag_index: idx_t; value: duckdb_value): duckdb_value {.
    cdecl, importc: "duckdb_create_union_value".}
proc duckdb_get_map_size*(value: duckdb_value): idx_t {.cdecl,
    importc: "duckdb_get_map_size".}
proc duckdb_get_map_key*(value: duckdb_value; index: idx_t): duckdb_value {.
    cdecl, importc: "duckdb_get_map_key".}
proc duckdb_get_map_value*(value: duckdb_value; index: idx_t): duckdb_value {.
    cdecl, importc: "duckdb_get_map_value".}
proc duckdb_is_null_value*(value: duckdb_value): bool {.cdecl,
    importc: "duckdb_is_null_value".}
proc duckdb_create_null_value*(): duckdb_value {.cdecl,
    importc: "duckdb_create_null_value".}
proc duckdb_get_list_size*(value: duckdb_value): idx_t {.cdecl,
    importc: "duckdb_get_list_size".}
proc duckdb_get_list_child*(value: duckdb_value; index: idx_t): duckdb_value {.
    cdecl, importc: "duckdb_get_list_child".}
proc duckdb_create_enum_value*(type_arg: duckdb_logical_type; value: uint64): duckdb_value {.
    cdecl, importc: "duckdb_create_enum_value".}
proc duckdb_get_enum_value*(value: duckdb_value): uint64 {.cdecl,
    importc: "duckdb_get_enum_value".}
proc duckdb_get_struct_child*(value: duckdb_value; index: idx_t): duckdb_value {.
    cdecl, importc: "duckdb_get_struct_child".}
proc duckdb_value_to_string*(value: duckdb_value): cstring {.cdecl,
    importc: "duckdb_value_to_string".}
proc duckdb_create_logical_type*(type_arg: duckdb_type): duckdb_logical_type {.
    cdecl, importc: "duckdb_create_logical_type".}
proc duckdb_logical_type_get_alias*(type_arg: duckdb_logical_type): cstring {.
    cdecl, importc: "duckdb_logical_type_get_alias".}
proc duckdb_logical_type_set_alias*(type_arg: duckdb_logical_type;
                                    alias: cstring): void {.cdecl,
    importc: "duckdb_logical_type_set_alias".}
proc duckdb_create_list_type*(type_arg: duckdb_logical_type): duckdb_logical_type {.
    cdecl, importc: "duckdb_create_list_type".}
proc duckdb_create_array_type*(type_arg: duckdb_logical_type; array_size: idx_t): duckdb_logical_type {.
    cdecl, importc: "duckdb_create_array_type".}
proc duckdb_create_map_type*(key_type: duckdb_logical_type;
                             value_type: duckdb_logical_type): duckdb_logical_type {.
    cdecl, importc: "duckdb_create_map_type".}
proc duckdb_create_union_type*(member_types: ptr duckdb_logical_type;
                               member_names: ptr cstring; member_count: idx_t): duckdb_logical_type {.
    cdecl, importc: "duckdb_create_union_type".}
proc duckdb_create_struct_type*(member_types: ptr duckdb_logical_type;
                                member_names: ptr cstring; member_count: idx_t): duckdb_logical_type {.
    cdecl, importc: "duckdb_create_struct_type".}
proc duckdb_create_enum_type*(member_names: ptr cstring; member_count: idx_t): duckdb_logical_type {.
    cdecl, importc: "duckdb_create_enum_type".}
proc duckdb_create_decimal_type*(width: uint8; scale: uint8): duckdb_logical_type {.
    cdecl, importc: "duckdb_create_decimal_type".}
proc duckdb_get_type_id*(type_arg: duckdb_logical_type): duckdb_type {.cdecl,
    importc: "duckdb_get_type_id".}
proc duckdb_decimal_width*(type_arg: duckdb_logical_type): uint8 {.cdecl,
    importc: "duckdb_decimal_width".}
proc duckdb_decimal_scale*(type_arg: duckdb_logical_type): uint8 {.cdecl,
    importc: "duckdb_decimal_scale".}
proc duckdb_decimal_internal_type*(type_arg: duckdb_logical_type): duckdb_type {.
    cdecl, importc: "duckdb_decimal_internal_type".}
proc duckdb_enum_internal_type*(type_arg: duckdb_logical_type): duckdb_type {.
    cdecl, importc: "duckdb_enum_internal_type".}
proc duckdb_enum_dictionary_size*(type_arg: duckdb_logical_type): uint32 {.
    cdecl, importc: "duckdb_enum_dictionary_size".}
proc duckdb_enum_dictionary_value*(type_arg: duckdb_logical_type; index: idx_t): cstring {.
    cdecl, importc: "duckdb_enum_dictionary_value".}
proc duckdb_list_type_child_type*(type_arg: duckdb_logical_type): duckdb_logical_type {.
    cdecl, importc: "duckdb_list_type_child_type".}
proc duckdb_array_type_child_type*(type_arg: duckdb_logical_type): duckdb_logical_type {.
    cdecl, importc: "duckdb_array_type_child_type".}
proc duckdb_array_type_array_size*(type_arg: duckdb_logical_type): idx_t {.
    cdecl, importc: "duckdb_array_type_array_size".}
proc duckdb_map_type_key_type*(type_arg: duckdb_logical_type): duckdb_logical_type {.
    cdecl, importc: "duckdb_map_type_key_type".}
proc duckdb_map_type_value_type*(type_arg: duckdb_logical_type): duckdb_logical_type {.
    cdecl, importc: "duckdb_map_type_value_type".}
proc duckdb_struct_type_child_count*(type_arg: duckdb_logical_type): idx_t {.
    cdecl, importc: "duckdb_struct_type_child_count".}
proc duckdb_struct_type_child_name*(type_arg: duckdb_logical_type; index: idx_t): cstring {.
    cdecl, importc: "duckdb_struct_type_child_name".}
proc duckdb_struct_type_child_type*(type_arg: duckdb_logical_type; index: idx_t): duckdb_logical_type {.
    cdecl, importc: "duckdb_struct_type_child_type".}
proc duckdb_union_type_member_count*(type_arg: duckdb_logical_type): idx_t {.
    cdecl, importc: "duckdb_union_type_member_count".}
proc duckdb_union_type_member_name*(type_arg: duckdb_logical_type; index: idx_t): cstring {.
    cdecl, importc: "duckdb_union_type_member_name".}
proc duckdb_union_type_member_type*(type_arg: duckdb_logical_type; index: idx_t): duckdb_logical_type {.
    cdecl, importc: "duckdb_union_type_member_type".}
proc duckdb_destroy_logical_type*(type_arg: ptr duckdb_logical_type): void {.
    cdecl, importc: "duckdb_destroy_logical_type".}
proc duckdb_register_logical_type*(con: duckdb_connection;
                                   type_arg: duckdb_logical_type;
                                   info: duckdb_create_type_info): duckdb_state {.
    cdecl, importc: "duckdb_register_logical_type".}
proc duckdb_create_data_chunk*(types: ptr duckdb_logical_type;
                               column_count: idx_t): duckdb_data_chunk {.cdecl,
    importc: "duckdb_create_data_chunk".}
proc duckdb_destroy_data_chunk*(chunk: ptr duckdb_data_chunk): void {.cdecl,
    importc: "duckdb_destroy_data_chunk".}
proc duckdb_data_chunk_reset*(chunk: duckdb_data_chunk): void {.cdecl,
    importc: "duckdb_data_chunk_reset".}
proc duckdb_data_chunk_get_column_count*(chunk: duckdb_data_chunk): idx_t {.
    cdecl, importc: "duckdb_data_chunk_get_column_count".}
proc duckdb_data_chunk_get_vector*(chunk: duckdb_data_chunk; col_idx: idx_t): duckdb_vector {.
    cdecl, importc: "duckdb_data_chunk_get_vector".}
proc duckdb_data_chunk_get_size*(chunk: duckdb_data_chunk): idx_t {.cdecl,
    importc: "duckdb_data_chunk_get_size".}
proc duckdb_data_chunk_set_size*(chunk: duckdb_data_chunk; size: idx_t): void {.
    cdecl, importc: "duckdb_data_chunk_set_size".}
proc duckdb_create_vector*(type_arg: duckdb_logical_type; capacity: idx_t): duckdb_vector {.
    cdecl, importc: "duckdb_create_vector".}
proc duckdb_destroy_vector*(vector: ptr duckdb_vector): void {.cdecl,
    importc: "duckdb_destroy_vector".}
proc duckdb_vector_get_column_type*(vector: duckdb_vector): duckdb_logical_type {.
    cdecl, importc: "duckdb_vector_get_column_type".}
proc duckdb_vector_get_data*(vector: duckdb_vector): pointer {.cdecl,
    importc: "duckdb_vector_get_data".}
proc duckdb_vector_get_validity*(vector: duckdb_vector): ptr uint64 {.cdecl,
    importc: "duckdb_vector_get_validity".}
proc duckdb_vector_ensure_validity_writable*(vector: duckdb_vector): void {.
    cdecl, importc: "duckdb_vector_ensure_validity_writable".}
proc duckdb_vector_assign_string_element*(vector: duckdb_vector; index: idx_t;
    str: cstring): void {.cdecl, importc: "duckdb_vector_assign_string_element".}
proc duckdb_vector_assign_string_element_len*(vector: duckdb_vector;
    index: idx_t; str: cstring; str_len: idx_t): void {.cdecl,
    importc: "duckdb_vector_assign_string_element_len".}
proc duckdb_unsafe_vector_assign_string_element_len*(vector: duckdb_vector;
    index: idx_t; str: cstring; str_len: idx_t): void {.cdecl,
    importc: "duckdb_unsafe_vector_assign_string_element_len".}
proc duckdb_list_vector_get_child*(vector: duckdb_vector): duckdb_vector {.
    cdecl, importc: "duckdb_list_vector_get_child".}
proc duckdb_list_vector_get_size*(vector: duckdb_vector): idx_t {.cdecl,
    importc: "duckdb_list_vector_get_size".}
proc duckdb_list_vector_set_size*(vector: duckdb_vector; size: idx_t): duckdb_state {.
    cdecl, importc: "duckdb_list_vector_set_size".}
proc duckdb_list_vector_reserve*(vector: duckdb_vector; required_capacity: idx_t): duckdb_state {.
    cdecl, importc: "duckdb_list_vector_reserve".}
proc duckdb_struct_vector_get_child*(vector: duckdb_vector; index: idx_t): duckdb_vector {.
    cdecl, importc: "duckdb_struct_vector_get_child".}
proc duckdb_array_vector_get_child*(vector: duckdb_vector): duckdb_vector {.
    cdecl, importc: "duckdb_array_vector_get_child".}
proc duckdb_slice_vector*(vector: duckdb_vector; sel: duckdb_selection_vector;
                          len: idx_t): void {.cdecl,
    importc: "duckdb_slice_vector".}
proc duckdb_vector_copy_sel*(src: duckdb_vector; dst: duckdb_vector;
                             sel: duckdb_selection_vector; src_count: idx_t;
                             src_offset: idx_t; dst_offset: idx_t): void {.
    cdecl, importc: "duckdb_vector_copy_sel".}
proc duckdb_vector_reference_value*(vector: duckdb_vector; value: duckdb_value): void {.
    cdecl, importc: "duckdb_vector_reference_value".}
proc duckdb_vector_reference_vector*(to_vector: duckdb_vector;
                                     from_vector: duckdb_vector): void {.cdecl,
    importc: "duckdb_vector_reference_vector".}
proc duckdb_validity_row_is_valid*(validity: ptr uint64; row: idx_t): bool {.
    cdecl, importc: "duckdb_validity_row_is_valid".}
proc duckdb_validity_set_row_validity*(validity: ptr uint64; row: idx_t;
                                       valid: bool): void {.cdecl,
    importc: "duckdb_validity_set_row_validity".}
proc duckdb_validity_set_row_invalid*(validity: ptr uint64; row: idx_t): void {.
    cdecl, importc: "duckdb_validity_set_row_invalid".}
proc duckdb_validity_set_row_valid*(validity: ptr uint64; row: idx_t): void {.
    cdecl, importc: "duckdb_validity_set_row_valid".}
proc duckdb_create_scalar_function*(): duckdb_scalar_function {.cdecl,
    importc: "duckdb_create_scalar_function".}
proc duckdb_destroy_scalar_function*(scalar_function: ptr duckdb_scalar_function): void {.
    cdecl, importc: "duckdb_destroy_scalar_function".}
proc duckdb_scalar_function_set_name*(scalar_function: duckdb_scalar_function;
                                      name: cstring): void {.cdecl,
    importc: "duckdb_scalar_function_set_name".}
proc duckdb_scalar_function_set_varargs*(
    scalar_function: duckdb_scalar_function; type_arg: duckdb_logical_type): void {.
    cdecl, importc: "duckdb_scalar_function_set_varargs".}
proc duckdb_scalar_function_set_special_handling*(
    scalar_function: duckdb_scalar_function): void {.cdecl,
    importc: "duckdb_scalar_function_set_special_handling".}
proc duckdb_scalar_function_set_volatile*(
    scalar_function: duckdb_scalar_function): void {.cdecl,
    importc: "duckdb_scalar_function_set_volatile".}
proc duckdb_scalar_function_add_parameter*(
    scalar_function: duckdb_scalar_function; type_arg: duckdb_logical_type): void {.
    cdecl, importc: "duckdb_scalar_function_add_parameter".}
proc duckdb_scalar_function_set_return_type*(
    scalar_function: duckdb_scalar_function; type_arg: duckdb_logical_type): void {.
    cdecl, importc: "duckdb_scalar_function_set_return_type".}
proc duckdb_scalar_function_set_extra_info*(
    scalar_function: duckdb_scalar_function; extra_info: pointer;
    destroy: duckdb_delete_callback_t): void {.cdecl,
    importc: "duckdb_scalar_function_set_extra_info".}
proc duckdb_scalar_function_set_bind*(scalar_function: duckdb_scalar_function;
                                      bind_arg: duckdb_scalar_function_bind_t): void {.
    cdecl, importc: "duckdb_scalar_function_set_bind".}
proc duckdb_scalar_function_set_bind_data*(info: duckdb_bind_info;
    bind_data: pointer; destroy: duckdb_delete_callback_t): void {.cdecl,
    importc: "duckdb_scalar_function_set_bind_data".}
proc duckdb_scalar_function_set_bind_data_copy*(info: duckdb_bind_info;
    copy: duckdb_copy_callback_t): void {.cdecl,
    importc: "duckdb_scalar_function_set_bind_data_copy".}
proc duckdb_scalar_function_bind_set_error*(info: duckdb_bind_info;
    error: cstring): void {.cdecl,
                            importc: "duckdb_scalar_function_bind_set_error".}
proc duckdb_scalar_function_set_function*(
    scalar_function: duckdb_scalar_function; function: duckdb_scalar_function_t): void {.
    cdecl, importc: "duckdb_scalar_function_set_function".}
proc duckdb_register_scalar_function*(con: duckdb_connection;
                                      scalar_function: duckdb_scalar_function): duckdb_state {.
    cdecl, importc: "duckdb_register_scalar_function".}
proc duckdb_scalar_function_get_extra_info*(info: duckdb_function_info): pointer {.
    cdecl, importc: "duckdb_scalar_function_get_extra_info".}
proc duckdb_scalar_function_bind_get_extra_info*(info: duckdb_bind_info): pointer {.
    cdecl, importc: "duckdb_scalar_function_bind_get_extra_info".}
proc duckdb_scalar_function_get_bind_data*(info: duckdb_function_info): pointer {.
    cdecl, importc: "duckdb_scalar_function_get_bind_data".}
proc duckdb_scalar_function_get_client_context*(info: duckdb_bind_info;
    out_context: ptr duckdb_client_context): void {.cdecl,
    importc: "duckdb_scalar_function_get_client_context".}
proc duckdb_scalar_function_set_error*(info: duckdb_function_info;
                                       error: cstring): void {.cdecl,
    importc: "duckdb_scalar_function_set_error".}
proc duckdb_create_scalar_function_set*(name: cstring): duckdb_scalar_function_set {.
    cdecl, importc: "duckdb_create_scalar_function_set".}
proc duckdb_destroy_scalar_function_set*(
    scalar_function_set: ptr duckdb_scalar_function_set): void {.cdecl,
    importc: "duckdb_destroy_scalar_function_set".}
proc duckdb_add_scalar_function_to_set*(set: duckdb_scalar_function_set;
                                        function: duckdb_scalar_function): duckdb_state {.
    cdecl, importc: "duckdb_add_scalar_function_to_set".}
proc duckdb_register_scalar_function_set*(con: duckdb_connection;
    set: duckdb_scalar_function_set): duckdb_state {.cdecl,
    importc: "duckdb_register_scalar_function_set".}
proc duckdb_scalar_function_bind_get_argument_count*(info: duckdb_bind_info): idx_t {.
    cdecl, importc: "duckdb_scalar_function_bind_get_argument_count".}
proc duckdb_scalar_function_bind_get_argument*(info: duckdb_bind_info;
    index: idx_t): duckdb_expression {.cdecl, importc: "duckdb_scalar_function_bind_get_argument".}
proc duckdb_scalar_function_get_state*(info: duckdb_function_info): pointer {.
    cdecl, importc: "duckdb_scalar_function_get_state".}
proc duckdb_scalar_function_set_init*(scalar_function: duckdb_scalar_function;
                                      init: duckdb_scalar_function_init_t): void {.
    cdecl, importc: "duckdb_scalar_function_set_init".}
proc duckdb_scalar_function_init_set_error*(info: duckdb_init_info;
    error: cstring): void {.cdecl,
                            importc: "duckdb_scalar_function_init_set_error".}
proc duckdb_scalar_function_init_set_state*(info: duckdb_init_info;
    state: pointer; destroy: duckdb_delete_callback_t): void {.cdecl,
    importc: "duckdb_scalar_function_init_set_state".}
proc duckdb_scalar_function_init_get_client_context*(info: duckdb_init_info;
    out_context: ptr duckdb_client_context): void {.cdecl,
    importc: "duckdb_scalar_function_init_get_client_context".}
proc duckdb_scalar_function_init_get_bind_data*(info: duckdb_init_info): pointer {.
    cdecl, importc: "duckdb_scalar_function_init_get_bind_data".}
proc duckdb_scalar_function_init_get_extra_info*(info: duckdb_init_info): pointer {.
    cdecl, importc: "duckdb_scalar_function_init_get_extra_info".}
proc duckdb_create_selection_vector*(size: idx_t): duckdb_selection_vector {.
    cdecl, importc: "duckdb_create_selection_vector".}
proc duckdb_destroy_selection_vector*(sel: duckdb_selection_vector): void {.
    cdecl, importc: "duckdb_destroy_selection_vector".}
proc duckdb_selection_vector_get_data_ptr*(sel: duckdb_selection_vector): ptr sel_t {.
    cdecl, importc: "duckdb_selection_vector_get_data_ptr".}
proc duckdb_create_aggregate_function*(): duckdb_aggregate_function {.cdecl,
    importc: "duckdb_create_aggregate_function".}
proc duckdb_destroy_aggregate_function*(aggregate_function: ptr duckdb_aggregate_function): void {.
    cdecl, importc: "duckdb_destroy_aggregate_function".}
proc duckdb_aggregate_function_set_name*(
    aggregate_function: duckdb_aggregate_function; name: cstring): void {.cdecl,
    importc: "duckdb_aggregate_function_set_name".}
proc duckdb_aggregate_function_add_parameter*(
    aggregate_function: duckdb_aggregate_function; type_arg: duckdb_logical_type): void {.
    cdecl, importc: "duckdb_aggregate_function_add_parameter".}
proc duckdb_aggregate_function_set_return_type*(
    aggregate_function: duckdb_aggregate_function; type_arg: duckdb_logical_type): void {.
    cdecl, importc: "duckdb_aggregate_function_set_return_type".}
proc duckdb_aggregate_function_set_functions*(
    aggregate_function: duckdb_aggregate_function;
    state_size: duckdb_aggregate_state_size;
    state_init: duckdb_aggregate_init_t; update: duckdb_aggregate_update_t;
    combine: duckdb_aggregate_combine_t; finalize: duckdb_aggregate_finalize_t): void {.
    cdecl, importc: "duckdb_aggregate_function_set_functions".}
proc duckdb_aggregate_function_set_destructor*(
    aggregate_function: duckdb_aggregate_function;
    destroy: duckdb_aggregate_destroy_t): void {.cdecl,
    importc: "duckdb_aggregate_function_set_destructor".}
proc duckdb_register_aggregate_function*(con: duckdb_connection;
    aggregate_function: duckdb_aggregate_function): duckdb_state {.cdecl,
    importc: "duckdb_register_aggregate_function".}
proc duckdb_aggregate_function_set_special_handling*(
    aggregate_function: duckdb_aggregate_function): void {.cdecl,
    importc: "duckdb_aggregate_function_set_special_handling".}
proc duckdb_aggregate_function_set_extra_info*(
    aggregate_function: duckdb_aggregate_function; extra_info: pointer;
    destroy: duckdb_delete_callback_t): void {.cdecl,
    importc: "duckdb_aggregate_function_set_extra_info".}
proc duckdb_aggregate_function_get_extra_info*(info: duckdb_function_info): pointer {.
    cdecl, importc: "duckdb_aggregate_function_get_extra_info".}
proc duckdb_aggregate_function_set_error*(info: duckdb_function_info;
    error: cstring): void {.cdecl,
                            importc: "duckdb_aggregate_function_set_error".}
proc duckdb_create_aggregate_function_set*(name: cstring): duckdb_aggregate_function_set {.
    cdecl, importc: "duckdb_create_aggregate_function_set".}
proc duckdb_destroy_aggregate_function_set*(
    aggregate_function_set: ptr duckdb_aggregate_function_set): void {.cdecl,
    importc: "duckdb_destroy_aggregate_function_set".}
proc duckdb_add_aggregate_function_to_set*(set: duckdb_aggregate_function_set;
    function: duckdb_aggregate_function): duckdb_state {.cdecl,
    importc: "duckdb_add_aggregate_function_to_set".}
proc duckdb_register_aggregate_function_set*(con: duckdb_connection;
    set: duckdb_aggregate_function_set): duckdb_state {.cdecl,
    importc: "duckdb_register_aggregate_function_set".}
proc duckdb_create_table_function*(): duckdb_table_function {.cdecl,
    importc: "duckdb_create_table_function".}
proc duckdb_destroy_table_function*(table_function: ptr duckdb_table_function): void {.
    cdecl, importc: "duckdb_destroy_table_function".}
proc duckdb_table_function_set_name*(table_function: duckdb_table_function;
                                     name: cstring): void {.cdecl,
    importc: "duckdb_table_function_set_name".}
proc duckdb_table_function_add_parameter*(table_function: duckdb_table_function;
    type_arg: duckdb_logical_type): void {.cdecl,
    importc: "duckdb_table_function_add_parameter".}
proc duckdb_table_function_add_named_parameter*(
    table_function: duckdb_table_function; name: cstring;
    type_arg: duckdb_logical_type): void {.cdecl,
    importc: "duckdb_table_function_add_named_parameter".}
proc duckdb_table_function_set_extra_info*(
    table_function: duckdb_table_function; extra_info: pointer;
    destroy: duckdb_delete_callback_t): void {.cdecl,
    importc: "duckdb_table_function_set_extra_info".}
proc duckdb_table_function_set_bind*(table_function: duckdb_table_function;
                                     bind_arg: duckdb_table_function_bind_t): void {.
    cdecl, importc: "duckdb_table_function_set_bind".}
proc duckdb_table_function_set_init*(table_function: duckdb_table_function;
                                     init: duckdb_table_function_init_t): void {.
    cdecl, importc: "duckdb_table_function_set_init".}
proc duckdb_table_function_set_local_init*(
    table_function: duckdb_table_function; init: duckdb_table_function_init_t): void {.
    cdecl, importc: "duckdb_table_function_set_local_init".}
proc duckdb_table_function_set_function*(table_function: duckdb_table_function;
    function: duckdb_table_function_t): void {.cdecl,
    importc: "duckdb_table_function_set_function".}
proc duckdb_table_function_supports_projection_pushdown*(
    table_function: duckdb_table_function; pushdown: bool): void {.cdecl,
    importc: "duckdb_table_function_supports_projection_pushdown".}
proc duckdb_register_table_function*(con: duckdb_connection;
                                     function: duckdb_table_function): duckdb_state {.
    cdecl, importc: "duckdb_register_table_function".}
proc duckdb_bind_get_extra_info*(info: duckdb_bind_info): pointer {.cdecl,
    importc: "duckdb_bind_get_extra_info".}
proc duckdb_table_function_get_client_context*(info: duckdb_bind_info;
    out_context: ptr duckdb_client_context): void {.cdecl,
    importc: "duckdb_table_function_get_client_context".}
proc duckdb_bind_add_result_column*(info: duckdb_bind_info; name: cstring;
                                    type_arg: duckdb_logical_type): void {.
    cdecl, importc: "duckdb_bind_add_result_column".}
proc duckdb_bind_get_parameter_count*(info: duckdb_bind_info): idx_t {.cdecl,
    importc: "duckdb_bind_get_parameter_count".}
proc duckdb_bind_get_parameter*(info: duckdb_bind_info; index: idx_t): duckdb_value {.
    cdecl, importc: "duckdb_bind_get_parameter".}
proc duckdb_bind_get_named_parameter*(info: duckdb_bind_info; name: cstring): duckdb_value {.
    cdecl, importc: "duckdb_bind_get_named_parameter".}
proc duckdb_bind_set_bind_data*(info: duckdb_bind_info; bind_data: pointer;
                                destroy: duckdb_delete_callback_t): void {.
    cdecl, importc: "duckdb_bind_set_bind_data".}
proc duckdb_bind_set_cardinality*(info: duckdb_bind_info; cardinality: idx_t;
                                  is_exact: bool): void {.cdecl,
    importc: "duckdb_bind_set_cardinality".}
proc duckdb_bind_set_error*(info: duckdb_bind_info; error: cstring): void {.
    cdecl, importc: "duckdb_bind_set_error".}
proc duckdb_init_get_extra_info*(info: duckdb_init_info): pointer {.cdecl,
    importc: "duckdb_init_get_extra_info".}
proc duckdb_init_get_bind_data*(info: duckdb_init_info): pointer {.cdecl,
    importc: "duckdb_init_get_bind_data".}
proc duckdb_init_set_init_data*(info: duckdb_init_info; init_data: pointer;
                                destroy: duckdb_delete_callback_t): void {.
    cdecl, importc: "duckdb_init_set_init_data".}
proc duckdb_init_get_column_count*(info: duckdb_init_info): idx_t {.cdecl,
    importc: "duckdb_init_get_column_count".}
proc duckdb_init_get_column_index*(info: duckdb_init_info; column_index: idx_t): idx_t {.
    cdecl, importc: "duckdb_init_get_column_index".}
proc duckdb_init_set_max_threads*(info: duckdb_init_info; max_threads: idx_t): void {.
    cdecl, importc: "duckdb_init_set_max_threads".}
proc duckdb_init_set_error*(info: duckdb_init_info; error: cstring): void {.
    cdecl, importc: "duckdb_init_set_error".}
proc duckdb_function_get_extra_info*(info: duckdb_function_info): pointer {.
    cdecl, importc: "duckdb_function_get_extra_info".}
proc duckdb_function_get_bind_data*(info: duckdb_function_info): pointer {.
    cdecl, importc: "duckdb_function_get_bind_data".}
proc duckdb_function_get_init_data*(info: duckdb_function_info): pointer {.
    cdecl, importc: "duckdb_function_get_init_data".}
proc duckdb_function_get_local_init_data*(info: duckdb_function_info): pointer {.
    cdecl, importc: "duckdb_function_get_local_init_data".}
proc duckdb_function_set_error*(info: duckdb_function_info; error: cstring): void {.
    cdecl, importc: "duckdb_function_set_error".}
proc duckdb_add_replacement_scan*(db: duckdb_database;
                                  replacement: duckdb_replacement_callback_t;
                                  extra_data: pointer;
                                  delete_callback: duckdb_delete_callback_t): void {.
    cdecl, importc: "duckdb_add_replacement_scan".}
proc duckdb_replacement_scan_set_function_name*(
    info: duckdb_replacement_scan_info; function_name: cstring): void {.cdecl,
    importc: "duckdb_replacement_scan_set_function_name".}
proc duckdb_replacement_scan_add_parameter*(info: duckdb_replacement_scan_info;
    parameter: duckdb_value): void {.cdecl, importc: "duckdb_replacement_scan_add_parameter".}
proc duckdb_replacement_scan_set_error*(info: duckdb_replacement_scan_info;
                                        error: cstring): void {.cdecl,
    importc: "duckdb_replacement_scan_set_error".}
proc duckdb_get_profiling_info*(connection: duckdb_connection): duckdb_profiling_info {.
    cdecl, importc: "duckdb_get_profiling_info".}
proc duckdb_profiling_info_get_value*(info: duckdb_profiling_info; key: cstring): duckdb_value {.
    cdecl, importc: "duckdb_profiling_info_get_value".}
proc duckdb_profiling_info_get_metrics*(info: duckdb_profiling_info): duckdb_value {.
    cdecl, importc: "duckdb_profiling_info_get_metrics".}
proc duckdb_profiling_info_get_child_count*(info: duckdb_profiling_info): idx_t {.
    cdecl, importc: "duckdb_profiling_info_get_child_count".}
proc duckdb_profiling_info_get_child*(info: duckdb_profiling_info; index: idx_t): duckdb_profiling_info {.
    cdecl, importc: "duckdb_profiling_info_get_child".}
proc duckdb_appender_create*(connection: duckdb_connection; schema: cstring;
                             table: cstring; out_appender: ptr duckdb_appender): duckdb_state {.
    cdecl, importc: "duckdb_appender_create".}
proc duckdb_appender_create_ext*(connection: duckdb_connection;
                                 catalog: cstring; schema: cstring;
                                 table: cstring;
                                 out_appender: ptr duckdb_appender): duckdb_state {.
    cdecl, importc: "duckdb_appender_create_ext".}
proc duckdb_appender_create_query*(connection: duckdb_connection;
                                   query: cstring; column_count: idx_t;
                                   types: ptr duckdb_logical_type;
                                   table_name: cstring;
                                   column_names: ptr cstring;
                                   out_appender: ptr duckdb_appender): duckdb_state {.
    cdecl, importc: "duckdb_appender_create_query".}
proc duckdb_appender_column_count*(appender: duckdb_appender): idx_t {.cdecl,
    importc: "duckdb_appender_column_count".}
proc duckdb_appender_column_type*(appender: duckdb_appender; col_idx: idx_t): duckdb_logical_type {.
    cdecl, importc: "duckdb_appender_column_type".}
proc duckdb_appender_error*(appender: duckdb_appender): cstring {.cdecl,
    importc: "duckdb_appender_error".}
proc duckdb_appender_error_data*(appender: duckdb_appender): duckdb_error_data {.
    cdecl, importc: "duckdb_appender_error_data".}
proc duckdb_appender_flush*(appender: duckdb_appender): duckdb_state {.cdecl,
    importc: "duckdb_appender_flush".}
proc duckdb_appender_clear*(appender: duckdb_appender): duckdb_state {.cdecl,
    importc: "duckdb_appender_clear".}
proc duckdb_appender_close*(appender: duckdb_appender): duckdb_state {.cdecl,
    importc: "duckdb_appender_close".}
proc duckdb_appender_destroy*(appender: ptr duckdb_appender): duckdb_state {.
    cdecl, importc: "duckdb_appender_destroy".}
proc duckdb_appender_add_column*(appender: duckdb_appender; name: cstring): duckdb_state {.
    cdecl, importc: "duckdb_appender_add_column".}
proc duckdb_appender_clear_columns*(appender: duckdb_appender): duckdb_state {.
    cdecl, importc: "duckdb_appender_clear_columns".}
proc duckdb_appender_begin_row*(appender: duckdb_appender): duckdb_state {.
    cdecl, importc: "duckdb_appender_begin_row".}
proc duckdb_appender_end_row*(appender: duckdb_appender): duckdb_state {.cdecl,
    importc: "duckdb_appender_end_row".}
proc duckdb_append_default*(appender: duckdb_appender): duckdb_state {.cdecl,
    importc: "duckdb_append_default".}
proc duckdb_append_default_to_chunk*(appender: duckdb_appender;
                                     chunk: duckdb_data_chunk; col: idx_t;
                                     row: idx_t): duckdb_state {.cdecl,
    importc: "duckdb_append_default_to_chunk".}
proc duckdb_append_bool*(appender: duckdb_appender; value: bool): duckdb_state {.
    cdecl, importc: "duckdb_append_bool".}
proc duckdb_append_int8*(appender: duckdb_appender; value: int8): duckdb_state {.
    cdecl, importc: "duckdb_append_int8".}
proc duckdb_append_int16*(appender: duckdb_appender; value: int16): duckdb_state {.
    cdecl, importc: "duckdb_append_int16".}
proc duckdb_append_int32*(appender: duckdb_appender; value: int32): duckdb_state {.
    cdecl, importc: "duckdb_append_int32".}
proc duckdb_append_int64*(appender: duckdb_appender; value: int64): duckdb_state {.
    cdecl, importc: "duckdb_append_int64".}
proc duckdb_append_hugeint*(appender: duckdb_appender; value: duckdb_hugeint): duckdb_state {.
    cdecl, importc: "duckdb_append_hugeint".}
proc duckdb_append_uint8*(appender: duckdb_appender; value: uint8): duckdb_state {.
    cdecl, importc: "duckdb_append_uint8".}
proc duckdb_append_uint16*(appender: duckdb_appender; value: uint16): duckdb_state {.
    cdecl, importc: "duckdb_append_uint16".}
proc duckdb_append_uint32*(appender: duckdb_appender; value: uint32): duckdb_state {.
    cdecl, importc: "duckdb_append_uint32".}
proc duckdb_append_uint64*(appender: duckdb_appender; value: uint64): duckdb_state {.
    cdecl, importc: "duckdb_append_uint64".}
proc duckdb_append_uhugeint*(appender: duckdb_appender; value: duckdb_uhugeint): duckdb_state {.
    cdecl, importc: "duckdb_append_uhugeint".}
proc duckdb_append_float*(appender: duckdb_appender; value: cfloat): duckdb_state {.
    cdecl, importc: "duckdb_append_float".}
proc duckdb_append_double*(appender: duckdb_appender; value: cdouble): duckdb_state {.
    cdecl, importc: "duckdb_append_double".}
proc duckdb_append_date*(appender: duckdb_appender; value: duckdb_date): duckdb_state {.
    cdecl, importc: "duckdb_append_date".}
proc duckdb_append_time*(appender: duckdb_appender; value: duckdb_time): duckdb_state {.
    cdecl, importc: "duckdb_append_time".}
proc duckdb_append_timestamp*(appender: duckdb_appender; value: duckdb_timestamp): duckdb_state {.
    cdecl, importc: "duckdb_append_timestamp".}
proc duckdb_append_interval*(appender: duckdb_appender; value: duckdb_interval): duckdb_state {.
    cdecl, importc: "duckdb_append_interval".}
proc duckdb_append_varchar*(appender: duckdb_appender; val: cstring): duckdb_state {.
    cdecl, importc: "duckdb_append_varchar".}
proc duckdb_append_varchar_length*(appender: duckdb_appender; val: cstring;
                                   length: idx_t): duckdb_state {.cdecl,
    importc: "duckdb_append_varchar_length".}
proc duckdb_append_blob*(appender: duckdb_appender; data: pointer; length: idx_t): duckdb_state {.
    cdecl, importc: "duckdb_append_blob".}
proc duckdb_append_null*(appender: duckdb_appender): duckdb_state {.cdecl,
    importc: "duckdb_append_null".}
proc duckdb_append_value*(appender: duckdb_appender; value: duckdb_value): duckdb_state {.
    cdecl, importc: "duckdb_append_value".}
proc duckdb_append_data_chunk*(appender: duckdb_appender;
                               chunk: duckdb_data_chunk): duckdb_state {.cdecl,
    importc: "duckdb_append_data_chunk".}
proc duckdb_table_description_create*(connection: duckdb_connection;
                                      schema: cstring; table: cstring;
                                      out_arg: ptr duckdb_table_description): duckdb_state {.
    cdecl, importc: "duckdb_table_description_create".}
proc duckdb_table_description_create_ext*(connection: duckdb_connection;
    catalog: cstring; schema: cstring; table: cstring;
    out_arg: ptr duckdb_table_description): duckdb_state {.cdecl,
    importc: "duckdb_table_description_create_ext".}
proc duckdb_table_description_destroy*(table_description: ptr duckdb_table_description): void {.
    cdecl, importc: "duckdb_table_description_destroy".}
proc duckdb_table_description_error*(table_description: duckdb_table_description): cstring {.
    cdecl, importc: "duckdb_table_description_error".}
proc duckdb_column_has_default*(table_description: duckdb_table_description;
                                index: idx_t; out_arg: ptr bool): duckdb_state {.
    cdecl, importc: "duckdb_column_has_default".}
proc duckdb_table_description_get_column_count*(
    table_description: duckdb_table_description): idx_t {.cdecl,
    importc: "duckdb_table_description_get_column_count".}
proc duckdb_table_description_get_column_name*(
    table_description: duckdb_table_description; index: idx_t): cstring {.cdecl,
    importc: "duckdb_table_description_get_column_name".}
proc duckdb_table_description_get_column_type*(
    table_description: duckdb_table_description; index: idx_t): duckdb_logical_type {.
    cdecl, importc: "duckdb_table_description_get_column_type".}
proc duckdb_to_arrow_schema*(arrow_options: duckdb_arrow_options;
                             types: ptr duckdb_logical_type; names: ptr cstring;
                             column_count: idx_t;
                             out_schema: ptr struct_ArrowSchema): duckdb_error_data {.
    cdecl, importc: "duckdb_to_arrow_schema".}
proc duckdb_data_chunk_to_arrow*(arrow_options: duckdb_arrow_options;
                                 chunk: duckdb_data_chunk;
                                 out_arrow_array: ptr struct_ArrowArray): duckdb_error_data {.
    cdecl, importc: "duckdb_data_chunk_to_arrow".}
proc duckdb_schema_from_arrow*(connection: duckdb_connection;
                               schema: ptr struct_ArrowSchema;
                               out_types: ptr duckdb_arrow_converted_schema): duckdb_error_data {.
    cdecl, importc: "duckdb_schema_from_arrow".}
proc duckdb_data_chunk_from_arrow*(connection: duckdb_connection;
                                   arrow_array: ptr struct_ArrowArray;
    converted_schema: duckdb_arrow_converted_schema;
                                   out_chunk: ptr duckdb_data_chunk): duckdb_error_data {.
    cdecl, importc: "duckdb_data_chunk_from_arrow".}
proc duckdb_destroy_arrow_converted_schema*(
    arrow_converted_schema: ptr duckdb_arrow_converted_schema): void {.cdecl,
    importc: "duckdb_destroy_arrow_converted_schema".}
proc duckdb_query_arrow*(connection: duckdb_connection; query: cstring;
                         out_result: ptr duckdb_arrow): duckdb_state {.cdecl,
    importc: "duckdb_query_arrow".}
proc duckdb_query_arrow_schema*(result: duckdb_arrow;
                                out_schema: ptr duckdb_arrow_schema): duckdb_state {.
    cdecl, importc: "duckdb_query_arrow_schema".}
proc duckdb_prepared_arrow_schema*(prepared: duckdb_prepared_statement;
                                   out_schema: ptr duckdb_arrow_schema): duckdb_state {.
    cdecl, importc: "duckdb_prepared_arrow_schema".}
proc duckdb_result_arrow_array*(result: duckdb_result; chunk: duckdb_data_chunk;
                                out_array: ptr duckdb_arrow_array): void {.
    cdecl, importc: "duckdb_result_arrow_array".}
proc duckdb_query_arrow_array*(result: duckdb_arrow;
                               out_array: ptr duckdb_arrow_array): duckdb_state {.
    cdecl, importc: "duckdb_query_arrow_array".}
proc duckdb_arrow_column_count*(result: duckdb_arrow): idx_t {.cdecl,
    importc: "duckdb_arrow_column_count".}
proc duckdb_arrow_row_count*(result: duckdb_arrow): idx_t {.cdecl,
    importc: "duckdb_arrow_row_count".}
proc duckdb_arrow_rows_changed*(result: duckdb_arrow): idx_t {.cdecl,
    importc: "duckdb_arrow_rows_changed".}
proc duckdb_query_arrow_error*(result: duckdb_arrow): cstring {.cdecl,
    importc: "duckdb_query_arrow_error".}
proc duckdb_destroy_arrow*(result: ptr duckdb_arrow): void {.cdecl,
    importc: "duckdb_destroy_arrow".}
proc duckdb_destroy_arrow_stream*(stream_p: ptr duckdb_arrow_stream): void {.
    cdecl, importc: "duckdb_destroy_arrow_stream".}
proc duckdb_execute_prepared_arrow*(prepared_statement: duckdb_prepared_statement;
                                    out_result: ptr duckdb_arrow): duckdb_state {.
    cdecl, importc: "duckdb_execute_prepared_arrow".}
proc duckdb_arrow_scan*(connection: duckdb_connection; table_name: cstring;
                        arrow: duckdb_arrow_stream): duckdb_state {.cdecl,
    importc: "duckdb_arrow_scan".}
proc duckdb_arrow_array_scan*(connection: duckdb_connection;
                              table_name: cstring;
                              arrow_schema: duckdb_arrow_schema;
                              arrow_array: duckdb_arrow_array;
                              out_stream: ptr duckdb_arrow_stream): duckdb_state {.
    cdecl, importc: "duckdb_arrow_array_scan".}
proc duckdb_execute_tasks*(database: duckdb_database; max_tasks: idx_t): void {.
    cdecl, importc: "duckdb_execute_tasks".}
proc duckdb_create_task_state*(database: duckdb_database): duckdb_task_state {.
    cdecl, importc: "duckdb_create_task_state".}
proc duckdb_execute_tasks_state*(state: duckdb_task_state): void {.cdecl,
    importc: "duckdb_execute_tasks_state".}
proc duckdb_execute_n_tasks_state*(state: duckdb_task_state; max_tasks: idx_t): idx_t {.
    cdecl, importc: "duckdb_execute_n_tasks_state".}
proc duckdb_finish_execution*(state: duckdb_task_state): void {.cdecl,
    importc: "duckdb_finish_execution".}
proc duckdb_task_state_is_finished*(state: duckdb_task_state): bool {.cdecl,
    importc: "duckdb_task_state_is_finished".}
proc duckdb_destroy_task_state*(state: duckdb_task_state): void {.cdecl,
    importc: "duckdb_destroy_task_state".}
proc duckdb_execution_is_finished*(con: duckdb_connection): bool {.cdecl,
    importc: "duckdb_execution_is_finished".}
proc duckdb_stream_fetch_chunk*(result: duckdb_result): duckdb_data_chunk {.
    cdecl, importc: "duckdb_stream_fetch_chunk".}
proc duckdb_fetch_chunk*(result: duckdb_result): duckdb_data_chunk {.cdecl,
    importc: "duckdb_fetch_chunk".}
proc duckdb_create_cast_function*(): duckdb_cast_function {.cdecl,
    importc: "duckdb_create_cast_function".}
proc duckdb_cast_function_set_source_type*(cast_function: duckdb_cast_function;
    source_type: duckdb_logical_type): void {.cdecl,
    importc: "duckdb_cast_function_set_source_type".}
proc duckdb_cast_function_set_target_type*(cast_function: duckdb_cast_function;
    target_type: duckdb_logical_type): void {.cdecl,
    importc: "duckdb_cast_function_set_target_type".}
proc duckdb_cast_function_set_implicit_cast_cost*(
    cast_function: duckdb_cast_function; cost: int64): void {.cdecl,
    importc: "duckdb_cast_function_set_implicit_cast_cost".}
proc duckdb_cast_function_set_function*(cast_function: duckdb_cast_function;
                                        function: duckdb_cast_function_t): void {.
    cdecl, importc: "duckdb_cast_function_set_function".}
proc duckdb_cast_function_set_extra_info*(cast_function: duckdb_cast_function;
    extra_info: pointer; destroy: duckdb_delete_callback_t): void {.cdecl,
    importc: "duckdb_cast_function_set_extra_info".}
proc duckdb_cast_function_get_extra_info*(info: duckdb_function_info): pointer {.
    cdecl, importc: "duckdb_cast_function_get_extra_info".}
proc duckdb_cast_function_get_cast_mode*(info: duckdb_function_info): duckdb_cast_mode {.
    cdecl, importc: "duckdb_cast_function_get_cast_mode".}
proc duckdb_cast_function_set_error*(info: duckdb_function_info; error: cstring): void {.
    cdecl, importc: "duckdb_cast_function_set_error".}
proc duckdb_cast_function_set_row_error*(info: duckdb_function_info;
    error: cstring; row: idx_t; output: duckdb_vector): void {.cdecl,
    importc: "duckdb_cast_function_set_row_error".}
proc duckdb_register_cast_function*(con: duckdb_connection;
                                    cast_function: duckdb_cast_function): duckdb_state {.
    cdecl, importc: "duckdb_register_cast_function".}
proc duckdb_destroy_cast_function*(cast_function: ptr duckdb_cast_function): void {.
    cdecl, importc: "duckdb_destroy_cast_function".}
proc duckdb_destroy_expression*(expr: ptr duckdb_expression): void {.cdecl,
    importc: "duckdb_destroy_expression".}
proc duckdb_expression_return_type*(expr: duckdb_expression): duckdb_logical_type {.
    cdecl, importc: "duckdb_expression_return_type".}
proc duckdb_expression_is_foldable*(expr: duckdb_expression): bool {.cdecl,
    importc: "duckdb_expression_is_foldable".}
proc duckdb_expression_fold*(context: duckdb_client_context;
                             expr: duckdb_expression;
                             out_value: ptr duckdb_value): duckdb_error_data {.
    cdecl, importc: "duckdb_expression_fold".}
proc duckdb_client_context_get_file_system*(context: duckdb_client_context): duckdb_file_system {.
    cdecl, importc: "duckdb_client_context_get_file_system".}
proc duckdb_destroy_file_system*(file_system: ptr duckdb_file_system): void {.
    cdecl, importc: "duckdb_destroy_file_system".}
proc duckdb_file_system_error_data*(file_system: duckdb_file_system): duckdb_error_data {.
    cdecl, importc: "duckdb_file_system_error_data".}
proc duckdb_file_system_open*(file_system: duckdb_file_system; path: cstring;
                              options: duckdb_file_open_options;
                              out_file: ptr duckdb_file_handle): duckdb_state {.
    cdecl, importc: "duckdb_file_system_open".}
proc duckdb_create_file_open_options*(): duckdb_file_open_options {.cdecl,
    importc: "duckdb_create_file_open_options".}
proc duckdb_file_open_options_set_flag*(options: duckdb_file_open_options;
                                        flag: duckdb_file_flag; value: bool): duckdb_state {.
    cdecl, importc: "duckdb_file_open_options_set_flag".}
proc duckdb_destroy_file_open_options*(options: ptr duckdb_file_open_options): void {.
    cdecl, importc: "duckdb_destroy_file_open_options".}
proc duckdb_destroy_file_handle*(file_handle: ptr duckdb_file_handle): void {.
    cdecl, importc: "duckdb_destroy_file_handle".}
proc duckdb_file_handle_error_data*(file_handle: duckdb_file_handle): duckdb_error_data {.
    cdecl, importc: "duckdb_file_handle_error_data".}
proc duckdb_file_handle_read*(file_handle: duckdb_file_handle; buffer: pointer;
                              size: int64): int64 {.cdecl,
    importc: "duckdb_file_handle_read".}
proc duckdb_file_handle_write*(file_handle: duckdb_file_handle; buffer: pointer;
                               size: int64): int64 {.cdecl,
    importc: "duckdb_file_handle_write".}
proc duckdb_file_handle_tell*(file_handle: duckdb_file_handle): int64 {.cdecl,
    importc: "duckdb_file_handle_tell".}
proc duckdb_file_handle_size*(file_handle: duckdb_file_handle): int64 {.cdecl,
    importc: "duckdb_file_handle_size".}
proc duckdb_file_handle_seek*(file_handle: duckdb_file_handle; position: int64): duckdb_state {.
    cdecl, importc: "duckdb_file_handle_seek".}
proc duckdb_file_handle_sync*(file_handle: duckdb_file_handle): duckdb_state {.
    cdecl, importc: "duckdb_file_handle_sync".}
proc duckdb_file_handle_close*(file_handle: duckdb_file_handle): duckdb_state {.
    cdecl, importc: "duckdb_file_handle_close".}
proc duckdb_create_config_option*(): duckdb_config_option {.cdecl,
    importc: "duckdb_create_config_option".}
proc duckdb_destroy_config_option*(option: ptr duckdb_config_option): void {.
    cdecl, importc: "duckdb_destroy_config_option".}
proc duckdb_config_option_set_name*(option: duckdb_config_option; name: cstring): void {.
    cdecl, importc: "duckdb_config_option_set_name".}
proc duckdb_config_option_set_type*(option: duckdb_config_option;
                                    type_arg: duckdb_logical_type): void {.
    cdecl, importc: "duckdb_config_option_set_type".}
proc duckdb_config_option_set_default_value*(option: duckdb_config_option;
    default_value: duckdb_value): void {.cdecl,
    importc: "duckdb_config_option_set_default_value".}
proc duckdb_config_option_set_default_scope*(option: duckdb_config_option;
    default_scope: duckdb_config_option_scope): void {.cdecl,
    importc: "duckdb_config_option_set_default_scope".}
proc duckdb_config_option_set_description*(option: duckdb_config_option;
    description: cstring): void {.cdecl, importc: "duckdb_config_option_set_description".}
proc duckdb_register_config_option*(connection: duckdb_connection;
                                    option: duckdb_config_option): duckdb_state {.
    cdecl, importc: "duckdb_register_config_option".}
proc duckdb_client_context_get_config_option*(context: duckdb_client_context;
    name: cstring; out_scope: ptr duckdb_config_option_scope): duckdb_value {.
    cdecl, importc: "duckdb_client_context_get_config_option".}
proc duckdb_create_copy_function*(): duckdb_copy_function {.cdecl,
    importc: "duckdb_create_copy_function".}
proc duckdb_copy_function_set_name*(copy_function: duckdb_copy_function;
                                    name: cstring): void {.cdecl,
    importc: "duckdb_copy_function_set_name".}
proc duckdb_copy_function_set_extra_info*(copy_function: duckdb_copy_function;
    extra_info: pointer; destructor: duckdb_delete_callback_t): void {.cdecl,
    importc: "duckdb_copy_function_set_extra_info".}
proc duckdb_register_copy_function*(connection: duckdb_connection;
                                    copy_function: duckdb_copy_function): duckdb_state {.
    cdecl, importc: "duckdb_register_copy_function".}
proc duckdb_destroy_copy_function*(copy_function: ptr duckdb_copy_function): void {.
    cdecl, importc: "duckdb_destroy_copy_function".}
proc duckdb_copy_function_set_bind*(copy_function: duckdb_copy_function;
                                    bind_arg: duckdb_copy_function_bind_t): void {.
    cdecl, importc: "duckdb_copy_function_set_bind".}
proc duckdb_copy_function_bind_set_error*(info: duckdb_copy_function_bind_info;
    error: cstring): void {.cdecl,
                            importc: "duckdb_copy_function_bind_set_error".}
proc duckdb_copy_function_bind_get_extra_info*(
    info: duckdb_copy_function_bind_info): pointer {.cdecl,
    importc: "duckdb_copy_function_bind_get_extra_info".}
proc duckdb_copy_function_bind_get_client_context*(
    info: duckdb_copy_function_bind_info): duckdb_client_context {.cdecl,
    importc: "duckdb_copy_function_bind_get_client_context".}
proc duckdb_copy_function_bind_get_column_count*(
    info: duckdb_copy_function_bind_info): idx_t {.cdecl,
    importc: "duckdb_copy_function_bind_get_column_count".}
proc duckdb_copy_function_bind_get_column_type*(
    info: duckdb_copy_function_bind_info; col_idx: idx_t): duckdb_logical_type {.
    cdecl, importc: "duckdb_copy_function_bind_get_column_type".}
proc duckdb_copy_function_bind_get_options*(info: duckdb_copy_function_bind_info): duckdb_value {.
    cdecl, importc: "duckdb_copy_function_bind_get_options".}
proc duckdb_copy_function_bind_set_bind_data*(
    info: duckdb_copy_function_bind_info; bind_data: pointer;
    destructor: duckdb_delete_callback_t): void {.cdecl,
    importc: "duckdb_copy_function_bind_set_bind_data".}
proc duckdb_copy_function_set_global_init*(copy_function: duckdb_copy_function;
    init: duckdb_copy_function_global_init_t): void {.cdecl,
    importc: "duckdb_copy_function_set_global_init".}
proc duckdb_copy_function_global_init_set_error*(
    info: duckdb_copy_function_global_init_info; error: cstring): void {.cdecl,
    importc: "duckdb_copy_function_global_init_set_error".}
proc duckdb_copy_function_global_init_get_extra_info*(
    info: duckdb_copy_function_global_init_info): pointer {.cdecl,
    importc: "duckdb_copy_function_global_init_get_extra_info".}
proc duckdb_copy_function_global_init_get_client_context*(
    info: duckdb_copy_function_global_init_info): duckdb_client_context {.cdecl,
    importc: "duckdb_copy_function_global_init_get_client_context".}
proc duckdb_copy_function_global_init_get_bind_data*(
    info: duckdb_copy_function_global_init_info): pointer {.cdecl,
    importc: "duckdb_copy_function_global_init_get_bind_data".}
proc duckdb_copy_function_global_init_get_file_path*(
    info: duckdb_copy_function_global_init_info): cstring {.cdecl,
    importc: "duckdb_copy_function_global_init_get_file_path".}
proc duckdb_copy_function_global_init_set_global_state*(
    info: duckdb_copy_function_global_init_info; global_state: pointer;
    destructor: duckdb_delete_callback_t): void {.cdecl,
    importc: "duckdb_copy_function_global_init_set_global_state".}
proc duckdb_copy_function_set_sink*(copy_function: duckdb_copy_function;
                                    function: duckdb_copy_function_sink_t): void {.
    cdecl, importc: "duckdb_copy_function_set_sink".}
proc duckdb_copy_function_sink_set_error*(info: duckdb_copy_function_sink_info;
    error: cstring): void {.cdecl,
                            importc: "duckdb_copy_function_sink_set_error".}
proc duckdb_copy_function_sink_get_extra_info*(
    info: duckdb_copy_function_sink_info): pointer {.cdecl,
    importc: "duckdb_copy_function_sink_get_extra_info".}
proc duckdb_copy_function_sink_get_client_context*(
    info: duckdb_copy_function_sink_info): duckdb_client_context {.cdecl,
    importc: "duckdb_copy_function_sink_get_client_context".}
proc duckdb_copy_function_sink_get_bind_data*(
    info: duckdb_copy_function_sink_info): pointer {.cdecl,
    importc: "duckdb_copy_function_sink_get_bind_data".}
proc duckdb_copy_function_sink_get_global_state*(
    info: duckdb_copy_function_sink_info): pointer {.cdecl,
    importc: "duckdb_copy_function_sink_get_global_state".}
proc duckdb_copy_function_set_finalize*(copy_function: duckdb_copy_function;
    finalize: duckdb_copy_function_finalize_t): void {.cdecl,
    importc: "duckdb_copy_function_set_finalize".}
proc duckdb_copy_function_finalize_set_error*(
    info: duckdb_copy_function_finalize_info; error: cstring): void {.cdecl,
    importc: "duckdb_copy_function_finalize_set_error".}
proc duckdb_copy_function_finalize_get_extra_info*(
    info: duckdb_copy_function_finalize_info): pointer {.cdecl,
    importc: "duckdb_copy_function_finalize_get_extra_info".}
proc duckdb_copy_function_finalize_get_client_context*(
    info: duckdb_copy_function_finalize_info): duckdb_client_context {.cdecl,
    importc: "duckdb_copy_function_finalize_get_client_context".}
proc duckdb_copy_function_finalize_get_bind_data*(
    info: duckdb_copy_function_finalize_info): pointer {.cdecl,
    importc: "duckdb_copy_function_finalize_get_bind_data".}
proc duckdb_copy_function_finalize_get_global_state*(
    info: duckdb_copy_function_finalize_info): pointer {.cdecl,
    importc: "duckdb_copy_function_finalize_get_global_state".}
proc duckdb_copy_function_set_copy_from_function*(
    copy_function: duckdb_copy_function; table_function: duckdb_table_function): void {.
    cdecl, importc: "duckdb_copy_function_set_copy_from_function".}
proc duckdb_table_function_bind_get_result_column_count*(info: duckdb_bind_info): idx_t {.
    cdecl, importc: "duckdb_table_function_bind_get_result_column_count".}
proc duckdb_table_function_bind_get_result_column_name*(info: duckdb_bind_info;
    col_idx: idx_t): cstring {.cdecl, importc: "duckdb_table_function_bind_get_result_column_name".}
proc duckdb_table_function_bind_get_result_column_type*(info: duckdb_bind_info;
    col_idx: idx_t): duckdb_logical_type {.cdecl,
    importc: "duckdb_table_function_bind_get_result_column_type".}
proc duckdb_client_context_get_catalog*(context: duckdb_client_context;
                                        catalog_name: cstring): duckdb_catalog {.
    cdecl, importc: "duckdb_client_context_get_catalog".}
proc duckdb_catalog_get_type_name*(catalog: duckdb_catalog): cstring {.cdecl,
    importc: "duckdb_catalog_get_type_name".}
proc duckdb_catalog_get_entry*(catalog: duckdb_catalog;
                               context: duckdb_client_context;
                               entry_type: duckdb_catalog_entry_type;
                               schema_name: cstring; entry_name: cstring): duckdb_catalog_entry {.
    cdecl, importc: "duckdb_catalog_get_entry".}
proc duckdb_destroy_catalog*(catalog: ptr duckdb_catalog): void {.cdecl,
    importc: "duckdb_destroy_catalog".}
proc duckdb_catalog_entry_get_type*(entry: duckdb_catalog_entry): duckdb_catalog_entry_type {.
    cdecl, importc: "duckdb_catalog_entry_get_type".}
proc duckdb_catalog_entry_get_name*(entry: duckdb_catalog_entry): cstring {.
    cdecl, importc: "duckdb_catalog_entry_get_name".}
proc duckdb_destroy_catalog_entry*(entry: ptr duckdb_catalog_entry): void {.
    cdecl, importc: "duckdb_destroy_catalog_entry".}
proc duckdb_create_log_storage*(): duckdb_log_storage {.cdecl,
    importc: "duckdb_create_log_storage".}
proc duckdb_destroy_log_storage*(log_storage: ptr duckdb_log_storage): void {.
    cdecl, importc: "duckdb_destroy_log_storage".}
proc duckdb_log_storage_set_write_log_entry*(log_storage: duckdb_log_storage;
    function: duckdb_logger_write_log_entry_t): void {.cdecl,
    importc: "duckdb_log_storage_set_write_log_entry".}
proc duckdb_log_storage_set_extra_data*(log_storage: duckdb_log_storage;
                                        extra_data: pointer; delete_callback: duckdb_delete_callback_t): void {.
    cdecl, importc: "duckdb_log_storage_set_extra_data".}
proc duckdb_log_storage_set_name*(log_storage: duckdb_log_storage; name: cstring): void {.
    cdecl, importc: "duckdb_log_storage_set_name".}
proc duckdb_register_log_storage*(database: duckdb_database;
                                  log_storage: duckdb_log_storage): duckdb_state {.
    cdecl, importc: "duckdb_register_log_storage".}
proc duckdb_geometry_type_get_crs*(type_arg: duckdb_logical_type): cstring {.
    cdecl, importc: "duckdb_geometry_type_get_crs".}