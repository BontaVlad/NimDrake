{.warning[UnusedImport]: off.}
{.hint[XDeclaredButNotUsed]: off.}
from macros import hint, warning, newLit, getSize

from os import parentDir

when not declared(ownSizeOf):
  macro ownSizeof(x: typed): untyped =
    newLit(x.getSize)

type enum_DUCKDB_TYPE_2181038529* {.size: sizeof(cuint).} = enum
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

type enum_duckdb_state_2181038534* {.size: sizeof(cuint).} = enum
  DuckDBSuccess = 0
  DuckDBError = 1

type enum_duckdb_pending_state_2181038538* {.size: sizeof(cuint).} = enum
  DUCKDB_PENDING_RESULT_READY = 0
  DUCKDB_PENDING_RESULT_NOT_READY = 1
  DUCKDB_PENDING_ERROR = 2
  DUCKDB_PENDING_NO_TASKS_AVAILABLE = 3

type enum_duckdb_result_type_2181038542* {.size: sizeof(cuint).} = enum
  DUCKDB_RESULT_TYPE_INVALID = 0
  DUCKDB_RESULT_TYPE_CHANGED_ROWS = 1
  DUCKDB_RESULT_TYPE_NOTHING = 2
  DUCKDB_RESULT_TYPE_QUERY_RESULT = 3

type enum_duckdb_statement_type_2181038546* {.size: sizeof(cuint).} = enum
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

type enum_duckdb_error_type_2181038550* {.size: sizeof(cuint).} = enum
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

type enum_duckdb_cast_mode_2181038554* {.size: sizeof(cuint).} = enum
  DUCKDB_CAST_NORMAL = 0
  DUCKDB_CAST_TRY = 1

type
  duckdb_type_2181038532 = enum_DUCKDB_TYPE_2181038531
    ## Generated based on /usr/include/duckdb.h:141:3
  duckdb_state_2181038536 = enum_duckdb_state_2181038535
    ## Generated based on /usr/include/duckdb.h:143:66
  duckdb_pending_state_2181038540 = enum_duckdb_pending_state_2181038539
    ## Generated based on /usr/include/duckdb.h:150:3
  duckdb_result_type_2181038544 = enum_duckdb_result_type_2181038543
    ## Generated based on /usr/include/duckdb.h:157:3
  duckdb_statement_type_2181038548 = enum_duckdb_statement_type_2181038547
    ## Generated based on /usr/include/duckdb.h:188:3
  duckdb_error_type_2181038552 = enum_duckdb_error_type_2181038551
    ## Generated based on /usr/include/duckdb.h:234:3
  duckdb_cast_mode_2181038556 = enum_duckdb_cast_mode_2181038555
    ## Generated based on /usr/include/duckdb.h:236:79
  idx_t_2181038558 = uint64 ## Generated based on /usr/include/duckdb.h:243:18
  sel_t_2181038560 = uint32 ## Generated based on /usr/include/duckdb.h:246:18
  duckdb_delete_callback_t_2181038562 = proc(a0: pointer): void {.cdecl.}
    ## Generated based on /usr/include/duckdb.h:250:16
  duckdb_task_state_2181038564 = pointer
    ## Generated based on /usr/include/duckdb.h:253:15
  struct_duckdb_date_2181038566 {.pure, inheritable, bycopy.} = object
    days*: int32 ## Generated based on /usr/include/duckdb.h:261:9

  duckdb_date_2181038568 = struct_duckdb_date_2181038567
    ## Generated based on /usr/include/duckdb.h:263:3
  struct_duckdb_date_struct_2181038570 {.pure, inheritable, bycopy.} = object
    year*: int32 ## Generated based on /usr/include/duckdb.h:264:9
    month*: int8
    day*: int8

  duckdb_date_struct_2181038572 = struct_duckdb_date_struct_2181038571
    ## Generated based on /usr/include/duckdb.h:268:3
  struct_duckdb_time_2181038574 {.pure, inheritable, bycopy.} = object
    micros*: int64 ## Generated based on /usr/include/duckdb.h:272:9

  duckdb_time_2181038576 = struct_duckdb_time_2181038575
    ## Generated based on /usr/include/duckdb.h:274:3
  struct_duckdb_time_struct_2181038578 {.pure, inheritable, bycopy.} = object
    hour*: int8 ## Generated based on /usr/include/duckdb.h:275:9
    min*: int8
    sec*: int8
    micros*: int32

  duckdb_time_struct_2181038580 = struct_duckdb_time_struct_2181038579
    ## Generated based on /usr/include/duckdb.h:280:3
  struct_duckdb_time_tz_2181038582 {.pure, inheritable, bycopy.} = object
    bits*: uint64 ## Generated based on /usr/include/duckdb.h:283:9

  duckdb_time_tz_2181038584 = struct_duckdb_time_tz_2181038583
    ## Generated based on /usr/include/duckdb.h:285:3
  struct_duckdb_time_tz_struct_2181038586 {.pure, inheritable, bycopy.} = object
    time*: duckdb_time_struct_2181038581
      ## Generated based on /usr/include/duckdb.h:286:9
    offset*: int32

  duckdb_time_tz_struct_2181038588 = struct_duckdb_time_tz_struct_2181038587
    ## Generated based on /usr/include/duckdb.h:289:3
  struct_duckdb_timestamp_2181038590 {.pure, inheritable, bycopy.} = object
    micros*: int64 ## Generated based on /usr/include/duckdb.h:293:9

  duckdb_timestamp_2181038592 = struct_duckdb_timestamp_2181038591
    ## Generated based on /usr/include/duckdb.h:295:3
  struct_duckdb_timestamp_s_2181038594 {.pure, inheritable, bycopy.} = object
    seconds*: int64 ## Generated based on /usr/include/duckdb.h:298:9

  duckdb_timestamp_s_2181038596 = struct_duckdb_timestamp_s_2181038595
    ## Generated based on /usr/include/duckdb.h:300:3
  struct_duckdb_timestamp_ms_2181038598 {.pure, inheritable, bycopy.} = object
    millis*: int64 ## Generated based on /usr/include/duckdb.h:303:9

  duckdb_timestamp_ms_2181038600 = struct_duckdb_timestamp_ms_2181038599
    ## Generated based on /usr/include/duckdb.h:305:3
  struct_duckdb_timestamp_ns_2181038602 {.pure, inheritable, bycopy.} = object
    nanos*: int64 ## Generated based on /usr/include/duckdb.h:308:9

  duckdb_timestamp_ns_2181038604 = struct_duckdb_timestamp_ns_2181038603
    ## Generated based on /usr/include/duckdb.h:310:3
  struct_duckdb_timestamp_struct_2181038606 {.pure, inheritable, bycopy.} = object
    date*: duckdb_date_struct_2181038573
      ## Generated based on /usr/include/duckdb.h:312:9
    time*: duckdb_time_struct_2181038581

  duckdb_timestamp_struct_2181038608 = struct_duckdb_timestamp_struct_2181038607
    ## Generated based on /usr/include/duckdb.h:315:3
  struct_duckdb_interval_2181038610 {.pure, inheritable, bycopy.} = object
    months*: int32 ## Generated based on /usr/include/duckdb.h:317:9
    days*: int32
    micros*: int64

  duckdb_interval_2181038612 = struct_duckdb_interval_2181038611
    ## Generated based on /usr/include/duckdb.h:321:3
  struct_duckdb_hugeint_2181038614 {.pure, inheritable, bycopy.} = object
    lower*: uint64 ## Generated based on /usr/include/duckdb.h:326:9
    upper*: int64

  duckdb_hugeint_2181038616 = struct_duckdb_hugeint_2181038615
    ## Generated based on /usr/include/duckdb.h:329:3
  struct_duckdb_uhugeint_2181038618 {.pure, inheritable, bycopy.} = object
    lower*: uint64 ## Generated based on /usr/include/duckdb.h:330:9
    upper*: uint64

  duckdb_uhugeint_2181038627 = struct_duckdb_uhugeint_2181038626
    ## Generated based on /usr/include/duckdb.h:333:3
  struct_duckdb_decimal_2181038629 {.pure, inheritable, bycopy.} = object
    width*: uint8 ## Generated based on /usr/include/duckdb.h:336:9
    scale*: uint8
    value*: duckdb_hugeint_2181038617

  duckdb_decimal_2181038631 = struct_duckdb_decimal_2181038630
    ## Generated based on /usr/include/duckdb.h:340:3
  struct_duckdb_query_progress_type_2181038633 {.pure, inheritable, bycopy.} = object
    percentage*: cdouble ## Generated based on /usr/include/duckdb.h:343:9
    rows_processed*: uint64
    total_rows_to_process*: uint64

  duckdb_query_progress_type_2181038635 = struct_duckdb_query_progress_type_2181038634
    ## Generated based on /usr/include/duckdb.h:347:3
  struct_duckdb_string_t_value_t_pointer_t {.pure, inheritable, bycopy.} = object
    length*: uint32
    prefix*: array[4'i64, cschar]
    ptr_field*: cstring

  struct_duckdb_string_t_value_t_inlined_t* {.pure, inheritable, bycopy.} = object
    length*: uint32
    inlined*: array[12'i64, cschar]

  struct_duckdb_string_t_value_t* {.union, bycopy.} = object
    pointer*: struct_duckdb_string_t_value_t_pointer_t
    inlined*: struct_duckdb_string_t_value_t_inlined_t

  struct_duckdb_string_t_2181038637 {.pure, inheritable, bycopy.} = object
    value*: struct_duckdb_string_t_value_t
      ## Generated based on /usr/include/duckdb.h:353:9

  duckdb_string_t_2181038639 = struct_duckdb_string_t_2181038638
    ## Generated based on /usr/include/duckdb.h:365:3
  struct_duckdb_list_entry_2181038641 {.pure, inheritable, bycopy.} = object
    offset*: uint64 ## Generated based on /usr/include/duckdb.h:370:9
    length*: uint64

  duckdb_list_entry_2181038643 = struct_duckdb_list_entry_2181038642
    ## Generated based on /usr/include/duckdb.h:373:3
  struct_duckdb_column_2181038645 {.pure, inheritable, bycopy.} = object
    deprecated_data*: pointer ## Generated based on /usr/include/duckdb.h:379:9
    deprecated_nullmask*: ptr bool
    deprecated_type*: duckdb_type_2181038533
    deprecated_name*: cstring
    internal_data*: pointer

  duckdb_column_2181038647 = struct_duckdb_column_2181038646
    ## Generated based on /usr/include/duckdb.h:389:3
  struct_duckdb_vector_2181038649 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:393:16

  duckdb_vector_2181038651 = ptr struct_duckdb_vector_2181038650
    ## Generated based on /usr/include/duckdb.h:395:5
  struct_duckdb_selection_vector_2181038653 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:399:16

  duckdb_selection_vector_2181038655 = ptr struct_duckdb_selection_vector_2181038654
    ## Generated based on /usr/include/duckdb.h:401:5
  struct_duckdb_string_2181038657 {.pure, inheritable, bycopy.} = object
    data*: cstring ## Generated based on /usr/include/duckdb.h:409:9
    size*: idx_t_2181038559

  duckdb_string_2181038659 = struct_duckdb_string_2181038658
    ## Generated based on /usr/include/duckdb.h:412:3
  struct_duckdb_blob_2181038661 {.pure, inheritable, bycopy.} = object
    data*: pointer ## Generated based on /usr/include/duckdb.h:416:9
    size*: idx_t_2181038559

  duckdb_blob_2181038663 = struct_duckdb_blob_2181038662
    ## Generated based on /usr/include/duckdb.h:419:3
  struct_duckdb_bit_2181038665 {.pure, inheritable, bycopy.} = object
    data*: ptr uint8 ## Generated based on /usr/include/duckdb.h:426:9
    size*: idx_t_2181038559

  duckdb_bit_2181038667 = struct_duckdb_bit_2181038666
    ## Generated based on /usr/include/duckdb.h:429:3
  struct_duckdb_varint_2181038669 {.pure, inheritable, bycopy.} = object
    data*: ptr uint8 ## Generated based on /usr/include/duckdb.h:434:9
    size*: idx_t_2181038559
    is_negative*: bool

  duckdb_varint_2181038671 = struct_duckdb_varint_2181038670
    ## Generated based on /usr/include/duckdb.h:438:3
  struct_duckdb_result_2181038673 {.pure, inheritable, bycopy.} = object
    deprecated_column_count*: idx_t_2181038559
      ## Generated based on /usr/include/duckdb.h:442:9
    deprecated_row_count*: idx_t_2181038559
    deprecated_rows_changed*: idx_t_2181038559
    deprecated_columns*: ptr duckdb_column_2181038648
    deprecated_error_message*: cstring
    internal_data*: pointer

  duckdb_result_2181038675 = struct_duckdb_result_2181038674
    ## Generated based on /usr/include/duckdb.h:454:3
  struct_duckdb_instance_cache_2181038677 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:457:16

  duckdb_instance_cache_2181038679 = ptr struct_duckdb_instance_cache_2181038678
    ## Generated based on /usr/include/duckdb.h:459:5
  struct_duckdb_database_2181038681 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:462:16

  duckdb_database_2181038683 = ptr struct_duckdb_database_2181038682
    ## Generated based on /usr/include/duckdb.h:464:5
  struct_duckdb_connection_2181038685 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:467:16

  duckdb_connection_2181038687 = ptr struct_duckdb_connection_2181038686
    ## Generated based on /usr/include/duckdb.h:469:5
  struct_duckdb_client_context_2181038689 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:472:16

  duckdb_client_context_2181038691 = ptr struct_duckdb_client_context_2181038690
    ## Generated based on /usr/include/duckdb.h:474:5
  struct_duckdb_prepared_statement_2181038693 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:478:16

  duckdb_prepared_statement_2181038695 = ptr struct_duckdb_prepared_statement_2181038694
    ## Generated based on /usr/include/duckdb.h:480:5
  struct_duckdb_extracted_statements_2181038697 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:483:16

  duckdb_extracted_statements_2181038699 =
    ptr struct_duckdb_extracted_statements_2181038698
    ## Generated based on /usr/include/duckdb.h:485:5
  struct_duckdb_pending_result_2181038701 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:489:16

  duckdb_pending_result_2181038703 = ptr struct_duckdb_pending_result_2181038702
    ## Generated based on /usr/include/duckdb.h:491:5
  struct_duckdb_appender_2181038705 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:495:16

  duckdb_appender_2181038707 = ptr struct_duckdb_appender_2181038706
    ## Generated based on /usr/include/duckdb.h:497:5
  struct_duckdb_table_description_2181038709 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:501:16

  duckdb_table_description_2181038711 = ptr struct_duckdb_table_description_2181038710
    ## Generated based on /usr/include/duckdb.h:503:5
  struct_duckdb_config_2181038713 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:507:16

  duckdb_config_2181038715 = ptr struct_duckdb_config_2181038714
    ## Generated based on /usr/include/duckdb.h:509:5
  struct_duckdb_logical_type_2181038717 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:513:16

  duckdb_logical_type_2181038719 = ptr struct_duckdb_logical_type_2181038718
    ## Generated based on /usr/include/duckdb.h:515:5
  struct_duckdb_create_type_info_2181038721 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:519:16

  duckdb_create_type_info_2181038723 = ptr struct_duckdb_create_type_info_2181038722
    ## Generated based on /usr/include/duckdb.h:521:5
  struct_duckdb_data_chunk_2181038725 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:525:16

  duckdb_data_chunk_2181038727 = ptr struct_duckdb_data_chunk_2181038726
    ## Generated based on /usr/include/duckdb.h:527:5
  struct_duckdb_value_2181038729 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:531:16

  duckdb_value_2181038731 = ptr struct_duckdb_value_2181038730
    ## Generated based on /usr/include/duckdb.h:533:5
  struct_duckdb_profiling_info_2181038733 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:536:16

  duckdb_profiling_info_2181038735 = ptr struct_duckdb_profiling_info_2181038734
    ## Generated based on /usr/include/duckdb.h:538:5
  struct_duckdb_extension_info_2181038737 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:545:16

  duckdb_extension_info_2181038739 = ptr struct_duckdb_extension_info_2181038738
    ## Generated based on /usr/include/duckdb.h:547:5
  struct_duckdb_function_info_2181038741 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:555:16

  duckdb_function_info_2181038743 = ptr struct_duckdb_function_info_2181038742
    ## Generated based on /usr/include/duckdb.h:557:5
  struct_duckdb_bind_info_2181038745 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:561:16

  duckdb_bind_info_2181038747 = ptr struct_duckdb_bind_info_2181038746
    ## Generated based on /usr/include/duckdb.h:563:5
  struct_duckdb_scalar_function_2181038749 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:570:16

  duckdb_scalar_function_2181038751 = ptr struct_duckdb_scalar_function_2181038750
    ## Generated based on /usr/include/duckdb.h:572:5
  struct_duckdb_scalar_function_set_2181038753 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:575:16

  duckdb_scalar_function_set_2181038755 =
    ptr struct_duckdb_scalar_function_set_2181038754
    ## Generated based on /usr/include/duckdb.h:577:5
  duckdb_scalar_function_bind_t_2181038757 =
    proc(a0: duckdb_bind_info_2181038748): void {.cdecl.}
    ## Generated based on /usr/include/duckdb.h:580:16
  duckdb_scalar_function_t_2181038759 = proc(
    a0: duckdb_function_info_2181038744,
    a1: duckdb_data_chunk_2181038728,
    a2: duckdb_vector_2181038652,
  ): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:583:16
  struct_duckdb_aggregate_function_2181038761 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:589:16

  duckdb_aggregate_function_2181038763 = ptr struct_duckdb_aggregate_function_2181038762
    ## Generated based on /usr/include/duckdb.h:591:5
  struct_duckdb_aggregate_function_set_2181038765 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:594:16

  duckdb_aggregate_function_set_2181038767 =
    ptr struct_duckdb_aggregate_function_set_2181038766
    ## Generated based on /usr/include/duckdb.h:596:5
  struct_duckdb_aggregate_state_2181038769 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:599:16

  duckdb_aggregate_state_2181038771 = ptr struct_duckdb_aggregate_state_2181038770
    ## Generated based on /usr/include/duckdb.h:601:5
  duckdb_aggregate_state_size_2181038773 =
    proc(a0: duckdb_function_info_2181038744): idx_t_2181038559 {.cdecl.}
    ## Generated based on /usr/include/duckdb.h:604:17
  duckdb_aggregate_init_t_2181038775 = proc(
    a0: duckdb_function_info_2181038744, a1: duckdb_aggregate_state_2181038772
  ): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:606:16
  duckdb_aggregate_destroy_t_2181038777 = proc(
    a0: ptr duckdb_aggregate_state_2181038772, a1: idx_t_2181038559
  ): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:608:16
  duckdb_aggregate_update_t_2181038779 = proc(
    a0: duckdb_function_info_2181038744,
    a1: duckdb_data_chunk_2181038728,
    a2: ptr duckdb_aggregate_state_2181038772,
  ): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:610:16
  duckdb_aggregate_combine_t_2181038781 = proc(
    a0: duckdb_function_info_2181038744,
    a1: ptr duckdb_aggregate_state_2181038772,
    a2: ptr duckdb_aggregate_state_2181038772,
    a3: idx_t_2181038559,
  ): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:613:16
  duckdb_aggregate_finalize_t_2181038783 = proc(
    a0: duckdb_function_info_2181038744,
    a1: ptr duckdb_aggregate_state_2181038772,
    a2: duckdb_vector_2181038652,
    a3: idx_t_2181038559,
    a4: idx_t_2181038559,
  ): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:616:16
  struct_duckdb_table_function_2181038785 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:624:16

  duckdb_table_function_2181038787 = ptr struct_duckdb_table_function_2181038786
    ## Generated based on /usr/include/duckdb.h:626:5
  struct_duckdb_init_info_2181038789 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:629:16

  duckdb_init_info_2181038791 = ptr struct_duckdb_init_info_2181038790
    ## Generated based on /usr/include/duckdb.h:631:5
  duckdb_table_function_bind_t_2181038793 =
    proc(a0: duckdb_bind_info_2181038748): void {.cdecl.}
    ## Generated based on /usr/include/duckdb.h:634:16
  duckdb_table_function_init_t_2181038795 =
    proc(a0: duckdb_init_info_2181038792): void {.cdecl.}
    ## Generated based on /usr/include/duckdb.h:637:16
  duckdb_table_function_t_2181038797 = proc(
    a0: duckdb_function_info_2181038744, a1: duckdb_data_chunk_2181038728
  ): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:640:16
  struct_duckdb_cast_function_2181038799 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:647:16

  duckdb_cast_function_2181038801 = ptr struct_duckdb_cast_function_2181038800
    ## Generated based on /usr/include/duckdb.h:649:5
  duckdb_cast_function_t_2181038803 = proc(
    a0: duckdb_function_info_2181038744,
    a1: idx_t_2181038559,
    a2: duckdb_vector_2181038652,
    a3: duckdb_vector_2181038652,
  ): bool {.cdecl.} ## Generated based on /usr/include/duckdb.h:651:16
  struct_duckdb_replacement_scan_info_2181038805 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:659:16

  duckdb_replacement_scan_info_2181038807 =
    ptr struct_duckdb_replacement_scan_info_2181038806
    ## Generated based on /usr/include/duckdb.h:661:5
  duckdb_replacement_callback_t_2181038809 = proc(
    a0: duckdb_replacement_scan_info_2181038808, a1: cstring, a2: pointer
  ): void {.cdecl.} ## Generated based on /usr/include/duckdb.h:664:16
  struct_duckdb_arrow_2181038811 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:671:16

  duckdb_arrow_2181038813 = ptr struct_duckdb_arrow_2181038812
    ## Generated based on /usr/include/duckdb.h:673:5
  struct_duckdb_arrow_stream_2181038815 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:676:16

  duckdb_arrow_stream_2181038817 = ptr struct_duckdb_arrow_stream_2181038816
    ## Generated based on /usr/include/duckdb.h:678:5
  struct_duckdb_arrow_schema_2181038819 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:681:16

  duckdb_arrow_schema_2181038821 = ptr struct_duckdb_arrow_schema_2181038820
    ## Generated based on /usr/include/duckdb.h:683:5
  struct_duckdb_arrow_array_2181038823 {.pure, inheritable, bycopy.} = object
    internal_ptr*: pointer ## Generated based on /usr/include/duckdb.h:686:16

  duckdb_arrow_array_2181038825 = ptr struct_duckdb_arrow_array_2181038824
    ## Generated based on /usr/include/duckdb.h:688:5
  struct_duckdb_extension_access_2181038827 {.pure, inheritable, bycopy.} = object
    set_error*: proc(a0: duckdb_extension_info_2181038740, a1: cstring): void {.cdecl.}
      ## Generated based on /usr/include/duckdb.h:694:8
    get_database*: proc(
      a0: duckdb_extension_info_2181038740
    ): ptr duckdb_database_2181038684 {.cdecl.}
    get_api*: proc(a0: duckdb_extension_info_2181038740, a1: cstring): pointer {.cdecl.}

  duckdb_time_2181038577 = (
    when declared(duckdb_time):
      when ownSizeof(duckdb_time) != ownSizeof(duckdb_time_2181038576):
        static:
          warning("Declaration of " & "duckdb_time" & " exists but with different size")
      duckdb_time
    else:
      duckdb_time_2181038576
  )
  enum_duckdb_cast_mode_2181038555 = (
    when declared(enum_duckdb_cast_mode):
      when ownSizeof(enum_duckdb_cast_mode) !=
          ownSizeof(enum_duckdb_cast_mode_2181038554):
        static:
          warning(
            "Declaration of " & "enum_duckdb_cast_mode" &
              " exists but with different size"
          )
      enum_duckdb_cast_mode
    else:
      enum_duckdb_cast_mode_2181038554
  )
  duckdb_function_info_2181038744 = (
    when declared(duckdb_function_info):
      when ownSizeof(duckdb_function_info) != ownSizeof(duckdb_function_info_2181038743):
        static:
          warning(
            "Declaration of " & "duckdb_function_info" &
              " exists but with different size"
          )
      duckdb_function_info
    else:
      duckdb_function_info_2181038743
  )
  struct_duckdb_scalar_function_set_2181038754 = (
    when declared(struct_duckdb_scalar_function_set):
      when ownSizeof(struct_duckdb_scalar_function_set) !=
          ownSizeof(struct_duckdb_scalar_function_set_2181038753):
        static:
          warning(
            "Declaration of " & "struct_duckdb_scalar_function_set" &
              " exists but with different size"
          )
      struct_duckdb_scalar_function_set
    else:
      struct_duckdb_scalar_function_set_2181038753
  )
  struct_duckdb_column_2181038646 = (
    when declared(struct_duckdb_column):
      when ownSizeof(struct_duckdb_column) != ownSizeof(struct_duckdb_column_2181038645):
        static:
          warning(
            "Declaration of " & "struct_duckdb_column" &
              " exists but with different size"
          )
      struct_duckdb_column
    else:
      struct_duckdb_column_2181038645
  )
  struct_duckdb_database_2181038682 = (
    when declared(struct_duckdb_database):
      when ownSizeof(struct_duckdb_database) !=
          ownSizeof(struct_duckdb_database_2181038681):
        static:
          warning(
            "Declaration of " & "struct_duckdb_database" &
              " exists but with different size"
          )
      struct_duckdb_database
    else:
      struct_duckdb_database_2181038681
  )
  duckdb_date_struct_2181038573 = (
    when declared(duckdb_date_struct):
      when ownSizeof(duckdb_date_struct) != ownSizeof(duckdb_date_struct_2181038572):
        static:
          warning(
            "Declaration of " & "duckdb_date_struct" & " exists but with different size"
          )
      duckdb_date_struct
    else:
      duckdb_date_struct_2181038572
  )
  duckdb_decimal_2181038632 = (
    when declared(duckdb_decimal):
      when ownSizeof(duckdb_decimal) != ownSizeof(duckdb_decimal_2181038631):
        static:
          warning(
            "Declaration of " & "duckdb_decimal" & " exists but with different size"
          )
      duckdb_decimal
    else:
      duckdb_decimal_2181038631
  )
  struct_duckdb_decimal_2181038630 = (
    when declared(struct_duckdb_decimal):
      when ownSizeof(struct_duckdb_decimal) !=
          ownSizeof(struct_duckdb_decimal_2181038629):
        static:
          warning(
            "Declaration of " & "struct_duckdb_decimal" &
              " exists but with different size"
          )
      struct_duckdb_decimal
    else:
      struct_duckdb_decimal_2181038629
  )
  struct_duckdb_cast_function_2181038800 = (
    when declared(struct_duckdb_cast_function):
      when ownSizeof(struct_duckdb_cast_function) !=
          ownSizeof(struct_duckdb_cast_function_2181038799):
        static:
          warning(
            "Declaration of " & "struct_duckdb_cast_function" &
              " exists but with different size"
          )
      struct_duckdb_cast_function
    else:
      struct_duckdb_cast_function_2181038799
  )
  duckdb_database_2181038684 = (
    when declared(duckdb_database):
      when ownSizeof(duckdb_database) != ownSizeof(duckdb_database_2181038683):
        static:
          warning(
            "Declaration of " & "duckdb_database" & " exists but with different size"
          )
      duckdb_database
    else:
      duckdb_database_2181038683
  )
  duckdb_aggregate_function_2181038764 = (
    when declared(duckdb_aggregate_function):
      when ownSizeof(duckdb_aggregate_function) !=
          ownSizeof(duckdb_aggregate_function_2181038763):
        static:
          warning(
            "Declaration of " & "duckdb_aggregate_function" &
              " exists but with different size"
          )
      duckdb_aggregate_function
    else:
      duckdb_aggregate_function_2181038763
  )
  duckdb_aggregate_function_set_2181038768 = (
    when declared(duckdb_aggregate_function_set):
      when ownSizeof(duckdb_aggregate_function_set) !=
          ownSizeof(duckdb_aggregate_function_set_2181038767):
        static:
          warning(
            "Declaration of " & "duckdb_aggregate_function_set" &
              " exists but with different size"
          )
      duckdb_aggregate_function_set
    else:
      duckdb_aggregate_function_set_2181038767
  )
  duckdb_arrow_2181038814 = (
    when declared(duckdb_arrow):
      when ownSizeof(duckdb_arrow) != ownSizeof(duckdb_arrow_2181038813):
        static:
          warning(
            "Declaration of " & "duckdb_arrow" & " exists but with different size"
          )
      duckdb_arrow
    else:
      duckdb_arrow_2181038813
  )
  sel_t_2181038561 = (
    when declared(sel_t):
      when ownSizeof(sel_t) != ownSizeof(sel_t_2181038560):
        static:
          warning("Declaration of " & "sel_t" & " exists but with different size")
      sel_t
    else:
      sel_t_2181038560
  )
  struct_duckdb_string_t_2181038638 = (
    when declared(struct_duckdb_string_t):
      when ownSizeof(struct_duckdb_string_t) !=
          ownSizeof(struct_duckdb_string_t_2181038637):
        static:
          warning(
            "Declaration of " & "struct_duckdb_string_t" &
              " exists but with different size"
          )
      struct_duckdb_string_t
    else:
      struct_duckdb_string_t_2181038637
  )
  struct_duckdb_data_chunk_2181038726 = (
    when declared(struct_duckdb_data_chunk):
      when ownSizeof(struct_duckdb_data_chunk) !=
          ownSizeof(struct_duckdb_data_chunk_2181038725):
        static:
          warning(
            "Declaration of " & "struct_duckdb_data_chunk" &
              " exists but with different size"
          )
      struct_duckdb_data_chunk
    else:
      struct_duckdb_data_chunk_2181038725
  )
  duckdb_arrow_stream_2181038818 = (
    when declared(duckdb_arrow_stream):
      when ownSizeof(duckdb_arrow_stream) != ownSizeof(duckdb_arrow_stream_2181038817):
        static:
          warning(
            "Declaration of " & "duckdb_arrow_stream" & " exists but with different size"
          )
      duckdb_arrow_stream
    else:
      duckdb_arrow_stream_2181038817
  )
  duckdb_cast_function_t_2181038804 = (
    when declared(duckdb_cast_function_t):
      when ownSizeof(duckdb_cast_function_t) !=
          ownSizeof(duckdb_cast_function_t_2181038803):
        static:
          warning(
            "Declaration of " & "duckdb_cast_function_t" &
              " exists but with different size"
          )
      duckdb_cast_function_t
    else:
      duckdb_cast_function_t_2181038803
  )
  idx_t_2181038559 = (
    when declared(idx_t):
      when ownSizeof(idx_t) != ownSizeof(idx_t_2181038558):
        static:
          warning("Declaration of " & "idx_t" & " exists but with different size")
      idx_t
    else:
      idx_t_2181038558
  )
  struct_duckdb_extracted_statements_2181038698 = (
    when declared(struct_duckdb_extracted_statements):
      when ownSizeof(struct_duckdb_extracted_statements) !=
          ownSizeof(struct_duckdb_extracted_statements_2181038697):
        static:
          warning(
            "Declaration of " & "struct_duckdb_extracted_statements" &
              " exists but with different size"
          )
      struct_duckdb_extracted_statements
    else:
      struct_duckdb_extracted_statements_2181038697
  )
  duckdb_instance_cache_2181038680 = (
    when declared(duckdb_instance_cache):
      when ownSizeof(duckdb_instance_cache) !=
          ownSizeof(duckdb_instance_cache_2181038679):
        static:
          warning(
            "Declaration of " & "duckdb_instance_cache" &
              " exists but with different size"
          )
      duckdb_instance_cache
    else:
      duckdb_instance_cache_2181038679
  )
  struct_duckdb_bind_info_2181038746 = (
    when declared(struct_duckdb_bind_info):
      when ownSizeof(struct_duckdb_bind_info) !=
          ownSizeof(struct_duckdb_bind_info_2181038745):
        static:
          warning(
            "Declaration of " & "struct_duckdb_bind_info" &
              " exists but with different size"
          )
      struct_duckdb_bind_info
    else:
      struct_duckdb_bind_info_2181038745
  )
  struct_duckdb_time_tz_2181038583 = (
    when declared(struct_duckdb_time_tz):
      when ownSizeof(struct_duckdb_time_tz) !=
          ownSizeof(struct_duckdb_time_tz_2181038582):
        static:
          warning(
            "Declaration of " & "struct_duckdb_time_tz" &
              " exists but with different size"
          )
      struct_duckdb_time_tz
    else:
      struct_duckdb_time_tz_2181038582
  )
  duckdb_uhugeint_2181038628 = (
    when declared(duckdb_uhugeint):
      when ownSizeof(duckdb_uhugeint) != ownSizeof(duckdb_uhugeint_2181038627):
        static:
          warning(
            "Declaration of " & "duckdb_uhugeint" & " exists but with different size"
          )
      duckdb_uhugeint
    else:
      duckdb_uhugeint_2181038627
  )
  struct_duckdb_timestamp_ns_2181038603 = (
    when declared(struct_duckdb_timestamp_ns):
      when ownSizeof(struct_duckdb_timestamp_ns) !=
          ownSizeof(struct_duckdb_timestamp_ns_2181038602):
        static:
          warning(
            "Declaration of " & "struct_duckdb_timestamp_ns" &
              " exists but with different size"
          )
      struct_duckdb_timestamp_ns
    else:
      struct_duckdb_timestamp_ns_2181038602
  )
  struct_duckdb_create_type_info_2181038722 = (
    when declared(struct_duckdb_create_type_info):
      when ownSizeof(struct_duckdb_create_type_info) !=
          ownSizeof(struct_duckdb_create_type_info_2181038721):
        static:
          warning(
            "Declaration of " & "struct_duckdb_create_type_info" &
              " exists but with different size"
          )
      struct_duckdb_create_type_info
    else:
      struct_duckdb_create_type_info_2181038721
  )
  duckdb_blob_2181038664 = (
    when declared(duckdb_blob):
      when ownSizeof(duckdb_blob) != ownSizeof(duckdb_blob_2181038663):
        static:
          warning("Declaration of " & "duckdb_blob" & " exists but with different size")
      duckdb_blob
    else:
      duckdb_blob_2181038663
  )
  duckdb_aggregate_init_t_2181038776 = (
    when declared(duckdb_aggregate_init_t):
      when ownSizeof(duckdb_aggregate_init_t) !=
          ownSizeof(duckdb_aggregate_init_t_2181038775):
        static:
          warning(
            "Declaration of " & "duckdb_aggregate_init_t" &
              " exists but with different size"
          )
      duckdb_aggregate_init_t
    else:
      duckdb_aggregate_init_t_2181038775
  )
  duckdb_type_2181038533 = (
    when declared(duckdb_type):
      when ownSizeof(duckdb_type) != ownSizeof(duckdb_type_2181038532):
        static:
          warning("Declaration of " & "duckdb_type" & " exists but with different size")
      duckdb_type
    else:
      duckdb_type_2181038532
  )
  struct_duckdb_string_2181038658 = (
    when declared(struct_duckdb_string):
      when ownSizeof(struct_duckdb_string) != ownSizeof(struct_duckdb_string_2181038657):
        static:
          warning(
            "Declaration of " & "struct_duckdb_string" &
              " exists but with different size"
          )
      struct_duckdb_string
    else:
      struct_duckdb_string_2181038657
  )
  struct_duckdb_client_context_2181038690 = (
    when declared(struct_duckdb_client_context):
      when ownSizeof(struct_duckdb_client_context) !=
          ownSizeof(struct_duckdb_client_context_2181038689):
        static:
          warning(
            "Declaration of " & "struct_duckdb_client_context" &
              " exists but with different size"
          )
      struct_duckdb_client_context
    else:
      struct_duckdb_client_context_2181038689
  )
  duckdb_varint_2181038672 = (
    when declared(duckdb_varint):
      when ownSizeof(duckdb_varint) != ownSizeof(duckdb_varint_2181038671):
        static:
          warning(
            "Declaration of " & "duckdb_varint" & " exists but with different size"
          )
      duckdb_varint
    else:
      duckdb_varint_2181038671
  )
  duckdb_table_function_t_2181038798 = (
    when declared(duckdb_table_function_t):
      when ownSizeof(duckdb_table_function_t) !=
          ownSizeof(duckdb_table_function_t_2181038797):
        static:
          warning(
            "Declaration of " & "duckdb_table_function_t" &
              " exists but with different size"
          )
      duckdb_table_function_t
    else:
      duckdb_table_function_t_2181038797
  )
  struct_duckdb_time_struct_2181038579 = (
    when declared(struct_duckdb_time_struct):
      when ownSizeof(struct_duckdb_time_struct) !=
          ownSizeof(struct_duckdb_time_struct_2181038578):
        static:
          warning(
            "Declaration of " & "struct_duckdb_time_struct" &
              " exists but with different size"
          )
      struct_duckdb_time_struct
    else:
      struct_duckdb_time_struct_2181038578
  )
  duckdb_task_state_2181038565 = (
    when declared(duckdb_task_state):
      when ownSizeof(duckdb_task_state) != ownSizeof(duckdb_task_state_2181038564):
        static:
          warning(
            "Declaration of " & "duckdb_task_state" & " exists but with different size"
          )
      duckdb_task_state
    else:
      duckdb_task_state_2181038564
  )
  duckdb_scalar_function_2181038752 = (
    when declared(duckdb_scalar_function):
      when ownSizeof(duckdb_scalar_function) !=
          ownSizeof(duckdb_scalar_function_2181038751):
        static:
          warning(
            "Declaration of " & "duckdb_scalar_function" &
              " exists but with different size"
          )
      duckdb_scalar_function
    else:
      duckdb_scalar_function_2181038751
  )
  struct_duckdb_query_progress_type_2181038634 = (
    when declared(struct_duckdb_query_progress_type):
      when ownSizeof(struct_duckdb_query_progress_type) !=
          ownSizeof(struct_duckdb_query_progress_type_2181038633):
        static:
          warning(
            "Declaration of " & "struct_duckdb_query_progress_type" &
              " exists but with different size"
          )
      struct_duckdb_query_progress_type
    else:
      struct_duckdb_query_progress_type_2181038633
  )
  enum_duckdb_error_type_2181038551 = (
    when declared(enum_duckdb_error_type):
      when ownSizeof(enum_duckdb_error_type) !=
          ownSizeof(enum_duckdb_error_type_2181038550):
        static:
          warning(
            "Declaration of " & "enum_duckdb_error_type" &
              " exists but with different size"
          )
      enum_duckdb_error_type
    else:
      enum_duckdb_error_type_2181038550
  )
  duckdb_timestamp_s_2181038597 = (
    when declared(duckdb_timestamp_s):
      when ownSizeof(duckdb_timestamp_s) != ownSizeof(duckdb_timestamp_s_2181038596):
        static:
          warning(
            "Declaration of " & "duckdb_timestamp_s" & " exists but with different size"
          )
      duckdb_timestamp_s
    else:
      duckdb_timestamp_s_2181038596
  )
  duckdb_pending_state_2181038541 = (
    when declared(duckdb_pending_state):
      when ownSizeof(duckdb_pending_state) != ownSizeof(duckdb_pending_state_2181038540):
        static:
          warning(
            "Declaration of " & "duckdb_pending_state" &
              " exists but with different size"
          )
      duckdb_pending_state
    else:
      duckdb_pending_state_2181038540
  )
  struct_duckdb_timestamp_2181038591 = (
    when declared(struct_duckdb_timestamp):
      when ownSizeof(struct_duckdb_timestamp) !=
          ownSizeof(struct_duckdb_timestamp_2181038590):
        static:
          warning(
            "Declaration of " & "struct_duckdb_timestamp" &
              " exists but with different size"
          )
      struct_duckdb_timestamp
    else:
      struct_duckdb_timestamp_2181038590
  )
  struct_duckdb_hugeint_2181038615 = (
    when declared(struct_duckdb_hugeint):
      when ownSizeof(struct_duckdb_hugeint) !=
          ownSizeof(struct_duckdb_hugeint_2181038614):
        static:
          warning(
            "Declaration of " & "struct_duckdb_hugeint" &
              " exists but with different size"
          )
      struct_duckdb_hugeint
    else:
      struct_duckdb_hugeint_2181038614
  )
  struct_duckdb_blob_2181038662 = (
    when declared(struct_duckdb_blob):
      when ownSizeof(struct_duckdb_blob) != ownSizeof(struct_duckdb_blob_2181038661):
        static:
          warning(
            "Declaration of " & "struct_duckdb_blob" & " exists but with different size"
          )
      struct_duckdb_blob
    else:
      struct_duckdb_blob_2181038661
  )
  enum_duckdb_state_2181038535 = (
    when declared(enum_duckdb_state):
      when ownSizeof(enum_duckdb_state) != ownSizeof(enum_duckdb_state_2181038534):
        static:
          warning(
            "Declaration of " & "enum_duckdb_state" & " exists but with different size"
          )
      enum_duckdb_state
    else:
      enum_duckdb_state_2181038534
  )
  duckdb_aggregate_combine_t_2181038782 = (
    when declared(duckdb_aggregate_combine_t):
      when ownSizeof(duckdb_aggregate_combine_t) !=
          ownSizeof(duckdb_aggregate_combine_t_2181038781):
        static:
          warning(
            "Declaration of " & "duckdb_aggregate_combine_t" &
              " exists but with different size"
          )
      duckdb_aggregate_combine_t
    else:
      duckdb_aggregate_combine_t_2181038781
  )
  struct_duckdb_selection_vector_2181038654 = (
    when declared(struct_duckdb_selection_vector):
      when ownSizeof(struct_duckdb_selection_vector) !=
          ownSizeof(struct_duckdb_selection_vector_2181038653):
        static:
          warning(
            "Declaration of " & "struct_duckdb_selection_vector" &
              " exists but with different size"
          )
      struct_duckdb_selection_vector
    else:
      struct_duckdb_selection_vector_2181038653
  )
  duckdb_table_function_bind_t_2181038794 = (
    when declared(duckdb_table_function_bind_t):
      when ownSizeof(duckdb_table_function_bind_t) !=
          ownSizeof(duckdb_table_function_bind_t_2181038793):
        static:
          warning(
            "Declaration of " & "duckdb_table_function_bind_t" &
              " exists but with different size"
          )
      duckdb_table_function_bind_t
    else:
      duckdb_table_function_bind_t_2181038793
  )
  struct_duckdb_instance_cache_2181038678 = (
    when declared(struct_duckdb_instance_cache):
      when ownSizeof(struct_duckdb_instance_cache) !=
          ownSizeof(struct_duckdb_instance_cache_2181038677):
        static:
          warning(
            "Declaration of " & "struct_duckdb_instance_cache" &
              " exists but with different size"
          )
      struct_duckdb_instance_cache
    else:
      struct_duckdb_instance_cache_2181038677
  )
  struct_duckdb_extension_access_2181038828 = (
    when declared(struct_duckdb_extension_access):
      when ownSizeof(struct_duckdb_extension_access) !=
          ownSizeof(struct_duckdb_extension_access_2181038827):
        static:
          warning(
            "Declaration of " & "struct_duckdb_extension_access" &
              " exists but with different size"
          )
      struct_duckdb_extension_access
    else:
      struct_duckdb_extension_access_2181038827
  )
  duckdb_scalar_function_set_2181038756 = (
    when declared(duckdb_scalar_function_set):
      when ownSizeof(duckdb_scalar_function_set) !=
          ownSizeof(duckdb_scalar_function_set_2181038755):
        static:
          warning(
            "Declaration of " & "duckdb_scalar_function_set" &
              " exists but with different size"
          )
      duckdb_scalar_function_set
    else:
      duckdb_scalar_function_set_2181038755
  )
  duckdb_value_2181038732 = (
    when declared(duckdb_value):
      when ownSizeof(duckdb_value) != ownSizeof(duckdb_value_2181038731):
        static:
          warning(
            "Declaration of " & "duckdb_value" & " exists but with different size"
          )
      duckdb_value
    else:
      duckdb_value_2181038731
  )
  duckdb_delete_callback_t_2181038563 = (
    when declared(duckdb_delete_callback_t):
      when ownSizeof(duckdb_delete_callback_t) !=
          ownSizeof(duckdb_delete_callback_t_2181038562):
        static:
          warning(
            "Declaration of " & "duckdb_delete_callback_t" &
              " exists but with different size"
          )
      duckdb_delete_callback_t
    else:
      duckdb_delete_callback_t_2181038562
  )
  duckdb_scalar_function_bind_t_2181038758 = (
    when declared(duckdb_scalar_function_bind_t):
      when ownSizeof(duckdb_scalar_function_bind_t) !=
          ownSizeof(duckdb_scalar_function_bind_t_2181038757):
        static:
          warning(
            "Declaration of " & "duckdb_scalar_function_bind_t" &
              " exists but with different size"
          )
      duckdb_scalar_function_bind_t
    else:
      duckdb_scalar_function_bind_t_2181038757
  )
  struct_duckdb_timestamp_ms_2181038599 = (
    when declared(struct_duckdb_timestamp_ms):
      when ownSizeof(struct_duckdb_timestamp_ms) !=
          ownSizeof(struct_duckdb_timestamp_ms_2181038598):
        static:
          warning(
            "Declaration of " & "struct_duckdb_timestamp_ms" &
              " exists but with different size"
          )
      struct_duckdb_timestamp_ms
    else:
      struct_duckdb_timestamp_ms_2181038598
  )
  duckdb_list_entry_2181038644 = (
    when declared(duckdb_list_entry):
      when ownSizeof(duckdb_list_entry) != ownSizeof(duckdb_list_entry_2181038643):
        static:
          warning(
            "Declaration of " & "duckdb_list_entry" & " exists but with different size"
          )
      duckdb_list_entry
    else:
      duckdb_list_entry_2181038643
  )
  struct_duckdb_scalar_function_2181038750 = (
    when declared(struct_duckdb_scalar_function):
      when ownSizeof(struct_duckdb_scalar_function) !=
          ownSizeof(struct_duckdb_scalar_function_2181038749):
        static:
          warning(
            "Declaration of " & "struct_duckdb_scalar_function" &
              " exists but with different size"
          )
      struct_duckdb_scalar_function
    else:
      struct_duckdb_scalar_function_2181038749
  )
  struct_duckdb_vector_2181038650 = (
    when declared(struct_duckdb_vector):
      when ownSizeof(struct_duckdb_vector) != ownSizeof(struct_duckdb_vector_2181038649):
        static:
          warning(
            "Declaration of " & "struct_duckdb_vector" &
              " exists but with different size"
          )
      struct_duckdb_vector
    else:
      struct_duckdb_vector_2181038649
  )
  struct_duckdb_interval_2181038611 = (
    when declared(struct_duckdb_interval):
      when ownSizeof(struct_duckdb_interval) !=
          ownSizeof(struct_duckdb_interval_2181038610):
        static:
          warning(
            "Declaration of " & "struct_duckdb_interval" &
              " exists but with different size"
          )
      struct_duckdb_interval
    else:
      struct_duckdb_interval_2181038610
  )
  duckdb_bit_2181038668 = (
    when declared(duckdb_bit):
      when ownSizeof(duckdb_bit) != ownSizeof(duckdb_bit_2181038667):
        static:
          warning("Declaration of " & "duckdb_bit" & " exists but with different size")
      duckdb_bit
    else:
      duckdb_bit_2181038667
  )
  struct_duckdb_arrow_2181038812 = (
    when declared(struct_duckdb_arrow):
      when ownSizeof(struct_duckdb_arrow) != ownSizeof(struct_duckdb_arrow_2181038811):
        static:
          warning(
            "Declaration of " & "struct_duckdb_arrow" & " exists but with different size"
          )
      struct_duckdb_arrow
    else:
      struct_duckdb_arrow_2181038811
  )
  duckdb_timestamp_struct_2181038609 = (
    when declared(duckdb_timestamp_struct):
      when ownSizeof(duckdb_timestamp_struct) !=
          ownSizeof(duckdb_timestamp_struct_2181038608):
        static:
          warning(
            "Declaration of " & "duckdb_timestamp_struct" &
              " exists but with different size"
          )
      duckdb_timestamp_struct
    else:
      duckdb_timestamp_struct_2181038608
  )
  duckdb_query_progress_type_2181038636 = (
    when declared(duckdb_query_progress_type):
      when ownSizeof(duckdb_query_progress_type) !=
          ownSizeof(duckdb_query_progress_type_2181038635):
        static:
          warning(
            "Declaration of " & "duckdb_query_progress_type" &
              " exists but with different size"
          )
      duckdb_query_progress_type
    else:
      duckdb_query_progress_type_2181038635
  )
  duckdb_init_info_2181038792 = (
    when declared(duckdb_init_info):
      when ownSizeof(duckdb_init_info) != ownSizeof(duckdb_init_info_2181038791):
        static:
          warning(
            "Declaration of " & "duckdb_init_info" & " exists but with different size"
          )
      duckdb_init_info
    else:
      duckdb_init_info_2181038791
  )
  duckdb_table_function_2181038788 = (
    when declared(duckdb_table_function):
      when ownSizeof(duckdb_table_function) !=
          ownSizeof(duckdb_table_function_2181038787):
        static:
          warning(
            "Declaration of " & "duckdb_table_function" &
              " exists but with different size"
          )
      duckdb_table_function
    else:
      duckdb_table_function_2181038787
  )
  duckdb_replacement_scan_info_2181038808 = (
    when declared(duckdb_replacement_scan_info):
      when ownSizeof(duckdb_replacement_scan_info) !=
          ownSizeof(duckdb_replacement_scan_info_2181038807):
        static:
          warning(
            "Declaration of " & "duckdb_replacement_scan_info" &
              " exists but with different size"
          )
      duckdb_replacement_scan_info
    else:
      duckdb_replacement_scan_info_2181038807
  )
  struct_duckdb_prepared_statement_2181038694 = (
    when declared(struct_duckdb_prepared_statement):
      when ownSizeof(struct_duckdb_prepared_statement) !=
          ownSizeof(struct_duckdb_prepared_statement_2181038693):
        static:
          warning(
            "Declaration of " & "struct_duckdb_prepared_statement" &
              " exists but with different size"
          )
      struct_duckdb_prepared_statement
    else:
      struct_duckdb_prepared_statement_2181038693
  )
  duckdb_replacement_callback_t_2181038810 = (
    when declared(duckdb_replacement_callback_t):
      when ownSizeof(duckdb_replacement_callback_t) !=
          ownSizeof(duckdb_replacement_callback_t_2181038809):
        static:
          warning(
            "Declaration of " & "duckdb_replacement_callback_t" &
              " exists but with different size"
          )
      duckdb_replacement_callback_t
    else:
      duckdb_replacement_callback_t_2181038809
  )
  duckdb_logical_type_2181038720 = (
    when declared(duckdb_logical_type):
      when ownSizeof(duckdb_logical_type) != ownSizeof(duckdb_logical_type_2181038719):
        static:
          warning(
            "Declaration of " & "duckdb_logical_type" & " exists but with different size"
          )
      duckdb_logical_type
    else:
      duckdb_logical_type_2181038719
  )
  duckdb_profiling_info_2181038736 = (
    when declared(duckdb_profiling_info):
      when ownSizeof(duckdb_profiling_info) !=
          ownSizeof(duckdb_profiling_info_2181038735):
        static:
          warning(
            "Declaration of " & "duckdb_profiling_info" &
              " exists but with different size"
          )
      duckdb_profiling_info
    else:
      duckdb_profiling_info_2181038735
  )
  duckdb_date_2181038569 = (
    when declared(duckdb_date):
      when ownSizeof(duckdb_date) != ownSizeof(duckdb_date_2181038568):
        static:
          warning("Declaration of " & "duckdb_date" & " exists but with different size")
      duckdb_date
    else:
      duckdb_date_2181038568
  )
  duckdb_table_description_2181038712 = (
    when declared(duckdb_table_description):
      when ownSizeof(duckdb_table_description) !=
          ownSizeof(duckdb_table_description_2181038711):
        static:
          warning(
            "Declaration of " & "duckdb_table_description" &
              " exists but with different size"
          )
      duckdb_table_description
    else:
      duckdb_table_description_2181038711
  )
  struct_duckdb_timestamp_s_2181038595 = (
    when declared(struct_duckdb_timestamp_s):
      when ownSizeof(struct_duckdb_timestamp_s) !=
          ownSizeof(struct_duckdb_timestamp_s_2181038594):
        static:
          warning(
            "Declaration of " & "struct_duckdb_timestamp_s" &
              " exists but with different size"
          )
      struct_duckdb_timestamp_s
    else:
      struct_duckdb_timestamp_s_2181038594
  )
  duckdb_connection_2181038688 = (
    when declared(duckdb_connection):
      when ownSizeof(duckdb_connection) != ownSizeof(duckdb_connection_2181038687):
        static:
          warning(
            "Declaration of " & "duckdb_connection" & " exists but with different size"
          )
      duckdb_connection
    else:
      duckdb_connection_2181038687
  )
  struct_duckdb_date_struct_2181038571 = (
    when declared(struct_duckdb_date_struct):
      when ownSizeof(struct_duckdb_date_struct) !=
          ownSizeof(struct_duckdb_date_struct_2181038570):
        static:
          warning(
            "Declaration of " & "struct_duckdb_date_struct" &
              " exists but with different size"
          )
      struct_duckdb_date_struct
    else:
      struct_duckdb_date_struct_2181038570
  )
  struct_duckdb_arrow_schema_2181038820 = (
    when declared(struct_duckdb_arrow_schema):
      when ownSizeof(struct_duckdb_arrow_schema) !=
          ownSizeof(struct_duckdb_arrow_schema_2181038819):
        static:
          warning(
            "Declaration of " & "struct_duckdb_arrow_schema" &
              " exists but with different size"
          )
      struct_duckdb_arrow_schema
    else:
      struct_duckdb_arrow_schema_2181038819
  )
  duckdb_time_tz_2181038585 = (
    when declared(duckdb_time_tz):
      when ownSizeof(duckdb_time_tz) != ownSizeof(duckdb_time_tz_2181038584):
        static:
          warning(
            "Declaration of " & "duckdb_time_tz" & " exists but with different size"
          )
      duckdb_time_tz
    else:
      duckdb_time_tz_2181038584
  )
  struct_duckdb_aggregate_function_2181038762 = (
    when declared(struct_duckdb_aggregate_function):
      when ownSizeof(struct_duckdb_aggregate_function) !=
          ownSizeof(struct_duckdb_aggregate_function_2181038761):
        static:
          warning(
            "Declaration of " & "struct_duckdb_aggregate_function" &
              " exists but with different size"
          )
      struct_duckdb_aggregate_function
    else:
      struct_duckdb_aggregate_function_2181038761
  )
  enum_duckdb_statement_type_2181038547 = (
    when declared(enum_duckdb_statement_type):
      when ownSizeof(enum_duckdb_statement_type) !=
          ownSizeof(enum_duckdb_statement_type_2181038546):
        static:
          warning(
            "Declaration of " & "enum_duckdb_statement_type" &
              " exists but with different size"
          )
      enum_duckdb_statement_type
    else:
      enum_duckdb_statement_type_2181038546
  )
  duckdb_vector_2181038652 = (
    when declared(duckdb_vector):
      when ownSizeof(duckdb_vector) != ownSizeof(duckdb_vector_2181038651):
        static:
          warning(
            "Declaration of " & "duckdb_vector" & " exists but with different size"
          )
      duckdb_vector
    else:
      duckdb_vector_2181038651
  )
  struct_duckdb_table_description_2181038710 = (
    when declared(struct_duckdb_table_description):
      when ownSizeof(struct_duckdb_table_description) !=
          ownSizeof(struct_duckdb_table_description_2181038709):
        static:
          warning(
            "Declaration of " & "struct_duckdb_table_description" &
              " exists but with different size"
          )
      struct_duckdb_table_description
    else:
      struct_duckdb_table_description_2181038709
  )
  duckdb_interval_2181038613 = (
    when declared(duckdb_interval):
      when ownSizeof(duckdb_interval) != ownSizeof(duckdb_interval_2181038612):
        static:
          warning(
            "Declaration of " & "duckdb_interval" & " exists but with different size"
          )
      duckdb_interval
    else:
      duckdb_interval_2181038612
  )
  duckdb_client_context_2181038692 = (
    when declared(duckdb_client_context):
      when ownSizeof(duckdb_client_context) !=
          ownSizeof(duckdb_client_context_2181038691):
        static:
          warning(
            "Declaration of " & "duckdb_client_context" &
              " exists but with different size"
          )
      duckdb_client_context
    else:
      duckdb_client_context_2181038691
  )
  duckdb_pending_result_2181038704 = (
    when declared(duckdb_pending_result):
      when ownSizeof(duckdb_pending_result) !=
          ownSizeof(duckdb_pending_result_2181038703):
        static:
          warning(
            "Declaration of " & "duckdb_pending_result" &
              " exists but with different size"
          )
      duckdb_pending_result
    else:
      duckdb_pending_result_2181038703
  )
  duckdb_create_type_info_2181038724 = (
    when declared(duckdb_create_type_info):
      when ownSizeof(duckdb_create_type_info) !=
          ownSizeof(duckdb_create_type_info_2181038723):
        static:
          warning(
            "Declaration of " & "duckdb_create_type_info" &
              " exists but with different size"
          )
      duckdb_create_type_info
    else:
      duckdb_create_type_info_2181038723
  )
  struct_duckdb_aggregate_state_2181038770 = (
    when declared(struct_duckdb_aggregate_state):
      when ownSizeof(struct_duckdb_aggregate_state) !=
          ownSizeof(struct_duckdb_aggregate_state_2181038769):
        static:
          warning(
            "Declaration of " & "struct_duckdb_aggregate_state" &
              " exists but with different size"
          )
      struct_duckdb_aggregate_state
    else:
      struct_duckdb_aggregate_state_2181038769
  )
  enum_duckdb_pending_state_2181038539 = (
    when declared(enum_duckdb_pending_state):
      when ownSizeof(enum_duckdb_pending_state) !=
          ownSizeof(enum_duckdb_pending_state_2181038538):
        static:
          warning(
            "Declaration of " & "enum_duckdb_pending_state" &
              " exists but with different size"
          )
      enum_duckdb_pending_state
    else:
      enum_duckdb_pending_state_2181038538
  )
  duckdb_string_2181038660 = (
    when declared(duckdb_string):
      when ownSizeof(duckdb_string) != ownSizeof(duckdb_string_2181038659):
        static:
          warning(
            "Declaration of " & "duckdb_string" & " exists but with different size"
          )
      duckdb_string
    else:
      duckdb_string_2181038659
  )
  duckdb_config_2181038716 = (
    when declared(duckdb_config):
      when ownSizeof(duckdb_config) != ownSizeof(duckdb_config_2181038715):
        static:
          warning(
            "Declaration of " & "duckdb_config" & " exists but with different size"
          )
      duckdb_config
    else:
      duckdb_config_2181038715
  )
  duckdb_prepared_statement_2181038696 = (
    when declared(duckdb_prepared_statement):
      when ownSizeof(duckdb_prepared_statement) !=
          ownSizeof(duckdb_prepared_statement_2181038695):
        static:
          warning(
            "Declaration of " & "duckdb_prepared_statement" &
              " exists but with different size"
          )
      duckdb_prepared_statement
    else:
      duckdb_prepared_statement_2181038695
  )
  duckdb_aggregate_update_t_2181038780 = (
    when declared(duckdb_aggregate_update_t):
      when ownSizeof(duckdb_aggregate_update_t) !=
          ownSizeof(duckdb_aggregate_update_t_2181038779):
        static:
          warning(
            "Declaration of " & "duckdb_aggregate_update_t" &
              " exists but with different size"
          )
      duckdb_aggregate_update_t
    else:
      duckdb_aggregate_update_t_2181038779
  )
  struct_duckdb_pending_result_2181038702 = (
    when declared(struct_duckdb_pending_result):
      when ownSizeof(struct_duckdb_pending_result) !=
          ownSizeof(struct_duckdb_pending_result_2181038701):
        static:
          warning(
            "Declaration of " & "struct_duckdb_pending_result" &
              " exists but with different size"
          )
      struct_duckdb_pending_result
    else:
      struct_duckdb_pending_result_2181038701
  )
  duckdb_bind_info_2181038748 = (
    when declared(duckdb_bind_info):
      when ownSizeof(duckdb_bind_info) != ownSizeof(duckdb_bind_info_2181038747):
        static:
          warning(
            "Declaration of " & "duckdb_bind_info" & " exists but with different size"
          )
      duckdb_bind_info
    else:
      duckdb_bind_info_2181038747
  )
  struct_duckdb_result_2181038674 = (
    when declared(struct_duckdb_result):
      when ownSizeof(struct_duckdb_result) != ownSizeof(struct_duckdb_result_2181038673):
        static:
          warning(
            "Declaration of " & "struct_duckdb_result" &
              " exists but with different size"
          )
      struct_duckdb_result
    else:
      struct_duckdb_result_2181038673
  )
  duckdb_time_tz_struct_2181038589 = (
    when declared(duckdb_time_tz_struct):
      when ownSizeof(duckdb_time_tz_struct) !=
          ownSizeof(duckdb_time_tz_struct_2181038588):
        static:
          warning(
            "Declaration of " & "duckdb_time_tz_struct" &
              " exists but with different size"
          )
      duckdb_time_tz_struct
    else:
      duckdb_time_tz_struct_2181038588
  )
  duckdb_aggregate_destroy_t_2181038778 = (
    when declared(duckdb_aggregate_destroy_t):
      when ownSizeof(duckdb_aggregate_destroy_t) !=
          ownSizeof(duckdb_aggregate_destroy_t_2181038777):
        static:
          warning(
            "Declaration of " & "duckdb_aggregate_destroy_t" &
              " exists but with different size"
          )
      duckdb_aggregate_destroy_t
    else:
      duckdb_aggregate_destroy_t_2181038777
  )
  struct_duckdb_profiling_info_2181038734 = (
    when declared(struct_duckdb_profiling_info):
      when ownSizeof(struct_duckdb_profiling_info) !=
          ownSizeof(struct_duckdb_profiling_info_2181038733):
        static:
          warning(
            "Declaration of " & "struct_duckdb_profiling_info" &
              " exists but with different size"
          )
      struct_duckdb_profiling_info
    else:
      struct_duckdb_profiling_info_2181038733
  )
  duckdb_cast_function_2181038802 = (
    when declared(duckdb_cast_function):
      when ownSizeof(duckdb_cast_function) != ownSizeof(duckdb_cast_function_2181038801):
        static:
          warning(
            "Declaration of " & "duckdb_cast_function" &
              " exists but with different size"
          )
      duckdb_cast_function
    else:
      duckdb_cast_function_2181038801
  )
  duckdb_timestamp_2181038593 = (
    when declared(duckdb_timestamp):
      when ownSizeof(duckdb_timestamp) != ownSizeof(duckdb_timestamp_2181038592):
        static:
          warning(
            "Declaration of " & "duckdb_timestamp" & " exists but with different size"
          )
      duckdb_timestamp
    else:
      duckdb_timestamp_2181038592
  )
  struct_duckdb_extension_info_2181038738 = (
    when declared(struct_duckdb_extension_info):
      when ownSizeof(struct_duckdb_extension_info) !=
          ownSizeof(struct_duckdb_extension_info_2181038737):
        static:
          warning(
            "Declaration of " & "struct_duckdb_extension_info" &
              " exists but with different size"
          )
      struct_duckdb_extension_info
    else:
      struct_duckdb_extension_info_2181038737
  )
  duckdb_aggregate_state_2181038772 = (
    when declared(duckdb_aggregate_state):
      when ownSizeof(duckdb_aggregate_state) !=
          ownSizeof(duckdb_aggregate_state_2181038771):
        static:
          warning(
            "Declaration of " & "duckdb_aggregate_state" &
              " exists but with different size"
          )
      duckdb_aggregate_state
    else:
      duckdb_aggregate_state_2181038771
  )
  duckdb_time_struct_2181038581 = (
    when declared(duckdb_time_struct):
      when ownSizeof(duckdb_time_struct) != ownSizeof(duckdb_time_struct_2181038580):
        static:
          warning(
            "Declaration of " & "duckdb_time_struct" & " exists but with different size"
          )
      duckdb_time_struct
    else:
      duckdb_time_struct_2181038580
  )
  duckdb_statement_type_2181038549 = (
    when declared(duckdb_statement_type):
      when ownSizeof(duckdb_statement_type) !=
          ownSizeof(duckdb_statement_type_2181038548):
        static:
          warning(
            "Declaration of " & "duckdb_statement_type" &
              " exists but with different size"
          )
      duckdb_statement_type
    else:
      duckdb_statement_type_2181038548
  )
  struct_duckdb_uhugeint_2181038626 = (
    when declared(struct_duckdb_uhugeint):
      when ownSizeof(struct_duckdb_uhugeint) !=
          ownSizeof(struct_duckdb_uhugeint_2181038618):
        static:
          warning(
            "Declaration of " & "struct_duckdb_uhugeint" &
              " exists but with different size"
          )
      struct_duckdb_uhugeint
    else:
      struct_duckdb_uhugeint_2181038618
  )
  duckdb_column_2181038648 = (
    when declared(duckdb_column):
      when ownSizeof(duckdb_column) != ownSizeof(duckdb_column_2181038647):
        static:
          warning(
            "Declaration of " & "duckdb_column" & " exists but with different size"
          )
      duckdb_column
    else:
      duckdb_column_2181038647
  )
  struct_duckdb_replacement_scan_info_2181038806 = (
    when declared(struct_duckdb_replacement_scan_info):
      when ownSizeof(struct_duckdb_replacement_scan_info) !=
          ownSizeof(struct_duckdb_replacement_scan_info_2181038805):
        static:
          warning(
            "Declaration of " & "struct_duckdb_replacement_scan_info" &
              " exists but with different size"
          )
      struct_duckdb_replacement_scan_info
    else:
      struct_duckdb_replacement_scan_info_2181038805
  )
  duckdb_selection_vector_2181038656 = (
    when declared(duckdb_selection_vector):
      when ownSizeof(duckdb_selection_vector) !=
          ownSizeof(duckdb_selection_vector_2181038655):
        static:
          warning(
            "Declaration of " & "duckdb_selection_vector" &
              " exists but with different size"
          )
      duckdb_selection_vector
    else:
      duckdb_selection_vector_2181038655
  )
  duckdb_result_2181038676 = (
    when declared(duckdb_result):
      when ownSizeof(duckdb_result) != ownSizeof(duckdb_result_2181038675):
        static:
          warning(
            "Declaration of " & "duckdb_result" & " exists but with different size"
          )
      duckdb_result
    else:
      duckdb_result_2181038675
  )
  duckdb_aggregate_state_size_2181038774 = (
    when declared(duckdb_aggregate_state_size):
      when ownSizeof(duckdb_aggregate_state_size) !=
          ownSizeof(duckdb_aggregate_state_size_2181038773):
        static:
          warning(
            "Declaration of " & "duckdb_aggregate_state_size" &
              " exists but with different size"
          )
      duckdb_aggregate_state_size
    else:
      duckdb_aggregate_state_size_2181038773
  )
  struct_duckdb_arrow_stream_2181038816 = (
    when declared(struct_duckdb_arrow_stream):
      when ownSizeof(struct_duckdb_arrow_stream) !=
          ownSizeof(struct_duckdb_arrow_stream_2181038815):
        static:
          warning(
            "Declaration of " & "struct_duckdb_arrow_stream" &
              " exists but with different size"
          )
      struct_duckdb_arrow_stream
    else:
      struct_duckdb_arrow_stream_2181038815
  )
  duckdb_scalar_function_t_2181038760 = (
    when declared(duckdb_scalar_function_t):
      when ownSizeof(duckdb_scalar_function_t) !=
          ownSizeof(duckdb_scalar_function_t_2181038759):
        static:
          warning(
            "Declaration of " & "duckdb_scalar_function_t" &
              " exists but with different size"
          )
      duckdb_scalar_function_t
    else:
      duckdb_scalar_function_t_2181038759
  )
  duckdb_cast_mode_2181038557 = (
    when declared(duckdb_cast_mode):
      when ownSizeof(duckdb_cast_mode) != ownSizeof(duckdb_cast_mode_2181038556):
        static:
          warning(
            "Declaration of " & "duckdb_cast_mode" & " exists but with different size"
          )
      duckdb_cast_mode
    else:
      duckdb_cast_mode_2181038556
  )
  struct_duckdb_aggregate_function_set_2181038766 = (
    when declared(struct_duckdb_aggregate_function_set):
      when ownSizeof(struct_duckdb_aggregate_function_set) !=
          ownSizeof(struct_duckdb_aggregate_function_set_2181038765):
        static:
          warning(
            "Declaration of " & "struct_duckdb_aggregate_function_set" &
              " exists but with different size"
          )
      struct_duckdb_aggregate_function_set
    else:
      struct_duckdb_aggregate_function_set_2181038765
  )
  struct_duckdb_time_2181038575 = (
    when declared(struct_duckdb_time):
      when ownSizeof(struct_duckdb_time) != ownSizeof(struct_duckdb_time_2181038574):
        static:
          warning(
            "Declaration of " & "struct_duckdb_time" & " exists but with different size"
          )
      struct_duckdb_time
    else:
      struct_duckdb_time_2181038574
  )
  struct_duckdb_time_tz_struct_2181038587 = (
    when declared(struct_duckdb_time_tz_struct):
      when ownSizeof(struct_duckdb_time_tz_struct) !=
          ownSizeof(struct_duckdb_time_tz_struct_2181038586):
        static:
          warning(
            "Declaration of " & "struct_duckdb_time_tz_struct" &
              " exists but with different size"
          )
      struct_duckdb_time_tz_struct
    else:
      struct_duckdb_time_tz_struct_2181038586
  )
  duckdb_timestamp_ns_2181038605 = (
    when declared(duckdb_timestamp_ns):
      when ownSizeof(duckdb_timestamp_ns) != ownSizeof(duckdb_timestamp_ns_2181038604):
        static:
          warning(
            "Declaration of " & "duckdb_timestamp_ns" & " exists but with different size"
          )
      duckdb_timestamp_ns
    else:
      duckdb_timestamp_ns_2181038604
  )
  duckdb_string_t_2181038640 = (
    when declared(duckdb_string_t):
      when ownSizeof(duckdb_string_t) != ownSizeof(duckdb_string_t_2181038639):
        static:
          warning(
            "Declaration of " & "duckdb_string_t" & " exists but with different size"
          )
      duckdb_string_t
    else:
      duckdb_string_t_2181038639
  )
  struct_duckdb_table_function_2181038786 = (
    when declared(struct_duckdb_table_function):
      when ownSizeof(struct_duckdb_table_function) !=
          ownSizeof(struct_duckdb_table_function_2181038785):
        static:
          warning(
            "Declaration of " & "struct_duckdb_table_function" &
              " exists but with different size"
          )
      struct_duckdb_table_function
    else:
      struct_duckdb_table_function_2181038785
  )
  struct_duckdb_arrow_array_2181038824 = (
    when declared(struct_duckdb_arrow_array):
      when ownSizeof(struct_duckdb_arrow_array) !=
          ownSizeof(struct_duckdb_arrow_array_2181038823):
        static:
          warning(
            "Declaration of " & "struct_duckdb_arrow_array" &
              " exists but with different size"
          )
      struct_duckdb_arrow_array
    else:
      struct_duckdb_arrow_array_2181038823
  )
  duckdb_extension_info_2181038740 = (
    when declared(duckdb_extension_info):
      when ownSizeof(duckdb_extension_info) !=
          ownSizeof(duckdb_extension_info_2181038739):
        static:
          warning(
            "Declaration of " & "duckdb_extension_info" &
              " exists but with different size"
          )
      duckdb_extension_info
    else:
      duckdb_extension_info_2181038739
  )
  struct_duckdb_init_info_2181038790 = (
    when declared(struct_duckdb_init_info):
      when ownSizeof(struct_duckdb_init_info) !=
          ownSizeof(struct_duckdb_init_info_2181038789):
        static:
          warning(
            "Declaration of " & "struct_duckdb_init_info" &
              " exists but with different size"
          )
      struct_duckdb_init_info
    else:
      struct_duckdb_init_info_2181038789
  )
  struct_duckdb_connection_2181038686 = (
    when declared(struct_duckdb_connection):
      when ownSizeof(struct_duckdb_connection) !=
          ownSizeof(struct_duckdb_connection_2181038685):
        static:
          warning(
            "Declaration of " & "struct_duckdb_connection" &
              " exists but with different size"
          )
      struct_duckdb_connection
    else:
      struct_duckdb_connection_2181038685
  )
  struct_duckdb_logical_type_2181038718 = (
    when declared(struct_duckdb_logical_type):
      when ownSizeof(struct_duckdb_logical_type) !=
          ownSizeof(struct_duckdb_logical_type_2181038717):
        static:
          warning(
            "Declaration of " & "struct_duckdb_logical_type" &
              " exists but with different size"
          )
      struct_duckdb_logical_type
    else:
      struct_duckdb_logical_type_2181038717
  )
  struct_duckdb_date_2181038567 = (
    when declared(struct_duckdb_date):
      when ownSizeof(struct_duckdb_date) != ownSizeof(struct_duckdb_date_2181038566):
        static:
          warning(
            "Declaration of " & "struct_duckdb_date" & " exists but with different size"
          )
      struct_duckdb_date
    else:
      struct_duckdb_date_2181038566
  )
  duckdb_aggregate_finalize_t_2181038784 = (
    when declared(duckdb_aggregate_finalize_t):
      when ownSizeof(duckdb_aggregate_finalize_t) !=
          ownSizeof(duckdb_aggregate_finalize_t_2181038783):
        static:
          warning(
            "Declaration of " & "duckdb_aggregate_finalize_t" &
              " exists but with different size"
          )
      duckdb_aggregate_finalize_t
    else:
      duckdb_aggregate_finalize_t_2181038783
  )
  struct_duckdb_value_2181038730 = (
    when declared(struct_duckdb_value):
      when ownSizeof(struct_duckdb_value) != ownSizeof(struct_duckdb_value_2181038729):
        static:
          warning(
            "Declaration of " & "struct_duckdb_value" & " exists but with different size"
          )
      struct_duckdb_value
    else:
      struct_duckdb_value_2181038729
  )
  duckdb_arrow_schema_2181038822 = (
    when declared(duckdb_arrow_schema):
      when ownSizeof(duckdb_arrow_schema) != ownSizeof(duckdb_arrow_schema_2181038821):
        static:
          warning(
            "Declaration of " & "duckdb_arrow_schema" & " exists but with different size"
          )
      duckdb_arrow_schema
    else:
      duckdb_arrow_schema_2181038821
  )
  struct_duckdb_config_2181038714 = (
    when declared(struct_duckdb_config):
      when ownSizeof(struct_duckdb_config) != ownSizeof(struct_duckdb_config_2181038713):
        static:
          warning(
            "Declaration of " & "struct_duckdb_config" &
              " exists but with different size"
          )
      struct_duckdb_config
    else:
      struct_duckdb_config_2181038713
  )
  struct_duckdb_bit_2181038666 = (
    when declared(struct_duckdb_bit):
      when ownSizeof(struct_duckdb_bit) != ownSizeof(struct_duckdb_bit_2181038665):
        static:
          warning(
            "Declaration of " & "struct_duckdb_bit" & " exists but with different size"
          )
      struct_duckdb_bit
    else:
      struct_duckdb_bit_2181038665
  )
  struct_duckdb_list_entry_2181038642 = (
    when declared(struct_duckdb_list_entry):
      when ownSizeof(struct_duckdb_list_entry) !=
          ownSizeof(struct_duckdb_list_entry_2181038641):
        static:
          warning(
            "Declaration of " & "struct_duckdb_list_entry" &
              " exists but with different size"
          )
      struct_duckdb_list_entry
    else:
      struct_duckdb_list_entry_2181038641
  )
  struct_duckdb_appender_2181038706 = (
    when declared(struct_duckdb_appender):
      when ownSizeof(struct_duckdb_appender) !=
          ownSizeof(struct_duckdb_appender_2181038705):
        static:
          warning(
            "Declaration of " & "struct_duckdb_appender" &
              " exists but with different size"
          )
      struct_duckdb_appender
    else:
      struct_duckdb_appender_2181038705
  )
  duckdb_table_function_init_t_2181038796 = (
    when declared(duckdb_table_function_init_t):
      when ownSizeof(duckdb_table_function_init_t) !=
          ownSizeof(duckdb_table_function_init_t_2181038795):
        static:
          warning(
            "Declaration of " & "duckdb_table_function_init_t" &
              " exists but with different size"
          )
      duckdb_table_function_init_t
    else:
      duckdb_table_function_init_t_2181038795
  )
  duckdb_data_chunk_2181038728 = (
    when declared(duckdb_data_chunk):
      when ownSizeof(duckdb_data_chunk) != ownSizeof(duckdb_data_chunk_2181038727):
        static:
          warning(
            "Declaration of " & "duckdb_data_chunk" & " exists but with different size"
          )
      duckdb_data_chunk
    else:
      duckdb_data_chunk_2181038727
  )
  struct_duckdb_timestamp_struct_2181038607 = (
    when declared(struct_duckdb_timestamp_struct):
      when ownSizeof(struct_duckdb_timestamp_struct) !=
          ownSizeof(struct_duckdb_timestamp_struct_2181038606):
        static:
          warning(
            "Declaration of " & "struct_duckdb_timestamp_struct" &
              " exists but with different size"
          )
      struct_duckdb_timestamp_struct
    else:
      struct_duckdb_timestamp_struct_2181038606
  )
  duckdb_timestamp_ms_2181038601 = (
    when declared(duckdb_timestamp_ms):
      when ownSizeof(duckdb_timestamp_ms) != ownSizeof(duckdb_timestamp_ms_2181038600):
        static:
          warning(
            "Declaration of " & "duckdb_timestamp_ms" & " exists but with different size"
          )
      duckdb_timestamp_ms
    else:
      duckdb_timestamp_ms_2181038600
  )
  duckdb_arrow_array_2181038826 = (
    when declared(duckdb_arrow_array):
      when ownSizeof(duckdb_arrow_array) != ownSizeof(duckdb_arrow_array_2181038825):
        static:
          warning(
            "Declaration of " & "duckdb_arrow_array" & " exists but with different size"
          )
      duckdb_arrow_array
    else:
      duckdb_arrow_array_2181038825
  )
  duckdb_appender_2181038708 = (
    when declared(duckdb_appender):
      when ownSizeof(duckdb_appender) != ownSizeof(duckdb_appender_2181038707):
        static:
          warning(
            "Declaration of " & "duckdb_appender" & " exists but with different size"
          )
      duckdb_appender
    else:
      duckdb_appender_2181038707
  )
  duckdb_error_type_2181038553 = (
    when declared(duckdb_error_type):
      when ownSizeof(duckdb_error_type) != ownSizeof(duckdb_error_type_2181038552):
        static:
          warning(
            "Declaration of " & "duckdb_error_type" & " exists but with different size"
          )
      duckdb_error_type
    else:
      duckdb_error_type_2181038552
  )
  duckdb_extracted_statements_2181038700 = (
    when declared(duckdb_extracted_statements):
      when ownSizeof(duckdb_extracted_statements) !=
          ownSizeof(duckdb_extracted_statements_2181038699):
        static:
          warning(
            "Declaration of " & "duckdb_extracted_statements" &
              " exists but with different size"
          )
      duckdb_extracted_statements
    else:
      duckdb_extracted_statements_2181038699
  )
  struct_duckdb_function_info_2181038742 = (
    when declared(struct_duckdb_function_info):
      when ownSizeof(struct_duckdb_function_info) !=
          ownSizeof(struct_duckdb_function_info_2181038741):
        static:
          warning(
            "Declaration of " & "struct_duckdb_function_info" &
              " exists but with different size"
          )
      struct_duckdb_function_info
    else:
      struct_duckdb_function_info_2181038741
  )
  enum_DUCKDB_TYPE_2181038531 = (
    when declared(enum_DUCKDB_TYPE):
      when ownSizeof(enum_DUCKDB_TYPE) != ownSizeof(enum_DUCKDB_TYPE_2181038529):
        static:
          warning(
            "Declaration of " & "enum_DUCKDB_TYPE" & " exists but with different size"
          )
      enum_DUCKDB_TYPE
    else:
      enum_DUCKDB_TYPE_2181038529
  )
  struct_duckdb_varint_2181038670 = (
    when declared(struct_duckdb_varint):
      when ownSizeof(struct_duckdb_varint) != ownSizeof(struct_duckdb_varint_2181038669):
        static:
          warning(
            "Declaration of " & "struct_duckdb_varint" &
              " exists but with different size"
          )
      struct_duckdb_varint
    else:
      struct_duckdb_varint_2181038669
  )
  duckdb_result_type_2181038545 = (
    when declared(duckdb_result_type):
      when ownSizeof(duckdb_result_type) != ownSizeof(duckdb_result_type_2181038544):
        static:
          warning(
            "Declaration of " & "duckdb_result_type" & " exists but with different size"
          )
      duckdb_result_type
    else:
      duckdb_result_type_2181038544
  )
  duckdb_state_2181038537 = (
    when declared(duckdb_state):
      when ownSizeof(duckdb_state) != ownSizeof(duckdb_state_2181038536):
        static:
          warning(
            "Declaration of " & "duckdb_state" & " exists but with different size"
          )
      duckdb_state
    else:
      duckdb_state_2181038536
  )
  enum_duckdb_result_type_2181038543 = (
    when declared(enum_duckdb_result_type):
      when ownSizeof(enum_duckdb_result_type) !=
          ownSizeof(enum_duckdb_result_type_2181038542):
        static:
          warning(
            "Declaration of " & "enum_duckdb_result_type" &
              " exists but with different size"
          )
      enum_duckdb_result_type
    else:
      enum_duckdb_result_type_2181038542
  )
  duckdb_hugeint_2181038617 = (
    when declared(duckdb_hugeint):
      when ownSizeof(duckdb_hugeint) != ownSizeof(duckdb_hugeint_2181038616):
        static:
          warning(
            "Declaration of " & "duckdb_hugeint" & " exists but with different size"
          )
      duckdb_hugeint
    else:
      duckdb_hugeint_2181038616
  )

when not declared(duckdb_time):
  type duckdb_time* = duckdb_time_2181038576
else:
  static:
    hint("Declaration of " & "duckdb_time" & " already exists, not redeclaring")
when not declared(enum_duckdb_cast_mode):
  type enum_duckdb_cast_mode* = enum_duckdb_cast_mode_2181038554
else:
  static:
    hint(
      "Declaration of " & "enum_duckdb_cast_mode" & " already exists, not redeclaring"
    )
when not declared(duckdb_function_info):
  type duckdb_function_info* = duckdb_function_info_2181038743
else:
  static:
    hint(
      "Declaration of " & "duckdb_function_info" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_scalar_function_set):
  type struct_duckdb_scalar_function_set* = struct_duckdb_scalar_function_set_2181038753
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_scalar_function_set" &
        " already exists, not redeclaring"
    )
when not declared(struct_duckdb_column):
  type struct_duckdb_column* = struct_duckdb_column_2181038645
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_column" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_database):
  type struct_duckdb_database* = struct_duckdb_database_2181038681
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_database" & " already exists, not redeclaring"
    )
when not declared(duckdb_date_struct):
  type duckdb_date_struct* = duckdb_date_struct_2181038572
else:
  static:
    hint("Declaration of " & "duckdb_date_struct" & " already exists, not redeclaring")
when not declared(duckdb_decimal):
  type duckdb_decimal* = duckdb_decimal_2181038631
else:
  static:
    hint("Declaration of " & "duckdb_decimal" & " already exists, not redeclaring")
when not declared(struct_duckdb_decimal):
  type struct_duckdb_decimal* = struct_duckdb_decimal_2181038629
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_decimal" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_cast_function):
  type struct_duckdb_cast_function* = struct_duckdb_cast_function_2181038799
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_cast_function" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_database):
  type duckdb_database* = duckdb_database_2181038683
else:
  static:
    hint("Declaration of " & "duckdb_database" & " already exists, not redeclaring")
when not declared(duckdb_aggregate_function):
  type duckdb_aggregate_function* = duckdb_aggregate_function_2181038763
else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_function" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_aggregate_function_set):
  type duckdb_aggregate_function_set* = duckdb_aggregate_function_set_2181038767
else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_function_set" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_arrow):
  type duckdb_arrow* = duckdb_arrow_2181038813
else:
  static:
    hint("Declaration of " & "duckdb_arrow" & " already exists, not redeclaring")
when not declared(sel_t):
  type sel_t* = sel_t_2181038560
else:
  static:
    hint("Declaration of " & "sel_t" & " already exists, not redeclaring")
when not declared(struct_duckdb_string_t):
  type struct_duckdb_string_t* = struct_duckdb_string_t_2181038637
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_string_t" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_data_chunk):
  type struct_duckdb_data_chunk* = struct_duckdb_data_chunk_2181038725
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_data_chunk" & " already exists, not redeclaring"
    )
when not declared(duckdb_arrow_stream):
  type duckdb_arrow_stream* = duckdb_arrow_stream_2181038817
else:
  static:
    hint("Declaration of " & "duckdb_arrow_stream" & " already exists, not redeclaring")
when not declared(duckdb_cast_function_t):
  type duckdb_cast_function_t* = duckdb_cast_function_t_2181038803
else:
  static:
    hint(
      "Declaration of " & "duckdb_cast_function_t" & " already exists, not redeclaring"
    )
when not declared(idx_t):
  type idx_t* = idx_t_2181038558
else:
  static:
    hint("Declaration of " & "idx_t" & " already exists, not redeclaring")
when not declared(struct_duckdb_extracted_statements):
  type struct_duckdb_extracted_statements* =
    struct_duckdb_extracted_statements_2181038697

else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_extracted_statements" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_instance_cache):
  type duckdb_instance_cache* = duckdb_instance_cache_2181038679
else:
  static:
    hint(
      "Declaration of " & "duckdb_instance_cache" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_bind_info):
  type struct_duckdb_bind_info* = struct_duckdb_bind_info_2181038745
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_bind_info" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_time_tz):
  type struct_duckdb_time_tz* = struct_duckdb_time_tz_2181038582
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_time_tz" & " already exists, not redeclaring"
    )
when not declared(duckdb_uhugeint):
  type duckdb_uhugeint* = duckdb_uhugeint_2181038627
else:
  static:
    hint("Declaration of " & "duckdb_uhugeint" & " already exists, not redeclaring")
when not declared(struct_duckdb_timestamp_ns):
  type struct_duckdb_timestamp_ns* = struct_duckdb_timestamp_ns_2181038602
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_timestamp_ns" &
        " already exists, not redeclaring"
    )
when not declared(struct_duckdb_create_type_info):
  type struct_duckdb_create_type_info* = struct_duckdb_create_type_info_2181038721
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_create_type_info" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_blob):
  type duckdb_blob* = duckdb_blob_2181038663
else:
  static:
    hint("Declaration of " & "duckdb_blob" & " already exists, not redeclaring")
when not declared(duckdb_aggregate_init_t):
  type duckdb_aggregate_init_t* = duckdb_aggregate_init_t_2181038775
else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_init_t" & " already exists, not redeclaring"
    )
when not declared(duckdb_type):
  type duckdb_type* = duckdb_type_2181038532
else:
  static:
    hint("Declaration of " & "duckdb_type" & " already exists, not redeclaring")
when not declared(struct_duckdb_string):
  type struct_duckdb_string* = struct_duckdb_string_2181038657
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_string" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_client_context):
  type struct_duckdb_client_context* = struct_duckdb_client_context_2181038689
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_client_context" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_varint):
  type duckdb_varint* = duckdb_varint_2181038671
else:
  static:
    hint("Declaration of " & "duckdb_varint" & " already exists, not redeclaring")
when not declared(duckdb_table_function_t):
  type duckdb_table_function_t* = duckdb_table_function_t_2181038797
else:
  static:
    hint(
      "Declaration of " & "duckdb_table_function_t" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_time_struct):
  type struct_duckdb_time_struct* = struct_duckdb_time_struct_2181038578
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_time_struct" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_task_state):
  type duckdb_task_state* = duckdb_task_state_2181038564
else:
  static:
    hint("Declaration of " & "duckdb_task_state" & " already exists, not redeclaring")
when not declared(duckdb_scalar_function):
  type duckdb_scalar_function* = duckdb_scalar_function_2181038751
else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_query_progress_type):
  type struct_duckdb_query_progress_type* = struct_duckdb_query_progress_type_2181038633
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_query_progress_type" &
        " already exists, not redeclaring"
    )
when not declared(enum_duckdb_error_type):
  type enum_duckdb_error_type* = enum_duckdb_error_type_2181038550
else:
  static:
    hint(
      "Declaration of " & "enum_duckdb_error_type" & " already exists, not redeclaring"
    )
when not declared(duckdb_timestamp_s):
  type duckdb_timestamp_s* = duckdb_timestamp_s_2181038596
else:
  static:
    hint("Declaration of " & "duckdb_timestamp_s" & " already exists, not redeclaring")
when not declared(duckdb_pending_state):
  type duckdb_pending_state* = duckdb_pending_state_2181038540
else:
  static:
    hint(
      "Declaration of " & "duckdb_pending_state" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_timestamp):
  type struct_duckdb_timestamp* = struct_duckdb_timestamp_2181038590
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_timestamp" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_hugeint):
  type struct_duckdb_hugeint* = struct_duckdb_hugeint_2181038614
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_hugeint" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_blob):
  type struct_duckdb_blob* = struct_duckdb_blob_2181038661
else:
  static:
    hint("Declaration of " & "struct_duckdb_blob" & " already exists, not redeclaring")
when not declared(enum_duckdb_state):
  type enum_duckdb_state* = enum_duckdb_state_2181038534
else:
  static:
    hint("Declaration of " & "enum_duckdb_state" & " already exists, not redeclaring")
when not declared(duckdb_aggregate_combine_t):
  type duckdb_aggregate_combine_t* = duckdb_aggregate_combine_t_2181038781
else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_combine_t" &
        " already exists, not redeclaring"
    )
when not declared(struct_duckdb_selection_vector):
  type struct_duckdb_selection_vector* = struct_duckdb_selection_vector_2181038653
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_selection_vector" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_table_function_bind_t):
  type duckdb_table_function_bind_t* = duckdb_table_function_bind_t_2181038793
else:
  static:
    hint(
      "Declaration of " & "duckdb_table_function_bind_t" &
        " already exists, not redeclaring"
    )
when not declared(struct_duckdb_instance_cache):
  type struct_duckdb_instance_cache* = struct_duckdb_instance_cache_2181038677
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_instance_cache" &
        " already exists, not redeclaring"
    )
when not declared(struct_duckdb_extension_access):
  type struct_duckdb_extension_access* = struct_duckdb_extension_access_2181038827
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_extension_access" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_set):
  type duckdb_scalar_function_set* = duckdb_scalar_function_set_2181038755
else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_set" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_value):
  type duckdb_value* = duckdb_value_2181038731
else:
  static:
    hint("Declaration of " & "duckdb_value" & " already exists, not redeclaring")
when not declared(duckdb_delete_callback_t):
  type duckdb_delete_callback_t* = duckdb_delete_callback_t_2181038562
else:
  static:
    hint(
      "Declaration of " & "duckdb_delete_callback_t" & " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_bind_t):
  type duckdb_scalar_function_bind_t* = duckdb_scalar_function_bind_t_2181038757
else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_bind_t" &
        " already exists, not redeclaring"
    )
when not declared(struct_duckdb_timestamp_ms):
  type struct_duckdb_timestamp_ms* = struct_duckdb_timestamp_ms_2181038598
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_timestamp_ms" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_list_entry):
  type duckdb_list_entry* = duckdb_list_entry_2181038643
else:
  static:
    hint("Declaration of " & "duckdb_list_entry" & " already exists, not redeclaring")
when not declared(struct_duckdb_scalar_function):
  type struct_duckdb_scalar_function* = struct_duckdb_scalar_function_2181038749
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_scalar_function" &
        " already exists, not redeclaring"
    )
when not declared(struct_duckdb_vector):
  type struct_duckdb_vector* = struct_duckdb_vector_2181038649
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_vector" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_interval):
  type struct_duckdb_interval* = struct_duckdb_interval_2181038610
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_interval" & " already exists, not redeclaring"
    )
when not declared(duckdb_bit):
  type duckdb_bit* = duckdb_bit_2181038667
else:
  static:
    hint("Declaration of " & "duckdb_bit" & " already exists, not redeclaring")
when not declared(struct_duckdb_arrow):
  type struct_duckdb_arrow* = struct_duckdb_arrow_2181038811
else:
  static:
    hint("Declaration of " & "struct_duckdb_arrow" & " already exists, not redeclaring")
when not declared(duckdb_timestamp_struct):
  type duckdb_timestamp_struct* = duckdb_timestamp_struct_2181038608
else:
  static:
    hint(
      "Declaration of " & "duckdb_timestamp_struct" & " already exists, not redeclaring"
    )
when not declared(duckdb_query_progress_type):
  type duckdb_query_progress_type* = duckdb_query_progress_type_2181038635
else:
  static:
    hint(
      "Declaration of " & "duckdb_query_progress_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_init_info):
  type duckdb_init_info* = duckdb_init_info_2181038791
else:
  static:
    hint("Declaration of " & "duckdb_init_info" & " already exists, not redeclaring")
when not declared(duckdb_table_function):
  type duckdb_table_function* = duckdb_table_function_2181038787
else:
  static:
    hint(
      "Declaration of " & "duckdb_table_function" & " already exists, not redeclaring"
    )
when not declared(duckdb_replacement_scan_info):
  type duckdb_replacement_scan_info* = duckdb_replacement_scan_info_2181038807
else:
  static:
    hint(
      "Declaration of " & "duckdb_replacement_scan_info" &
        " already exists, not redeclaring"
    )
when not declared(struct_duckdb_prepared_statement):
  type struct_duckdb_prepared_statement* = struct_duckdb_prepared_statement_2181038693
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_prepared_statement" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_replacement_callback_t):
  type duckdb_replacement_callback_t* = duckdb_replacement_callback_t_2181038809
else:
  static:
    hint(
      "Declaration of " & "duckdb_replacement_callback_t" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_logical_type):
  type duckdb_logical_type* = duckdb_logical_type_2181038719
else:
  static:
    hint("Declaration of " & "duckdb_logical_type" & " already exists, not redeclaring")
when not declared(duckdb_profiling_info):
  type duckdb_profiling_info* = duckdb_profiling_info_2181038735
else:
  static:
    hint(
      "Declaration of " & "duckdb_profiling_info" & " already exists, not redeclaring"
    )
when not declared(duckdb_date):
  type duckdb_date* = duckdb_date_2181038568
else:
  static:
    hint("Declaration of " & "duckdb_date" & " already exists, not redeclaring")
when not declared(duckdb_table_description):
  type duckdb_table_description* = duckdb_table_description_2181038711
else:
  static:
    hint(
      "Declaration of " & "duckdb_table_description" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_timestamp_s):
  type struct_duckdb_timestamp_s* = struct_duckdb_timestamp_s_2181038594
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_timestamp_s" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_connection):
  type duckdb_connection* = duckdb_connection_2181038687
else:
  static:
    hint("Declaration of " & "duckdb_connection" & " already exists, not redeclaring")
when not declared(struct_duckdb_date_struct):
  type struct_duckdb_date_struct* = struct_duckdb_date_struct_2181038570
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_date_struct" &
        " already exists, not redeclaring"
    )
when not declared(struct_duckdb_arrow_schema):
  type struct_duckdb_arrow_schema* = struct_duckdb_arrow_schema_2181038819
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_arrow_schema" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_time_tz):
  type duckdb_time_tz* = duckdb_time_tz_2181038584
else:
  static:
    hint("Declaration of " & "duckdb_time_tz" & " already exists, not redeclaring")
when not declared(struct_duckdb_aggregate_function):
  type struct_duckdb_aggregate_function* = struct_duckdb_aggregate_function_2181038761
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_aggregate_function" &
        " already exists, not redeclaring"
    )
when not declared(enum_duckdb_statement_type):
  type enum_duckdb_statement_type* = enum_duckdb_statement_type_2181038546
else:
  static:
    hint(
      "Declaration of " & "enum_duckdb_statement_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_vector):
  type duckdb_vector* = duckdb_vector_2181038651
else:
  static:
    hint("Declaration of " & "duckdb_vector" & " already exists, not redeclaring")
when not declared(struct_duckdb_table_description):
  type struct_duckdb_table_description* = struct_duckdb_table_description_2181038709
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_table_description" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_interval):
  type duckdb_interval* = duckdb_interval_2181038612
else:
  static:
    hint("Declaration of " & "duckdb_interval" & " already exists, not redeclaring")
when not declared(duckdb_client_context):
  type duckdb_client_context* = duckdb_client_context_2181038691
else:
  static:
    hint(
      "Declaration of " & "duckdb_client_context" & " already exists, not redeclaring"
    )
when not declared(duckdb_pending_result):
  type duckdb_pending_result* = duckdb_pending_result_2181038703
else:
  static:
    hint(
      "Declaration of " & "duckdb_pending_result" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_type_info):
  type duckdb_create_type_info* = duckdb_create_type_info_2181038723
else:
  static:
    hint(
      "Declaration of " & "duckdb_create_type_info" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_aggregate_state):
  type struct_duckdb_aggregate_state* = struct_duckdb_aggregate_state_2181038769
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_aggregate_state" &
        " already exists, not redeclaring"
    )
when not declared(enum_duckdb_pending_state):
  type enum_duckdb_pending_state* = enum_duckdb_pending_state_2181038538
else:
  static:
    hint(
      "Declaration of " & "enum_duckdb_pending_state" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_string):
  type duckdb_string* = duckdb_string_2181038659
else:
  static:
    hint("Declaration of " & "duckdb_string" & " already exists, not redeclaring")
when not declared(duckdb_config):
  type duckdb_config* = duckdb_config_2181038715
else:
  static:
    hint("Declaration of " & "duckdb_config" & " already exists, not redeclaring")
when not declared(duckdb_prepared_statement):
  type duckdb_prepared_statement* = duckdb_prepared_statement_2181038695
else:
  static:
    hint(
      "Declaration of " & "duckdb_prepared_statement" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_aggregate_update_t):
  type duckdb_aggregate_update_t* = duckdb_aggregate_update_t_2181038779
else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_update_t" &
        " already exists, not redeclaring"
    )
when not declared(struct_duckdb_pending_result):
  type struct_duckdb_pending_result* = struct_duckdb_pending_result_2181038701
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_pending_result" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_bind_info):
  type duckdb_bind_info* = duckdb_bind_info_2181038747
else:
  static:
    hint("Declaration of " & "duckdb_bind_info" & " already exists, not redeclaring")
when not declared(struct_duckdb_result):
  type struct_duckdb_result* = struct_duckdb_result_2181038673
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_result" & " already exists, not redeclaring"
    )
when not declared(duckdb_time_tz_struct):
  type duckdb_time_tz_struct* = duckdb_time_tz_struct_2181038588
else:
  static:
    hint(
      "Declaration of " & "duckdb_time_tz_struct" & " already exists, not redeclaring"
    )
when not declared(duckdb_aggregate_destroy_t):
  type duckdb_aggregate_destroy_t* = duckdb_aggregate_destroy_t_2181038777
else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_destroy_t" &
        " already exists, not redeclaring"
    )
when not declared(struct_duckdb_profiling_info):
  type struct_duckdb_profiling_info* = struct_duckdb_profiling_info_2181038733
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_profiling_info" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_cast_function):
  type duckdb_cast_function* = duckdb_cast_function_2181038801
else:
  static:
    hint(
      "Declaration of " & "duckdb_cast_function" & " already exists, not redeclaring"
    )
when not declared(duckdb_timestamp):
  type duckdb_timestamp* = duckdb_timestamp_2181038592
else:
  static:
    hint("Declaration of " & "duckdb_timestamp" & " already exists, not redeclaring")
when not declared(struct_duckdb_extension_info):
  type struct_duckdb_extension_info* = struct_duckdb_extension_info_2181038737
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_extension_info" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_aggregate_state):
  type duckdb_aggregate_state* = duckdb_aggregate_state_2181038771
else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_state" & " already exists, not redeclaring"
    )
when not declared(duckdb_time_struct):
  type duckdb_time_struct* = duckdb_time_struct_2181038580
else:
  static:
    hint("Declaration of " & "duckdb_time_struct" & " already exists, not redeclaring")
when not declared(duckdb_statement_type):
  type duckdb_statement_type* = duckdb_statement_type_2181038548
else:
  static:
    hint(
      "Declaration of " & "duckdb_statement_type" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_uhugeint):
  type struct_duckdb_uhugeint* = struct_duckdb_uhugeint_2181038618
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_uhugeint" & " already exists, not redeclaring"
    )
when not declared(duckdb_column):
  type duckdb_column* = duckdb_column_2181038647
else:
  static:
    hint("Declaration of " & "duckdb_column" & " already exists, not redeclaring")
when not declared(struct_duckdb_replacement_scan_info):
  type struct_duckdb_replacement_scan_info* =
    struct_duckdb_replacement_scan_info_2181038805

else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_replacement_scan_info" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_selection_vector):
  type duckdb_selection_vector* = duckdb_selection_vector_2181038655
else:
  static:
    hint(
      "Declaration of " & "duckdb_selection_vector" & " already exists, not redeclaring"
    )
when not declared(duckdb_result):
  type duckdb_result* = duckdb_result_2181038675
else:
  static:
    hint("Declaration of " & "duckdb_result" & " already exists, not redeclaring")
when not declared(duckdb_aggregate_state_size):
  type duckdb_aggregate_state_size* = duckdb_aggregate_state_size_2181038773
else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_state_size" &
        " already exists, not redeclaring"
    )
when not declared(struct_duckdb_arrow_stream):
  type struct_duckdb_arrow_stream* = struct_duckdb_arrow_stream_2181038815
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_arrow_stream" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_t):
  type duckdb_scalar_function_t* = duckdb_scalar_function_t_2181038759
else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_t" & " already exists, not redeclaring"
    )
when not declared(duckdb_cast_mode):
  type duckdb_cast_mode* = duckdb_cast_mode_2181038556
else:
  static:
    hint("Declaration of " & "duckdb_cast_mode" & " already exists, not redeclaring")
when not declared(struct_duckdb_aggregate_function_set):
  type struct_duckdb_aggregate_function_set* =
    struct_duckdb_aggregate_function_set_2181038765

else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_aggregate_function_set" &
        " already exists, not redeclaring"
    )
when not declared(struct_duckdb_time):
  type struct_duckdb_time* = struct_duckdb_time_2181038574
else:
  static:
    hint("Declaration of " & "struct_duckdb_time" & " already exists, not redeclaring")
when not declared(struct_duckdb_time_tz_struct):
  type struct_duckdb_time_tz_struct* = struct_duckdb_time_tz_struct_2181038586
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_time_tz_struct" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_timestamp_ns):
  type duckdb_timestamp_ns* = duckdb_timestamp_ns_2181038604
else:
  static:
    hint("Declaration of " & "duckdb_timestamp_ns" & " already exists, not redeclaring")
when not declared(duckdb_string_t):
  type duckdb_string_t* = duckdb_string_t_2181038639
else:
  static:
    hint("Declaration of " & "duckdb_string_t" & " already exists, not redeclaring")
when not declared(struct_duckdb_table_function):
  type struct_duckdb_table_function* = struct_duckdb_table_function_2181038785
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_table_function" &
        " already exists, not redeclaring"
    )
when not declared(struct_duckdb_arrow_array):
  type struct_duckdb_arrow_array* = struct_duckdb_arrow_array_2181038823
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_arrow_array" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_extension_info):
  type duckdb_extension_info* = duckdb_extension_info_2181038739
else:
  static:
    hint(
      "Declaration of " & "duckdb_extension_info" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_init_info):
  type struct_duckdb_init_info* = struct_duckdb_init_info_2181038789
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_init_info" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_connection):
  type struct_duckdb_connection* = struct_duckdb_connection_2181038685
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_connection" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_logical_type):
  type struct_duckdb_logical_type* = struct_duckdb_logical_type_2181038717
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_logical_type" &
        " already exists, not redeclaring"
    )
when not declared(struct_duckdb_date):
  type struct_duckdb_date* = struct_duckdb_date_2181038566
else:
  static:
    hint("Declaration of " & "struct_duckdb_date" & " already exists, not redeclaring")
when not declared(duckdb_aggregate_finalize_t):
  type duckdb_aggregate_finalize_t* = duckdb_aggregate_finalize_t_2181038783
else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_finalize_t" &
        " already exists, not redeclaring"
    )
when not declared(struct_duckdb_value):
  type struct_duckdb_value* = struct_duckdb_value_2181038729
else:
  static:
    hint("Declaration of " & "struct_duckdb_value" & " already exists, not redeclaring")
when not declared(duckdb_arrow_schema):
  type duckdb_arrow_schema* = duckdb_arrow_schema_2181038821
else:
  static:
    hint("Declaration of " & "duckdb_arrow_schema" & " already exists, not redeclaring")
when not declared(struct_duckdb_config):
  type struct_duckdb_config* = struct_duckdb_config_2181038713
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_config" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_bit):
  type struct_duckdb_bit* = struct_duckdb_bit_2181038665
else:
  static:
    hint("Declaration of " & "struct_duckdb_bit" & " already exists, not redeclaring")
when not declared(struct_duckdb_list_entry):
  type struct_duckdb_list_entry* = struct_duckdb_list_entry_2181038641
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_list_entry" & " already exists, not redeclaring"
    )
when not declared(struct_duckdb_appender):
  type struct_duckdb_appender* = struct_duckdb_appender_2181038705
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_appender" & " already exists, not redeclaring"
    )
when not declared(duckdb_table_function_init_t):
  type duckdb_table_function_init_t* = duckdb_table_function_init_t_2181038795
else:
  static:
    hint(
      "Declaration of " & "duckdb_table_function_init_t" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_data_chunk):
  type duckdb_data_chunk* = duckdb_data_chunk_2181038727
else:
  static:
    hint("Declaration of " & "duckdb_data_chunk" & " already exists, not redeclaring")
when not declared(struct_duckdb_timestamp_struct):
  type struct_duckdb_timestamp_struct* = struct_duckdb_timestamp_struct_2181038606
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_timestamp_struct" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_timestamp_ms):
  type duckdb_timestamp_ms* = duckdb_timestamp_ms_2181038600
else:
  static:
    hint("Declaration of " & "duckdb_timestamp_ms" & " already exists, not redeclaring")
when not declared(duckdb_arrow_array):
  type duckdb_arrow_array* = duckdb_arrow_array_2181038825
else:
  static:
    hint("Declaration of " & "duckdb_arrow_array" & " already exists, not redeclaring")
when not declared(duckdb_appender):
  type duckdb_appender* = duckdb_appender_2181038707
else:
  static:
    hint("Declaration of " & "duckdb_appender" & " already exists, not redeclaring")
when not declared(duckdb_error_type):
  type duckdb_error_type* = duckdb_error_type_2181038552
else:
  static:
    hint("Declaration of " & "duckdb_error_type" & " already exists, not redeclaring")
when not declared(duckdb_extracted_statements):
  type duckdb_extracted_statements* = duckdb_extracted_statements_2181038699
else:
  static:
    hint(
      "Declaration of " & "duckdb_extracted_statements" &
        " already exists, not redeclaring"
    )
when not declared(struct_duckdb_function_info):
  type struct_duckdb_function_info* = struct_duckdb_function_info_2181038741
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_function_info" &
        " already exists, not redeclaring"
    )
when not declared(enum_DUCKDB_TYPE):
  type enum_DUCKDB_TYPE* = enum_DUCKDB_TYPE_2181038529
else:
  static:
    hint("Declaration of " & "enum_DUCKDB_TYPE" & " already exists, not redeclaring")
when not declared(struct_duckdb_varint):
  type struct_duckdb_varint* = struct_duckdb_varint_2181038669
else:
  static:
    hint(
      "Declaration of " & "struct_duckdb_varint" & " already exists, not redeclaring"
    )
when not declared(duckdb_result_type):
  type duckdb_result_type* = duckdb_result_type_2181038544
else:
  static:
    hint("Declaration of " & "duckdb_result_type" & " already exists, not redeclaring")
when not declared(duckdb_state):
  type duckdb_state* = duckdb_state_2181038536
else:
  static:
    hint("Declaration of " & "duckdb_state" & " already exists, not redeclaring")
when not declared(enum_duckdb_result_type):
  type enum_duckdb_result_type* = enum_duckdb_result_type_2181038542
else:
  static:
    hint(
      "Declaration of " & "enum_duckdb_result_type" & " already exists, not redeclaring"
    )
when not declared(duckdb_hugeint):
  type duckdb_hugeint* = duckdb_hugeint_2181038616
else:
  static:
    hint("Declaration of " & "duckdb_hugeint" & " already exists, not redeclaring")
when not declared(duckdb_create_instance_cache):
  proc duckdb_create_instance_cache*(): duckdb_instance_cache_2181038680 {.
    cdecl, importc: "duckdb_create_instance_cache"
  .}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_instance_cache" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_get_or_create_from_cache):
  proc duckdb_get_or_create_from_cache*(
    instance_cache: duckdb_instance_cache_2181038680,
    path: cstring,
    out_database: ptr duckdb_database_2181038684,
    config: duckdb_config_2181038716,
    out_error: ptr cstring,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_get_or_create_from_cache".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_get_or_create_from_cache" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_instance_cache):
  proc duckdb_destroy_instance_cache*(
    instance_cache: ptr duckdb_instance_cache_2181038680
  ): void {.cdecl, importc: "duckdb_destroy_instance_cache".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_instance_cache" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_open):
  proc duckdb_open*(
    path: cstring, out_database: ptr duckdb_database_2181038684
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_open".}

else:
  static:
    hint("Declaration of " & "duckdb_open" & " already exists, not redeclaring")
when not declared(duckdb_open_ext):
  proc duckdb_open_ext*(
    path: cstring,
    out_database: ptr duckdb_database_2181038684,
    config: duckdb_config_2181038716,
    out_error: ptr cstring,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_open_ext".}

else:
  static:
    hint("Declaration of " & "duckdb_open_ext" & " already exists, not redeclaring")
when not declared(duckdb_close):
  proc duckdb_close*(
    database: ptr duckdb_database_2181038684
  ): void {.cdecl, importc: "duckdb_close".}

else:
  static:
    hint("Declaration of " & "duckdb_close" & " already exists, not redeclaring")
when not declared(duckdb_connect):
  proc duckdb_connect*(
    database: duckdb_database_2181038684,
    out_connection: ptr duckdb_connection_2181038688,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_connect".}

else:
  static:
    hint("Declaration of " & "duckdb_connect" & " already exists, not redeclaring")
when not declared(duckdb_interrupt):
  proc duckdb_interrupt*(
    connection: duckdb_connection_2181038688
  ): void {.cdecl, importc: "duckdb_interrupt".}

else:
  static:
    hint("Declaration of " & "duckdb_interrupt" & " already exists, not redeclaring")
when not declared(duckdb_query_progress):
  proc duckdb_query_progress*(
    connection: duckdb_connection_2181038688
  ): duckdb_query_progress_type_2181038636 {.cdecl, importc: "duckdb_query_progress".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_query_progress" & " already exists, not redeclaring"
    )
when not declared(duckdb_disconnect):
  proc duckdb_disconnect*(
    connection: ptr duckdb_connection_2181038688
  ): void {.cdecl, importc: "duckdb_disconnect".}

else:
  static:
    hint("Declaration of " & "duckdb_disconnect" & " already exists, not redeclaring")
when not declared(duckdb_connection_get_client_context):
  proc duckdb_connection_get_client_context*(
    connection: duckdb_connection_2181038688,
    out_context: ptr duckdb_client_context_2181038692,
  ): void {.cdecl, importc: "duckdb_connection_get_client_context".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_connection_get_client_context" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_client_context_get_connection_id):
  proc duckdb_client_context_get_connection_id*(
    context: duckdb_client_context_2181038692
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_client_context_get_connection_id".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_client_context_get_connection_id" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_client_context):
  proc duckdb_destroy_client_context*(
    context: ptr duckdb_client_context_2181038692
  ): void {.cdecl, importc: "duckdb_destroy_client_context".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_client_context" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_library_version):
  proc duckdb_library_version*(): cstring {.cdecl, importc: "duckdb_library_version".}
else:
  static:
    hint(
      "Declaration of " & "duckdb_library_version" & " already exists, not redeclaring"
    )
when not declared(duckdb_get_table_names):
  proc duckdb_get_table_names*(
    connection: duckdb_connection_2181038688, query: cstring, qualified: bool
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_get_table_names".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_get_table_names" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_config):
  proc duckdb_create_config*(
    out_config: ptr duckdb_config_2181038716
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_create_config".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_config" & " already exists, not redeclaring"
    )
when not declared(duckdb_config_count):
  proc duckdb_config_count*(): csize_t {.cdecl, importc: "duckdb_config_count".}
else:
  static:
    hint("Declaration of " & "duckdb_config_count" & " already exists, not redeclaring")
when not declared(duckdb_get_config_flag):
  proc duckdb_get_config_flag*(
    index: csize_t, out_name: ptr cstring, out_description: ptr cstring
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_get_config_flag".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_get_config_flag" & " already exists, not redeclaring"
    )
when not declared(duckdb_set_config):
  proc duckdb_set_config*(
    config: duckdb_config_2181038716, name: cstring, option: cstring
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_set_config".}

else:
  static:
    hint("Declaration of " & "duckdb_set_config" & " already exists, not redeclaring")
when not declared(duckdb_destroy_config):
  proc duckdb_destroy_config*(
    config: ptr duckdb_config_2181038716
  ): void {.cdecl, importc: "duckdb_destroy_config".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_config" & " already exists, not redeclaring"
    )
when not declared(duckdb_query):
  proc duckdb_query*(
    connection: duckdb_connection_2181038688,
    query: cstring,
    out_result: ptr duckdb_result_2181038676,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_query".}

else:
  static:
    hint("Declaration of " & "duckdb_query" & " already exists, not redeclaring")
when not declared(duckdb_destroy_result):
  proc duckdb_destroy_result*(
    result: ptr duckdb_result_2181038676
  ): void {.cdecl, importc: "duckdb_destroy_result".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_result" & " already exists, not redeclaring"
    )
when not declared(duckdb_column_name):
  proc duckdb_column_name*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559
  ): cstring {.cdecl, importc: "duckdb_column_name".}

else:
  static:
    hint("Declaration of " & "duckdb_column_name" & " already exists, not redeclaring")
when not declared(duckdb_column_type):
  proc duckdb_column_type*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559
  ): duckdb_type_2181038533 {.cdecl, importc: "duckdb_column_type".}

else:
  static:
    hint("Declaration of " & "duckdb_column_type" & " already exists, not redeclaring")
when not declared(duckdb_result_statement_type):
  proc duckdb_result_statement_type*(
    result: duckdb_result_2181038676
  ): duckdb_statement_type_2181038549 {.cdecl, importc: "duckdb_result_statement_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_result_statement_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_column_logical_type):
  proc duckdb_column_logical_type*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_column_logical_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_column_logical_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_column_count):
  proc duckdb_column_count*(
    result: ptr duckdb_result_2181038676
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_column_count".}

else:
  static:
    hint("Declaration of " & "duckdb_column_count" & " already exists, not redeclaring")
when not declared(duckdb_row_count):
  proc duckdb_row_count*(
    result: ptr duckdb_result_2181038676
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_row_count".}

else:
  static:
    hint("Declaration of " & "duckdb_row_count" & " already exists, not redeclaring")
when not declared(duckdb_rows_changed):
  proc duckdb_rows_changed*(
    result: ptr duckdb_result_2181038676
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_rows_changed".}

else:
  static:
    hint("Declaration of " & "duckdb_rows_changed" & " already exists, not redeclaring")
when not declared(duckdb_column_data):
  proc duckdb_column_data*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559
  ): pointer {.cdecl, importc: "duckdb_column_data".}

else:
  static:
    hint("Declaration of " & "duckdb_column_data" & " already exists, not redeclaring")
when not declared(duckdb_nullmask_data):
  proc duckdb_nullmask_data*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559
  ): ptr bool {.cdecl, importc: "duckdb_nullmask_data".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_nullmask_data" & " already exists, not redeclaring"
    )
when not declared(duckdb_result_error):
  proc duckdb_result_error*(
    result: ptr duckdb_result_2181038676
  ): cstring {.cdecl, importc: "duckdb_result_error".}

else:
  static:
    hint("Declaration of " & "duckdb_result_error" & " already exists, not redeclaring")
when not declared(duckdb_result_error_type):
  proc duckdb_result_error_type*(
    result: ptr duckdb_result_2181038676
  ): duckdb_error_type_2181038553 {.cdecl, importc: "duckdb_result_error_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_result_error_type" & " already exists, not redeclaring"
    )
when not declared(duckdb_result_get_chunk):
  proc duckdb_result_get_chunk*(
    result: duckdb_result_2181038676, chunk_index: idx_t_2181038559
  ): duckdb_data_chunk_2181038728 {.cdecl, importc: "duckdb_result_get_chunk".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_result_get_chunk" & " already exists, not redeclaring"
    )
when not declared(duckdb_result_is_streaming):
  proc duckdb_result_is_streaming*(
    result: duckdb_result_2181038676
  ): bool {.cdecl, importc: "duckdb_result_is_streaming".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_result_is_streaming" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_result_chunk_count):
  proc duckdb_result_chunk_count*(
    result: duckdb_result_2181038676
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_result_chunk_count".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_result_chunk_count" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_result_return_type):
  proc duckdb_result_return_type*(
    result: duckdb_result_2181038676
  ): duckdb_result_type_2181038545 {.cdecl, importc: "duckdb_result_return_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_result_return_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_value_boolean):
  proc duckdb_value_boolean*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): bool {.cdecl, importc: "duckdb_value_boolean".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_value_boolean" & " already exists, not redeclaring"
    )
when not declared(duckdb_value_int8):
  proc duckdb_value_int8*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): int8 {.cdecl, importc: "duckdb_value_int8".}

else:
  static:
    hint("Declaration of " & "duckdb_value_int8" & " already exists, not redeclaring")
when not declared(duckdb_value_int16):
  proc duckdb_value_int16*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): int16 {.cdecl, importc: "duckdb_value_int16".}

else:
  static:
    hint("Declaration of " & "duckdb_value_int16" & " already exists, not redeclaring")
when not declared(duckdb_value_int32):
  proc duckdb_value_int32*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): int32 {.cdecl, importc: "duckdb_value_int32".}

else:
  static:
    hint("Declaration of " & "duckdb_value_int32" & " already exists, not redeclaring")
when not declared(duckdb_value_int64):
  proc duckdb_value_int64*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): int64 {.cdecl, importc: "duckdb_value_int64".}

else:
  static:
    hint("Declaration of " & "duckdb_value_int64" & " already exists, not redeclaring")
when not declared(duckdb_value_hugeint):
  proc duckdb_value_hugeint*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): duckdb_hugeint_2181038617 {.cdecl, importc: "duckdb_value_hugeint".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_value_hugeint" & " already exists, not redeclaring"
    )
when not declared(duckdb_value_uhugeint):
  proc duckdb_value_uhugeint*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): duckdb_uhugeint_2181038628 {.cdecl, importc: "duckdb_value_uhugeint".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_value_uhugeint" & " already exists, not redeclaring"
    )
when not declared(duckdb_value_decimal):
  proc duckdb_value_decimal*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): duckdb_decimal_2181038632 {.cdecl, importc: "duckdb_value_decimal".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_value_decimal" & " already exists, not redeclaring"
    )
when not declared(duckdb_value_uint8):
  proc duckdb_value_uint8*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): uint8 {.cdecl, importc: "duckdb_value_uint8".}

else:
  static:
    hint("Declaration of " & "duckdb_value_uint8" & " already exists, not redeclaring")
when not declared(duckdb_value_uint16):
  proc duckdb_value_uint16*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): uint16 {.cdecl, importc: "duckdb_value_uint16".}

else:
  static:
    hint("Declaration of " & "duckdb_value_uint16" & " already exists, not redeclaring")
when not declared(duckdb_value_uint32):
  proc duckdb_value_uint32*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): uint32 {.cdecl, importc: "duckdb_value_uint32".}

else:
  static:
    hint("Declaration of " & "duckdb_value_uint32" & " already exists, not redeclaring")
when not declared(duckdb_value_uint64):
  proc duckdb_value_uint64*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): uint64 {.cdecl, importc: "duckdb_value_uint64".}

else:
  static:
    hint("Declaration of " & "duckdb_value_uint64" & " already exists, not redeclaring")
when not declared(duckdb_value_float):
  proc duckdb_value_float*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): cfloat {.cdecl, importc: "duckdb_value_float".}

else:
  static:
    hint("Declaration of " & "duckdb_value_float" & " already exists, not redeclaring")
when not declared(duckdb_value_double):
  proc duckdb_value_double*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): cdouble {.cdecl, importc: "duckdb_value_double".}

else:
  static:
    hint("Declaration of " & "duckdb_value_double" & " already exists, not redeclaring")
when not declared(duckdb_value_date):
  proc duckdb_value_date*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): duckdb_date_2181038569 {.cdecl, importc: "duckdb_value_date".}

else:
  static:
    hint("Declaration of " & "duckdb_value_date" & " already exists, not redeclaring")
when not declared(duckdb_value_time):
  proc duckdb_value_time*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): duckdb_time_2181038577 {.cdecl, importc: "duckdb_value_time".}

else:
  static:
    hint("Declaration of " & "duckdb_value_time" & " already exists, not redeclaring")
when not declared(duckdb_value_timestamp):
  proc duckdb_value_timestamp*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): duckdb_timestamp_2181038593 {.cdecl, importc: "duckdb_value_timestamp".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_value_timestamp" & " already exists, not redeclaring"
    )
when not declared(duckdb_value_interval):
  proc duckdb_value_interval*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): duckdb_interval_2181038613 {.cdecl, importc: "duckdb_value_interval".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_value_interval" & " already exists, not redeclaring"
    )
when not declared(duckdb_value_varchar):
  proc duckdb_value_varchar*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): cstring {.cdecl, importc: "duckdb_value_varchar".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_value_varchar" & " already exists, not redeclaring"
    )
when not declared(duckdb_value_string):
  proc duckdb_value_string*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): duckdb_string_2181038660 {.cdecl, importc: "duckdb_value_string".}

else:
  static:
    hint("Declaration of " & "duckdb_value_string" & " already exists, not redeclaring")
when not declared(duckdb_value_varchar_internal):
  proc duckdb_value_varchar_internal*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): cstring {.cdecl, importc: "duckdb_value_varchar_internal".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_value_varchar_internal" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_value_string_internal):
  proc duckdb_value_string_internal*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): duckdb_string_2181038660 {.cdecl, importc: "duckdb_value_string_internal".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_value_string_internal" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_value_blob):
  proc duckdb_value_blob*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): duckdb_blob_2181038664 {.cdecl, importc: "duckdb_value_blob".}

else:
  static:
    hint("Declaration of " & "duckdb_value_blob" & " already exists, not redeclaring")
when not declared(duckdb_value_is_null):
  proc duckdb_value_is_null*(
    result: ptr duckdb_result_2181038676, col: idx_t_2181038559, row: idx_t_2181038559
  ): bool {.cdecl, importc: "duckdb_value_is_null".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_value_is_null" & " already exists, not redeclaring"
    )
when not declared(duckdb_malloc):
  proc duckdb_malloc*(size: csize_t): pointer {.cdecl, importc: "duckdb_malloc".}
else:
  static:
    hint("Declaration of " & "duckdb_malloc" & " already exists, not redeclaring")
when not declared(duckdb_free):
  proc duckdb_free*(ptr_arg: pointer): void {.cdecl, importc: "duckdb_free".}
else:
  static:
    hint("Declaration of " & "duckdb_free" & " already exists, not redeclaring")
when not declared(duckdb_vector_size):
  proc duckdb_vector_size*(): idx_t_2181038559 {.cdecl, importc: "duckdb_vector_size".}
else:
  static:
    hint("Declaration of " & "duckdb_vector_size" & " already exists, not redeclaring")
when not declared(duckdb_string_is_inlined):
  proc duckdb_string_is_inlined*(
    string: duckdb_string_t_2181038640
  ): bool {.cdecl, importc: "duckdb_string_is_inlined".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_string_is_inlined" & " already exists, not redeclaring"
    )
when not declared(duckdb_string_t_length):
  proc duckdb_string_t_length*(
    string: duckdb_string_t_2181038640
  ): uint32 {.cdecl, importc: "duckdb_string_t_length".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_string_t_length" & " already exists, not redeclaring"
    )
when not declared(duckdb_string_t_data):
  proc duckdb_string_t_data*(
    string: ptr duckdb_string_t_2181038640
  ): cstring {.cdecl, importc: "duckdb_string_t_data".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_string_t_data" & " already exists, not redeclaring"
    )
when not declared(duckdb_from_date):
  proc duckdb_from_date*(
    date: duckdb_date_2181038569
  ): duckdb_date_struct_2181038573 {.cdecl, importc: "duckdb_from_date".}

else:
  static:
    hint("Declaration of " & "duckdb_from_date" & " already exists, not redeclaring")
when not declared(duckdb_to_date):
  proc duckdb_to_date*(
    date: duckdb_date_struct_2181038573
  ): duckdb_date_2181038569 {.cdecl, importc: "duckdb_to_date".}

else:
  static:
    hint("Declaration of " & "duckdb_to_date" & " already exists, not redeclaring")
when not declared(duckdb_is_finite_date):
  proc duckdb_is_finite_date*(
    date: duckdb_date_2181038569
  ): bool {.cdecl, importc: "duckdb_is_finite_date".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_is_finite_date" & " already exists, not redeclaring"
    )
when not declared(duckdb_from_time):
  proc duckdb_from_time*(
    time: duckdb_time_2181038577
  ): duckdb_time_struct_2181038581 {.cdecl, importc: "duckdb_from_time".}

else:
  static:
    hint("Declaration of " & "duckdb_from_time" & " already exists, not redeclaring")
when not declared(duckdb_create_time_tz):
  proc duckdb_create_time_tz*(
    micros: int64, offset: int32
  ): duckdb_time_tz_2181038585 {.cdecl, importc: "duckdb_create_time_tz".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_time_tz" & " already exists, not redeclaring"
    )
when not declared(duckdb_from_time_tz):
  proc duckdb_from_time_tz*(
    micros: duckdb_time_tz_2181038585
  ): duckdb_time_tz_struct_2181038589 {.cdecl, importc: "duckdb_from_time_tz".}

else:
  static:
    hint("Declaration of " & "duckdb_from_time_tz" & " already exists, not redeclaring")
when not declared(duckdb_to_time):
  proc duckdb_to_time*(
    time: duckdb_time_struct_2181038581
  ): duckdb_time_2181038577 {.cdecl, importc: "duckdb_to_time".}

else:
  static:
    hint("Declaration of " & "duckdb_to_time" & " already exists, not redeclaring")
when not declared(duckdb_from_timestamp):
  proc duckdb_from_timestamp*(
    ts: duckdb_timestamp_2181038593
  ): duckdb_timestamp_struct_2181038609 {.cdecl, importc: "duckdb_from_timestamp".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_from_timestamp" & " already exists, not redeclaring"
    )
when not declared(duckdb_to_timestamp):
  proc duckdb_to_timestamp*(
    ts: duckdb_timestamp_struct_2181038609
  ): duckdb_timestamp_2181038593 {.cdecl, importc: "duckdb_to_timestamp".}

else:
  static:
    hint("Declaration of " & "duckdb_to_timestamp" & " already exists, not redeclaring")
when not declared(duckdb_is_finite_timestamp):
  proc duckdb_is_finite_timestamp*(
    ts: duckdb_timestamp_2181038593
  ): bool {.cdecl, importc: "duckdb_is_finite_timestamp".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_is_finite_timestamp" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_is_finite_timestamp_s):
  proc duckdb_is_finite_timestamp_s*(
    ts: duckdb_timestamp_s_2181038597
  ): bool {.cdecl, importc: "duckdb_is_finite_timestamp_s".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_is_finite_timestamp_s" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_is_finite_timestamp_ms):
  proc duckdb_is_finite_timestamp_ms*(
    ts: duckdb_timestamp_ms_2181038601
  ): bool {.cdecl, importc: "duckdb_is_finite_timestamp_ms".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_is_finite_timestamp_ms" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_is_finite_timestamp_ns):
  proc duckdb_is_finite_timestamp_ns*(
    ts: duckdb_timestamp_ns_2181038605
  ): bool {.cdecl, importc: "duckdb_is_finite_timestamp_ns".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_is_finite_timestamp_ns" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_hugeint_to_double):
  proc duckdb_hugeint_to_double*(
    val: duckdb_hugeint_2181038617
  ): cdouble {.cdecl, importc: "duckdb_hugeint_to_double".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_hugeint_to_double" & " already exists, not redeclaring"
    )
when not declared(duckdb_double_to_hugeint):
  proc duckdb_double_to_hugeint*(
    val: cdouble
  ): duckdb_hugeint_2181038617 {.cdecl, importc: "duckdb_double_to_hugeint".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_double_to_hugeint" & " already exists, not redeclaring"
    )
when not declared(duckdb_uhugeint_to_double):
  proc duckdb_uhugeint_to_double*(
    val: duckdb_uhugeint_2181038628
  ): cdouble {.cdecl, importc: "duckdb_uhugeint_to_double".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_uhugeint_to_double" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_double_to_uhugeint):
  proc duckdb_double_to_uhugeint*(
    val: cdouble
  ): duckdb_uhugeint_2181038628 {.cdecl, importc: "duckdb_double_to_uhugeint".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_double_to_uhugeint" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_double_to_decimal):
  proc duckdb_double_to_decimal*(
    val: cdouble, width: uint8, scale: uint8
  ): duckdb_decimal_2181038632 {.cdecl, importc: "duckdb_double_to_decimal".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_double_to_decimal" & " already exists, not redeclaring"
    )
when not declared(duckdb_decimal_to_double):
  proc duckdb_decimal_to_double*(
    val: duckdb_decimal_2181038632
  ): cdouble {.cdecl, importc: "duckdb_decimal_to_double".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_decimal_to_double" & " already exists, not redeclaring"
    )
when not declared(duckdb_prepare):
  proc duckdb_prepare*(
    connection: duckdb_connection_2181038688,
    query: cstring,
    out_prepared_statement: ptr duckdb_prepared_statement_2181038696,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_prepare".}

else:
  static:
    hint("Declaration of " & "duckdb_prepare" & " already exists, not redeclaring")
when not declared(duckdb_destroy_prepare):
  proc duckdb_destroy_prepare*(
    prepared_statement: ptr duckdb_prepared_statement_2181038696
  ): void {.cdecl, importc: "duckdb_destroy_prepare".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_prepare" & " already exists, not redeclaring"
    )
when not declared(duckdb_prepare_error):
  proc duckdb_prepare_error*(
    prepared_statement: duckdb_prepared_statement_2181038696
  ): cstring {.cdecl, importc: "duckdb_prepare_error".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_prepare_error" & " already exists, not redeclaring"
    )
when not declared(duckdb_nparams):
  proc duckdb_nparams*(
    prepared_statement: duckdb_prepared_statement_2181038696
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_nparams".}

else:
  static:
    hint("Declaration of " & "duckdb_nparams" & " already exists, not redeclaring")
when not declared(duckdb_parameter_name):
  proc duckdb_parameter_name*(
    prepared_statement: duckdb_prepared_statement_2181038696, index: idx_t_2181038559
  ): cstring {.cdecl, importc: "duckdb_parameter_name".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_parameter_name" & " already exists, not redeclaring"
    )
when not declared(duckdb_param_type):
  proc duckdb_param_type*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
  ): duckdb_type_2181038533 {.cdecl, importc: "duckdb_param_type".}

else:
  static:
    hint("Declaration of " & "duckdb_param_type" & " already exists, not redeclaring")
when not declared(duckdb_param_logical_type):
  proc duckdb_param_logical_type*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_param_logical_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_param_logical_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_clear_bindings):
  proc duckdb_clear_bindings*(
    prepared_statement: duckdb_prepared_statement_2181038696
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_clear_bindings".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_clear_bindings" & " already exists, not redeclaring"
    )
when not declared(duckdb_prepared_statement_type):
  proc duckdb_prepared_statement_type*(
    statement: duckdb_prepared_statement_2181038696
  ): duckdb_statement_type_2181038549 {.
    cdecl, importc: "duckdb_prepared_statement_type"
  .}

else:
  static:
    hint(
      "Declaration of " & "duckdb_prepared_statement_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_bind_value):
  proc duckdb_bind_value*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: duckdb_value_2181038732,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_value".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_value" & " already exists, not redeclaring")
when not declared(duckdb_bind_parameter_index):
  proc duckdb_bind_parameter_index*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx_out: ptr idx_t_2181038559,
    name: cstring,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_parameter_index".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_bind_parameter_index" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_bind_boolean):
  proc duckdb_bind_boolean*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: bool,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_boolean".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_boolean" & " already exists, not redeclaring")
when not declared(duckdb_bind_int8):
  proc duckdb_bind_int8*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: int8,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_int8".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_int8" & " already exists, not redeclaring")
when not declared(duckdb_bind_int16):
  proc duckdb_bind_int16*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: int16,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_int16".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_int16" & " already exists, not redeclaring")
when not declared(duckdb_bind_int32):
  proc duckdb_bind_int32*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: int32,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_int32".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_int32" & " already exists, not redeclaring")
when not declared(duckdb_bind_int64):
  proc duckdb_bind_int64*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: int64,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_int64".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_int64" & " already exists, not redeclaring")
when not declared(duckdb_bind_hugeint):
  proc duckdb_bind_hugeint*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: duckdb_hugeint_2181038617,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_hugeint".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_hugeint" & " already exists, not redeclaring")
when not declared(duckdb_bind_uhugeint):
  proc duckdb_bind_uhugeint*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: duckdb_uhugeint_2181038628,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_uhugeint".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_bind_uhugeint" & " already exists, not redeclaring"
    )
when not declared(duckdb_bind_decimal):
  proc duckdb_bind_decimal*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: duckdb_decimal_2181038632,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_decimal".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_decimal" & " already exists, not redeclaring")
when not declared(duckdb_bind_uint8):
  proc duckdb_bind_uint8*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: uint8,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_uint8".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_uint8" & " already exists, not redeclaring")
when not declared(duckdb_bind_uint16):
  proc duckdb_bind_uint16*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: uint16,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_uint16".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_uint16" & " already exists, not redeclaring")
when not declared(duckdb_bind_uint32):
  proc duckdb_bind_uint32*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: uint32,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_uint32".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_uint32" & " already exists, not redeclaring")
when not declared(duckdb_bind_uint64):
  proc duckdb_bind_uint64*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: uint64,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_uint64".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_uint64" & " already exists, not redeclaring")
when not declared(duckdb_bind_float):
  proc duckdb_bind_float*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: cfloat,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_float".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_float" & " already exists, not redeclaring")
when not declared(duckdb_bind_double):
  proc duckdb_bind_double*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: cdouble,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_double".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_double" & " already exists, not redeclaring")
when not declared(duckdb_bind_date):
  proc duckdb_bind_date*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: duckdb_date_2181038569,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_date".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_date" & " already exists, not redeclaring")
when not declared(duckdb_bind_time):
  proc duckdb_bind_time*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: duckdb_time_2181038577,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_time".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_time" & " already exists, not redeclaring")
when not declared(duckdb_bind_timestamp):
  proc duckdb_bind_timestamp*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: duckdb_timestamp_2181038593,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_timestamp".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_bind_timestamp" & " already exists, not redeclaring"
    )
when not declared(duckdb_bind_timestamp_tz):
  proc duckdb_bind_timestamp_tz*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: duckdb_timestamp_2181038593,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_timestamp_tz".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_bind_timestamp_tz" & " already exists, not redeclaring"
    )
when not declared(duckdb_bind_interval):
  proc duckdb_bind_interval*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: duckdb_interval_2181038613,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_interval".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_bind_interval" & " already exists, not redeclaring"
    )
when not declared(duckdb_bind_varchar):
  proc duckdb_bind_varchar*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: cstring,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_varchar".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_varchar" & " already exists, not redeclaring")
when not declared(duckdb_bind_varchar_length):
  proc duckdb_bind_varchar_length*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    val: cstring,
    length: idx_t_2181038559,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_varchar_length".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_bind_varchar_length" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_bind_blob):
  proc duckdb_bind_blob*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
    data: pointer,
    length: idx_t_2181038559,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_blob".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_blob" & " already exists, not redeclaring")
when not declared(duckdb_bind_null):
  proc duckdb_bind_null*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    param_idx: idx_t_2181038559,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_bind_null".}

else:
  static:
    hint("Declaration of " & "duckdb_bind_null" & " already exists, not redeclaring")
when not declared(duckdb_execute_prepared):
  proc duckdb_execute_prepared*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    out_result: ptr duckdb_result_2181038676,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_execute_prepared".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_execute_prepared" & " already exists, not redeclaring"
    )
when not declared(duckdb_execute_prepared_streaming):
  proc duckdb_execute_prepared_streaming*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    out_result: ptr duckdb_result_2181038676,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_execute_prepared_streaming".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_execute_prepared_streaming" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_extract_statements):
  proc duckdb_extract_statements*(
    connection: duckdb_connection_2181038688,
    query: cstring,
    out_extracted_statements: ptr duckdb_extracted_statements_2181038700,
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_extract_statements".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_extract_statements" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_prepare_extracted_statement):
  proc duckdb_prepare_extracted_statement*(
    connection: duckdb_connection_2181038688,
    extracted_statements: duckdb_extracted_statements_2181038700,
    index: idx_t_2181038559,
    out_prepared_statement: ptr duckdb_prepared_statement_2181038696,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_prepare_extracted_statement".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_prepare_extracted_statement" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_extract_statements_error):
  proc duckdb_extract_statements_error*(
    extracted_statements: duckdb_extracted_statements_2181038700
  ): cstring {.cdecl, importc: "duckdb_extract_statements_error".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_extract_statements_error" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_extracted):
  proc duckdb_destroy_extracted*(
    extracted_statements: ptr duckdb_extracted_statements_2181038700
  ): void {.cdecl, importc: "duckdb_destroy_extracted".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_extracted" & " already exists, not redeclaring"
    )
when not declared(duckdb_pending_prepared):
  proc duckdb_pending_prepared*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    out_result: ptr duckdb_pending_result_2181038704,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_pending_prepared".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_pending_prepared" & " already exists, not redeclaring"
    )
when not declared(duckdb_pending_prepared_streaming):
  proc duckdb_pending_prepared_streaming*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    out_result: ptr duckdb_pending_result_2181038704,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_pending_prepared_streaming".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_pending_prepared_streaming" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_pending):
  proc duckdb_destroy_pending*(
    pending_result: ptr duckdb_pending_result_2181038704
  ): void {.cdecl, importc: "duckdb_destroy_pending".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_pending" & " already exists, not redeclaring"
    )
when not declared(duckdb_pending_error):
  proc duckdb_pending_error*(
    pending_result: duckdb_pending_result_2181038704
  ): cstring {.cdecl, importc: "duckdb_pending_error".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_pending_error" & " already exists, not redeclaring"
    )
when not declared(duckdb_pending_execute_task):
  proc duckdb_pending_execute_task*(
    pending_result: duckdb_pending_result_2181038704
  ): duckdb_pending_state_2181038541 {.cdecl, importc: "duckdb_pending_execute_task".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_pending_execute_task" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_pending_execute_check_state):
  proc duckdb_pending_execute_check_state*(
    pending_result: duckdb_pending_result_2181038704
  ): duckdb_pending_state_2181038541 {.
    cdecl, importc: "duckdb_pending_execute_check_state"
  .}

else:
  static:
    hint(
      "Declaration of " & "duckdb_pending_execute_check_state" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_execute_pending):
  proc duckdb_execute_pending*(
    pending_result: duckdb_pending_result_2181038704,
    out_result: ptr duckdb_result_2181038676,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_execute_pending".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_execute_pending" & " already exists, not redeclaring"
    )
when not declared(duckdb_pending_execution_is_finished):
  proc duckdb_pending_execution_is_finished*(
    pending_state: duckdb_pending_state_2181038541
  ): bool {.cdecl, importc: "duckdb_pending_execution_is_finished".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_pending_execution_is_finished" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_value):
  proc duckdb_destroy_value*(
    value: ptr duckdb_value_2181038732
  ): void {.cdecl, importc: "duckdb_destroy_value".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_value" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_varchar):
  proc duckdb_create_varchar*(
    text: cstring
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_varchar".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_varchar" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_varchar_length):
  proc duckdb_create_varchar_length*(
    text: cstring, length: idx_t_2181038559
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_varchar_length".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_varchar_length" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_bool):
  proc duckdb_create_bool*(
    input: bool
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_bool".}

else:
  static:
    hint("Declaration of " & "duckdb_create_bool" & " already exists, not redeclaring")
when not declared(duckdb_create_int8):
  proc duckdb_create_int8*(
    input: int8
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_int8".}

else:
  static:
    hint("Declaration of " & "duckdb_create_int8" & " already exists, not redeclaring")
when not declared(duckdb_create_uint8):
  proc duckdb_create_uint8*(
    input: uint8
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_uint8".}

else:
  static:
    hint("Declaration of " & "duckdb_create_uint8" & " already exists, not redeclaring")
when not declared(duckdb_create_int16):
  proc duckdb_create_int16*(
    input: int16
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_int16".}

else:
  static:
    hint("Declaration of " & "duckdb_create_int16" & " already exists, not redeclaring")
when not declared(duckdb_create_uint16):
  proc duckdb_create_uint16*(
    input: uint16
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_uint16".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_uint16" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_int32):
  proc duckdb_create_int32*(
    input: int32
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_int32".}

else:
  static:
    hint("Declaration of " & "duckdb_create_int32" & " already exists, not redeclaring")
when not declared(duckdb_create_uint32):
  proc duckdb_create_uint32*(
    input: uint32
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_uint32".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_uint32" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_uint64):
  proc duckdb_create_uint64*(
    input: uint64
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_uint64".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_uint64" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_int64):
  proc duckdb_create_int64*(
    val: int64
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_int64".}

else:
  static:
    hint("Declaration of " & "duckdb_create_int64" & " already exists, not redeclaring")
when not declared(duckdb_create_hugeint):
  proc duckdb_create_hugeint*(
    input: duckdb_hugeint_2181038617
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_hugeint".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_hugeint" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_uhugeint):
  proc duckdb_create_uhugeint*(
    input: duckdb_uhugeint_2181038628
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_uhugeint".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_uhugeint" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_varint):
  proc duckdb_create_varint*(
    input: duckdb_varint_2181038672
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_varint".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_varint" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_decimal):
  proc duckdb_create_decimal*(
    input: duckdb_decimal_2181038632
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_decimal".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_decimal" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_float):
  proc duckdb_create_float*(
    input: cfloat
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_float".}

else:
  static:
    hint("Declaration of " & "duckdb_create_float" & " already exists, not redeclaring")
when not declared(duckdb_create_double):
  proc duckdb_create_double*(
    input: cdouble
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_double".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_double" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_date):
  proc duckdb_create_date*(
    input: duckdb_date_2181038569
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_date".}

else:
  static:
    hint("Declaration of " & "duckdb_create_date" & " already exists, not redeclaring")
when not declared(duckdb_create_time):
  proc duckdb_create_time*(
    input: duckdb_time_2181038577
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_time".}

else:
  static:
    hint("Declaration of " & "duckdb_create_time" & " already exists, not redeclaring")
when not declared(duckdb_create_time_tz_value):
  proc duckdb_create_time_tz_value*(
    value: duckdb_time_tz_2181038585
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_time_tz_value".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_time_tz_value" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_timestamp):
  proc duckdb_create_timestamp*(
    input: duckdb_timestamp_2181038593
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_timestamp".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_timestamp" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_timestamp_tz):
  proc duckdb_create_timestamp_tz*(
    input: duckdb_timestamp_2181038593
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_timestamp_tz".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_timestamp_tz" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_timestamp_s):
  proc duckdb_create_timestamp_s*(
    input: duckdb_timestamp_s_2181038597
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_timestamp_s".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_timestamp_s" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_timestamp_ms):
  proc duckdb_create_timestamp_ms*(
    input: duckdb_timestamp_ms_2181038601
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_timestamp_ms".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_timestamp_ms" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_timestamp_ns):
  proc duckdb_create_timestamp_ns*(
    input: duckdb_timestamp_ns_2181038605
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_timestamp_ns".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_timestamp_ns" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_interval):
  proc duckdb_create_interval*(
    input: duckdb_interval_2181038613
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_interval".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_interval" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_blob):
  proc duckdb_create_blob*(
    data: ptr uint8, length: idx_t_2181038559
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_blob".}

else:
  static:
    hint("Declaration of " & "duckdb_create_blob" & " already exists, not redeclaring")
when not declared(duckdb_create_bit):
  proc duckdb_create_bit*(
    input: duckdb_bit_2181038668
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_bit".}

else:
  static:
    hint("Declaration of " & "duckdb_create_bit" & " already exists, not redeclaring")
when not declared(duckdb_create_uuid):
  proc duckdb_create_uuid*(
    input: duckdb_uhugeint_2181038628
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_uuid".}

else:
  static:
    hint("Declaration of " & "duckdb_create_uuid" & " already exists, not redeclaring")
when not declared(duckdb_get_bool):
  proc duckdb_get_bool*(
    val: duckdb_value_2181038732
  ): bool {.cdecl, importc: "duckdb_get_bool".}

else:
  static:
    hint("Declaration of " & "duckdb_get_bool" & " already exists, not redeclaring")
when not declared(duckdb_get_int8):
  proc duckdb_get_int8*(
    val: duckdb_value_2181038732
  ): int8 {.cdecl, importc: "duckdb_get_int8".}

else:
  static:
    hint("Declaration of " & "duckdb_get_int8" & " already exists, not redeclaring")
when not declared(duckdb_get_uint8):
  proc duckdb_get_uint8*(
    val: duckdb_value_2181038732
  ): uint8 {.cdecl, importc: "duckdb_get_uint8".}

else:
  static:
    hint("Declaration of " & "duckdb_get_uint8" & " already exists, not redeclaring")
when not declared(duckdb_get_int16):
  proc duckdb_get_int16*(
    val: duckdb_value_2181038732
  ): int16 {.cdecl, importc: "duckdb_get_int16".}

else:
  static:
    hint("Declaration of " & "duckdb_get_int16" & " already exists, not redeclaring")
when not declared(duckdb_get_uint16):
  proc duckdb_get_uint16*(
    val: duckdb_value_2181038732
  ): uint16 {.cdecl, importc: "duckdb_get_uint16".}

else:
  static:
    hint("Declaration of " & "duckdb_get_uint16" & " already exists, not redeclaring")
when not declared(duckdb_get_int32):
  proc duckdb_get_int32*(
    val: duckdb_value_2181038732
  ): int32 {.cdecl, importc: "duckdb_get_int32".}

else:
  static:
    hint("Declaration of " & "duckdb_get_int32" & " already exists, not redeclaring")
when not declared(duckdb_get_uint32):
  proc duckdb_get_uint32*(
    val: duckdb_value_2181038732
  ): uint32 {.cdecl, importc: "duckdb_get_uint32".}

else:
  static:
    hint("Declaration of " & "duckdb_get_uint32" & " already exists, not redeclaring")
when not declared(duckdb_get_int64):
  proc duckdb_get_int64*(
    val: duckdb_value_2181038732
  ): int64 {.cdecl, importc: "duckdb_get_int64".}

else:
  static:
    hint("Declaration of " & "duckdb_get_int64" & " already exists, not redeclaring")
when not declared(duckdb_get_uint64):
  proc duckdb_get_uint64*(
    val: duckdb_value_2181038732
  ): uint64 {.cdecl, importc: "duckdb_get_uint64".}

else:
  static:
    hint("Declaration of " & "duckdb_get_uint64" & " already exists, not redeclaring")
when not declared(duckdb_get_hugeint):
  proc duckdb_get_hugeint*(
    val: duckdb_value_2181038732
  ): duckdb_hugeint_2181038617 {.cdecl, importc: "duckdb_get_hugeint".}

else:
  static:
    hint("Declaration of " & "duckdb_get_hugeint" & " already exists, not redeclaring")
when not declared(duckdb_get_uhugeint):
  proc duckdb_get_uhugeint*(
    val: duckdb_value_2181038732
  ): duckdb_uhugeint_2181038628 {.cdecl, importc: "duckdb_get_uhugeint".}

else:
  static:
    hint("Declaration of " & "duckdb_get_uhugeint" & " already exists, not redeclaring")
when not declared(duckdb_get_varint):
  proc duckdb_get_varint*(
    val: duckdb_value_2181038732
  ): duckdb_varint_2181038672 {.cdecl, importc: "duckdb_get_varint".}

else:
  static:
    hint("Declaration of " & "duckdb_get_varint" & " already exists, not redeclaring")
when not declared(duckdb_get_decimal):
  proc duckdb_get_decimal*(
    val: duckdb_value_2181038732
  ): duckdb_decimal_2181038632 {.cdecl, importc: "duckdb_get_decimal".}

else:
  static:
    hint("Declaration of " & "duckdb_get_decimal" & " already exists, not redeclaring")
when not declared(duckdb_get_float):
  proc duckdb_get_float*(
    val: duckdb_value_2181038732
  ): cfloat {.cdecl, importc: "duckdb_get_float".}

else:
  static:
    hint("Declaration of " & "duckdb_get_float" & " already exists, not redeclaring")
when not declared(duckdb_get_double):
  proc duckdb_get_double*(
    val: duckdb_value_2181038732
  ): cdouble {.cdecl, importc: "duckdb_get_double".}

else:
  static:
    hint("Declaration of " & "duckdb_get_double" & " already exists, not redeclaring")
when not declared(duckdb_get_date):
  proc duckdb_get_date*(
    val: duckdb_value_2181038732
  ): duckdb_date_2181038569 {.cdecl, importc: "duckdb_get_date".}

else:
  static:
    hint("Declaration of " & "duckdb_get_date" & " already exists, not redeclaring")
when not declared(duckdb_get_time):
  proc duckdb_get_time*(
    val: duckdb_value_2181038732
  ): duckdb_time_2181038577 {.cdecl, importc: "duckdb_get_time".}

else:
  static:
    hint("Declaration of " & "duckdb_get_time" & " already exists, not redeclaring")
when not declared(duckdb_get_time_tz):
  proc duckdb_get_time_tz*(
    val: duckdb_value_2181038732
  ): duckdb_time_tz_2181038585 {.cdecl, importc: "duckdb_get_time_tz".}

else:
  static:
    hint("Declaration of " & "duckdb_get_time_tz" & " already exists, not redeclaring")
when not declared(duckdb_get_timestamp):
  proc duckdb_get_timestamp*(
    val: duckdb_value_2181038732
  ): duckdb_timestamp_2181038593 {.cdecl, importc: "duckdb_get_timestamp".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_get_timestamp" & " already exists, not redeclaring"
    )
when not declared(duckdb_get_timestamp_tz):
  proc duckdb_get_timestamp_tz*(
    val: duckdb_value_2181038732
  ): duckdb_timestamp_2181038593 {.cdecl, importc: "duckdb_get_timestamp_tz".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_get_timestamp_tz" & " already exists, not redeclaring"
    )
when not declared(duckdb_get_timestamp_s):
  proc duckdb_get_timestamp_s*(
    val: duckdb_value_2181038732
  ): duckdb_timestamp_s_2181038597 {.cdecl, importc: "duckdb_get_timestamp_s".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_get_timestamp_s" & " already exists, not redeclaring"
    )
when not declared(duckdb_get_timestamp_ms):
  proc duckdb_get_timestamp_ms*(
    val: duckdb_value_2181038732
  ): duckdb_timestamp_ms_2181038601 {.cdecl, importc: "duckdb_get_timestamp_ms".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_get_timestamp_ms" & " already exists, not redeclaring"
    )
when not declared(duckdb_get_timestamp_ns):
  proc duckdb_get_timestamp_ns*(
    val: duckdb_value_2181038732
  ): duckdb_timestamp_ns_2181038605 {.cdecl, importc: "duckdb_get_timestamp_ns".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_get_timestamp_ns" & " already exists, not redeclaring"
    )
when not declared(duckdb_get_interval):
  proc duckdb_get_interval*(
    val: duckdb_value_2181038732
  ): duckdb_interval_2181038613 {.cdecl, importc: "duckdb_get_interval".}

else:
  static:
    hint("Declaration of " & "duckdb_get_interval" & " already exists, not redeclaring")
when not declared(duckdb_get_value_type):
  proc duckdb_get_value_type*(
    val: duckdb_value_2181038732
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_get_value_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_get_value_type" & " already exists, not redeclaring"
    )
when not declared(duckdb_get_blob):
  proc duckdb_get_blob*(
    val: duckdb_value_2181038732
  ): duckdb_blob_2181038664 {.cdecl, importc: "duckdb_get_blob".}

else:
  static:
    hint("Declaration of " & "duckdb_get_blob" & " already exists, not redeclaring")
when not declared(duckdb_get_bit):
  proc duckdb_get_bit*(
    val: duckdb_value_2181038732
  ): duckdb_bit_2181038668 {.cdecl, importc: "duckdb_get_bit".}

else:
  static:
    hint("Declaration of " & "duckdb_get_bit" & " already exists, not redeclaring")
when not declared(duckdb_get_uuid):
  proc duckdb_get_uuid*(
    val: duckdb_value_2181038732
  ): duckdb_uhugeint_2181038628 {.cdecl, importc: "duckdb_get_uuid".}

else:
  static:
    hint("Declaration of " & "duckdb_get_uuid" & " already exists, not redeclaring")
when not declared(duckdb_get_varchar):
  proc duckdb_get_varchar*(
    value: duckdb_value_2181038732
  ): cstring {.cdecl, importc: "duckdb_get_varchar".}

else:
  static:
    hint("Declaration of " & "duckdb_get_varchar" & " already exists, not redeclaring")
when not declared(duckdb_create_struct_value):
  proc duckdb_create_struct_value*(
    type_arg: duckdb_logical_type_2181038720, values: ptr duckdb_value_2181038732
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_struct_value".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_struct_value" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_list_value):
  proc duckdb_create_list_value*(
    type_arg: duckdb_logical_type_2181038720,
    values: ptr duckdb_value_2181038732,
    value_count: idx_t_2181038559,
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_list_value".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_list_value" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_array_value):
  proc duckdb_create_array_value*(
    type_arg: duckdb_logical_type_2181038720,
    values: ptr duckdb_value_2181038732,
    value_count: idx_t_2181038559,
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_array_value".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_array_value" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_map_value):
  proc duckdb_create_map_value*(
    map_type: duckdb_logical_type_2181038720,
    keys: ptr duckdb_value_2181038732,
    values: ptr duckdb_value_2181038732,
    entry_count: idx_t_2181038559,
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_map_value".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_map_value" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_union_value):
  proc duckdb_create_union_value*(
    union_type: duckdb_logical_type_2181038720,
    tag_index: idx_t_2181038559,
    value: duckdb_value_2181038732,
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_union_value".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_union_value" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_get_map_size):
  proc duckdb_get_map_size*(
    value: duckdb_value_2181038732
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_get_map_size".}

else:
  static:
    hint("Declaration of " & "duckdb_get_map_size" & " already exists, not redeclaring")
when not declared(duckdb_get_map_key):
  proc duckdb_get_map_key*(
    value: duckdb_value_2181038732, index: idx_t_2181038559
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_get_map_key".}

else:
  static:
    hint("Declaration of " & "duckdb_get_map_key" & " already exists, not redeclaring")
when not declared(duckdb_get_map_value):
  proc duckdb_get_map_value*(
    value: duckdb_value_2181038732, index: idx_t_2181038559
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_get_map_value".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_get_map_value" & " already exists, not redeclaring"
    )
when not declared(duckdb_is_null_value):
  proc duckdb_is_null_value*(
    value: duckdb_value_2181038732
  ): bool {.cdecl, importc: "duckdb_is_null_value".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_is_null_value" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_null_value):
  proc duckdb_create_null_value*(): duckdb_value_2181038732 {.
    cdecl, importc: "duckdb_create_null_value"
  .}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_null_value" & " already exists, not redeclaring"
    )
when not declared(duckdb_get_list_size):
  proc duckdb_get_list_size*(
    value: duckdb_value_2181038732
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_get_list_size".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_get_list_size" & " already exists, not redeclaring"
    )
when not declared(duckdb_get_list_child):
  proc duckdb_get_list_child*(
    value: duckdb_value_2181038732, index: idx_t_2181038559
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_get_list_child".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_get_list_child" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_enum_value):
  proc duckdb_create_enum_value*(
    type_arg: duckdb_logical_type_2181038720, value: uint64
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_create_enum_value".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_enum_value" & " already exists, not redeclaring"
    )
when not declared(duckdb_get_enum_value):
  proc duckdb_get_enum_value*(
    value: duckdb_value_2181038732
  ): uint64 {.cdecl, importc: "duckdb_get_enum_value".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_get_enum_value" & " already exists, not redeclaring"
    )
when not declared(duckdb_get_struct_child):
  proc duckdb_get_struct_child*(
    value: duckdb_value_2181038732, index: idx_t_2181038559
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_get_struct_child".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_get_struct_child" & " already exists, not redeclaring"
    )
when not declared(duckdb_value_to_string):
  proc duckdb_value_to_string*(
    value: duckdb_value_2181038732
  ): cstring {.cdecl, importc: "duckdb_value_to_string".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_value_to_string" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_logical_type):
  proc duckdb_create_logical_type*(
    type_arg: duckdb_type_2181038533
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_create_logical_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_logical_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_logical_type_get_alias):
  proc duckdb_logical_type_get_alias*(
    type_arg: duckdb_logical_type_2181038720
  ): cstring {.cdecl, importc: "duckdb_logical_type_get_alias".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_logical_type_get_alias" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_logical_type_set_alias):
  proc duckdb_logical_type_set_alias*(
    type_arg: duckdb_logical_type_2181038720, alias: cstring
  ): void {.cdecl, importc: "duckdb_logical_type_set_alias".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_logical_type_set_alias" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_list_type):
  proc duckdb_create_list_type*(
    type_arg: duckdb_logical_type_2181038720
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_create_list_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_list_type" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_array_type):
  proc duckdb_create_array_type*(
    type_arg: duckdb_logical_type_2181038720, array_size: idx_t_2181038559
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_create_array_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_array_type" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_map_type):
  proc duckdb_create_map_type*(
    key_type: duckdb_logical_type_2181038720, value_type: duckdb_logical_type_2181038720
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_create_map_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_map_type" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_union_type):
  proc duckdb_create_union_type*(
    member_types: ptr duckdb_logical_type_2181038720,
    member_names: ptr cstring,
    member_count: idx_t_2181038559,
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_create_union_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_union_type" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_struct_type):
  proc duckdb_create_struct_type*(
    member_types: ptr duckdb_logical_type_2181038720,
    member_names: ptr cstring,
    member_count: idx_t_2181038559,
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_create_struct_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_struct_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_enum_type):
  proc duckdb_create_enum_type*(
    member_names: ptr cstring, member_count: idx_t_2181038559
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_create_enum_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_enum_type" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_decimal_type):
  proc duckdb_create_decimal_type*(
    width: uint8, scale: uint8
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_create_decimal_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_decimal_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_get_type_id):
  proc duckdb_get_type_id*(
    type_arg: duckdb_logical_type_2181038720
  ): duckdb_type_2181038533 {.cdecl, importc: "duckdb_get_type_id".}

else:
  static:
    hint("Declaration of " & "duckdb_get_type_id" & " already exists, not redeclaring")
when not declared(duckdb_decimal_width):
  proc duckdb_decimal_width*(
    type_arg: duckdb_logical_type_2181038720
  ): uint8 {.cdecl, importc: "duckdb_decimal_width".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_decimal_width" & " already exists, not redeclaring"
    )
when not declared(duckdb_decimal_scale):
  proc duckdb_decimal_scale*(
    type_arg: duckdb_logical_type_2181038720
  ): uint8 {.cdecl, importc: "duckdb_decimal_scale".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_decimal_scale" & " already exists, not redeclaring"
    )
when not declared(duckdb_decimal_internal_type):
  proc duckdb_decimal_internal_type*(
    type_arg: duckdb_logical_type_2181038720
  ): duckdb_type_2181038533 {.cdecl, importc: "duckdb_decimal_internal_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_decimal_internal_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_enum_internal_type):
  proc duckdb_enum_internal_type*(
    type_arg: duckdb_logical_type_2181038720
  ): duckdb_type_2181038533 {.cdecl, importc: "duckdb_enum_internal_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_enum_internal_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_enum_dictionary_size):
  proc duckdb_enum_dictionary_size*(
    type_arg: duckdb_logical_type_2181038720
  ): uint32 {.cdecl, importc: "duckdb_enum_dictionary_size".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_enum_dictionary_size" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_enum_dictionary_value):
  proc duckdb_enum_dictionary_value*(
    type_arg: duckdb_logical_type_2181038720, index: idx_t_2181038559
  ): cstring {.cdecl, importc: "duckdb_enum_dictionary_value".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_enum_dictionary_value" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_list_type_child_type):
  proc duckdb_list_type_child_type*(
    type_arg: duckdb_logical_type_2181038720
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_list_type_child_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_list_type_child_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_array_type_child_type):
  proc duckdb_array_type_child_type*(
    type_arg: duckdb_logical_type_2181038720
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_array_type_child_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_array_type_child_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_array_type_array_size):
  proc duckdb_array_type_array_size*(
    type_arg: duckdb_logical_type_2181038720
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_array_type_array_size".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_array_type_array_size" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_map_type_key_type):
  proc duckdb_map_type_key_type*(
    type_arg: duckdb_logical_type_2181038720
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_map_type_key_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_map_type_key_type" & " already exists, not redeclaring"
    )
when not declared(duckdb_map_type_value_type):
  proc duckdb_map_type_value_type*(
    type_arg: duckdb_logical_type_2181038720
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_map_type_value_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_map_type_value_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_struct_type_child_count):
  proc duckdb_struct_type_child_count*(
    type_arg: duckdb_logical_type_2181038720
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_struct_type_child_count".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_struct_type_child_count" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_struct_type_child_name):
  proc duckdb_struct_type_child_name*(
    type_arg: duckdb_logical_type_2181038720, index: idx_t_2181038559
  ): cstring {.cdecl, importc: "duckdb_struct_type_child_name".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_struct_type_child_name" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_struct_type_child_type):
  proc duckdb_struct_type_child_type*(
    type_arg: duckdb_logical_type_2181038720, index: idx_t_2181038559
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_struct_type_child_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_struct_type_child_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_union_type_member_count):
  proc duckdb_union_type_member_count*(
    type_arg: duckdb_logical_type_2181038720
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_union_type_member_count".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_union_type_member_count" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_union_type_member_name):
  proc duckdb_union_type_member_name*(
    type_arg: duckdb_logical_type_2181038720, index: idx_t_2181038559
  ): cstring {.cdecl, importc: "duckdb_union_type_member_name".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_union_type_member_name" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_union_type_member_type):
  proc duckdb_union_type_member_type*(
    type_arg: duckdb_logical_type_2181038720, index: idx_t_2181038559
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_union_type_member_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_union_type_member_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_logical_type):
  proc duckdb_destroy_logical_type*(
    type_arg: ptr duckdb_logical_type_2181038720
  ): void {.cdecl, importc: "duckdb_destroy_logical_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_logical_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_register_logical_type):
  proc duckdb_register_logical_type*(
    con: duckdb_connection_2181038688,
    type_arg: duckdb_logical_type_2181038720,
    info: duckdb_create_type_info_2181038724,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_register_logical_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_register_logical_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_data_chunk):
  proc duckdb_create_data_chunk*(
    types: ptr duckdb_logical_type_2181038720, column_count: idx_t_2181038559
  ): duckdb_data_chunk_2181038728 {.cdecl, importc: "duckdb_create_data_chunk".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_data_chunk" & " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_data_chunk):
  proc duckdb_destroy_data_chunk*(
    chunk: ptr duckdb_data_chunk_2181038728
  ): void {.cdecl, importc: "duckdb_destroy_data_chunk".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_data_chunk" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_data_chunk_reset):
  proc duckdb_data_chunk_reset*(
    chunk: duckdb_data_chunk_2181038728
  ): void {.cdecl, importc: "duckdb_data_chunk_reset".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_data_chunk_reset" & " already exists, not redeclaring"
    )
when not declared(duckdb_data_chunk_get_column_count):
  proc duckdb_data_chunk_get_column_count*(
    chunk: duckdb_data_chunk_2181038728
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_data_chunk_get_column_count".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_data_chunk_get_column_count" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_data_chunk_get_vector):
  proc duckdb_data_chunk_get_vector*(
    chunk: duckdb_data_chunk_2181038728, col_idx: idx_t_2181038559
  ): duckdb_vector_2181038652 {.cdecl, importc: "duckdb_data_chunk_get_vector".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_data_chunk_get_vector" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_data_chunk_get_size):
  proc duckdb_data_chunk_get_size*(
    chunk: duckdb_data_chunk_2181038728
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_data_chunk_get_size".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_data_chunk_get_size" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_data_chunk_set_size):
  proc duckdb_data_chunk_set_size*(
    chunk: duckdb_data_chunk_2181038728, size: idx_t_2181038559
  ): void {.cdecl, importc: "duckdb_data_chunk_set_size".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_data_chunk_set_size" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_vector):
  proc duckdb_create_vector*(
    type_arg: duckdb_logical_type_2181038720, capacity: idx_t_2181038559
  ): duckdb_vector_2181038652 {.cdecl, importc: "duckdb_create_vector".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_vector" & " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_vector):
  proc duckdb_destroy_vector*(
    vector: ptr duckdb_vector_2181038652
  ): void {.cdecl, importc: "duckdb_destroy_vector".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_vector" & " already exists, not redeclaring"
    )
when not declared(duckdb_vector_get_column_type):
  proc duckdb_vector_get_column_type*(
    vector: duckdb_vector_2181038652
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_vector_get_column_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_vector_get_column_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_vector_get_data):
  proc duckdb_vector_get_data*(
    vector: duckdb_vector_2181038652
  ): pointer {.cdecl, importc: "duckdb_vector_get_data".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_vector_get_data" & " already exists, not redeclaring"
    )
when not declared(duckdb_vector_get_validity):
  proc duckdb_vector_get_validity*(
    vector: duckdb_vector_2181038652
  ): ptr uint64 {.cdecl, importc: "duckdb_vector_get_validity".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_vector_get_validity" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_vector_ensure_validity_writable):
  proc duckdb_vector_ensure_validity_writable*(
    vector: duckdb_vector_2181038652
  ): void {.cdecl, importc: "duckdb_vector_ensure_validity_writable".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_vector_ensure_validity_writable" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_vector_assign_string_element):
  proc duckdb_vector_assign_string_element*(
    vector: duckdb_vector_2181038652, index: idx_t_2181038559, str: cstring
  ): void {.cdecl, importc: "duckdb_vector_assign_string_element".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_vector_assign_string_element" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_vector_assign_string_element_len):
  proc duckdb_vector_assign_string_element_len*(
    vector: duckdb_vector_2181038652,
    index: idx_t_2181038559,
    str: cstring,
    str_len: idx_t_2181038559,
  ): void {.cdecl, importc: "duckdb_vector_assign_string_element_len".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_vector_assign_string_element_len" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_list_vector_get_child):
  proc duckdb_list_vector_get_child*(
    vector: duckdb_vector_2181038652
  ): duckdb_vector_2181038652 {.cdecl, importc: "duckdb_list_vector_get_child".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_list_vector_get_child" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_list_vector_get_size):
  proc duckdb_list_vector_get_size*(
    vector: duckdb_vector_2181038652
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_list_vector_get_size".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_list_vector_get_size" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_list_vector_set_size):
  proc duckdb_list_vector_set_size*(
    vector: duckdb_vector_2181038652, size: idx_t_2181038559
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_list_vector_set_size".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_list_vector_set_size" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_list_vector_reserve):
  proc duckdb_list_vector_reserve*(
    vector: duckdb_vector_2181038652, required_capacity: idx_t_2181038559
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_list_vector_reserve".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_list_vector_reserve" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_struct_vector_get_child):
  proc duckdb_struct_vector_get_child*(
    vector: duckdb_vector_2181038652, index: idx_t_2181038559
  ): duckdb_vector_2181038652 {.cdecl, importc: "duckdb_struct_vector_get_child".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_struct_vector_get_child" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_array_vector_get_child):
  proc duckdb_array_vector_get_child*(
    vector: duckdb_vector_2181038652
  ): duckdb_vector_2181038652 {.cdecl, importc: "duckdb_array_vector_get_child".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_array_vector_get_child" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_slice_vector):
  proc duckdb_slice_vector*(
    vector: duckdb_vector_2181038652,
    selection: duckdb_selection_vector_2181038656,
    len: idx_t_2181038559,
  ): void {.cdecl, importc: "duckdb_slice_vector".}

else:
  static:
    hint("Declaration of " & "duckdb_slice_vector" & " already exists, not redeclaring")
when not declared(duckdb_vector_reference_value):
  proc duckdb_vector_reference_value*(
    vector: duckdb_vector_2181038652, value: duckdb_value_2181038732
  ): void {.cdecl, importc: "duckdb_vector_reference_value".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_vector_reference_value" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_vector_reference_vector):
  proc duckdb_vector_reference_vector*(
    to_vector: duckdb_vector_2181038652, from_vector: duckdb_vector_2181038652
  ): void {.cdecl, importc: "duckdb_vector_reference_vector".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_vector_reference_vector" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_validity_row_is_valid):
  proc duckdb_validity_row_is_valid*(
    validity: ptr uint64, row: idx_t_2181038559
  ): bool {.cdecl, importc: "duckdb_validity_row_is_valid".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_validity_row_is_valid" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_validity_set_row_validity):
  proc duckdb_validity_set_row_validity*(
    validity: ptr uint64, row: idx_t_2181038559, valid: bool
  ): void {.cdecl, importc: "duckdb_validity_set_row_validity".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_validity_set_row_validity" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_validity_set_row_invalid):
  proc duckdb_validity_set_row_invalid*(
    validity: ptr uint64, row: idx_t_2181038559
  ): void {.cdecl, importc: "duckdb_validity_set_row_invalid".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_validity_set_row_invalid" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_validity_set_row_valid):
  proc duckdb_validity_set_row_valid*(
    validity: ptr uint64, row: idx_t_2181038559
  ): void {.cdecl, importc: "duckdb_validity_set_row_valid".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_validity_set_row_valid" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_scalar_function):
  proc duckdb_create_scalar_function*(): duckdb_scalar_function_2181038752 {.
    cdecl, importc: "duckdb_create_scalar_function"
  .}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_scalar_function" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_scalar_function):
  proc duckdb_destroy_scalar_function*(
    scalar_function: ptr duckdb_scalar_function_2181038752
  ): void {.cdecl, importc: "duckdb_destroy_scalar_function".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_scalar_function" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_set_name):
  proc duckdb_scalar_function_set_name*(
    scalar_function: duckdb_scalar_function_2181038752, name: cstring
  ): void {.cdecl, importc: "duckdb_scalar_function_set_name".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_set_name" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_set_varargs):
  proc duckdb_scalar_function_set_varargs*(
    scalar_function: duckdb_scalar_function_2181038752,
    type_arg: duckdb_logical_type_2181038720,
  ): void {.cdecl, importc: "duckdb_scalar_function_set_varargs".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_set_varargs" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_set_special_handling):
  proc duckdb_scalar_function_set_special_handling*(
    scalar_function: duckdb_scalar_function_2181038752
  ): void {.cdecl, importc: "duckdb_scalar_function_set_special_handling".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_set_special_handling" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_set_volatile):
  proc duckdb_scalar_function_set_volatile*(
    scalar_function: duckdb_scalar_function_2181038752
  ): void {.cdecl, importc: "duckdb_scalar_function_set_volatile".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_set_volatile" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_add_parameter):
  proc duckdb_scalar_function_add_parameter*(
    scalar_function: duckdb_scalar_function_2181038752,
    type_arg: duckdb_logical_type_2181038720,
  ): void {.cdecl, importc: "duckdb_scalar_function_add_parameter".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_add_parameter" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_set_return_type):
  proc duckdb_scalar_function_set_return_type*(
    scalar_function: duckdb_scalar_function_2181038752,
    type_arg: duckdb_logical_type_2181038720,
  ): void {.cdecl, importc: "duckdb_scalar_function_set_return_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_set_return_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_set_extra_info):
  proc duckdb_scalar_function_set_extra_info*(
    scalar_function: duckdb_scalar_function_2181038752,
    extra_info: pointer,
    destroy: duckdb_delete_callback_t_2181038563,
  ): void {.cdecl, importc: "duckdb_scalar_function_set_extra_info".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_set_extra_info" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_set_bind):
  proc duckdb_scalar_function_set_bind*(
    scalar_function: duckdb_scalar_function_2181038752,
    bind_arg: duckdb_scalar_function_bind_t_2181038758,
  ): void {.cdecl, importc: "duckdb_scalar_function_set_bind".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_set_bind" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_set_bind_data):
  proc duckdb_scalar_function_set_bind_data*(
    info: duckdb_bind_info_2181038748,
    bind_data: pointer,
    destroy: duckdb_delete_callback_t_2181038563,
  ): void {.cdecl, importc: "duckdb_scalar_function_set_bind_data".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_set_bind_data" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_bind_set_error):
  proc duckdb_scalar_function_bind_set_error*(
    info: duckdb_bind_info_2181038748, error: cstring
  ): void {.cdecl, importc: "duckdb_scalar_function_bind_set_error".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_bind_set_error" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_set_function):
  proc duckdb_scalar_function_set_function*(
    scalar_function: duckdb_scalar_function_2181038752,
    function: duckdb_scalar_function_t_2181038760,
  ): void {.cdecl, importc: "duckdb_scalar_function_set_function".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_set_function" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_register_scalar_function):
  proc duckdb_register_scalar_function*(
    con: duckdb_connection_2181038688,
    scalar_function: duckdb_scalar_function_2181038752,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_register_scalar_function".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_register_scalar_function" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_get_extra_info):
  proc duckdb_scalar_function_get_extra_info*(
    info: duckdb_function_info_2181038744
  ): pointer {.cdecl, importc: "duckdb_scalar_function_get_extra_info".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_get_extra_info" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_get_bind_data):
  proc duckdb_scalar_function_get_bind_data*(
    info: duckdb_function_info_2181038744
  ): pointer {.cdecl, importc: "duckdb_scalar_function_get_bind_data".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_get_bind_data" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_get_client_context):
  proc duckdb_scalar_function_get_client_context*(
    info: duckdb_bind_info_2181038748, out_context: ptr duckdb_client_context_2181038692
  ): void {.cdecl, importc: "duckdb_scalar_function_get_client_context".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_get_client_context" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_scalar_function_set_error):
  proc duckdb_scalar_function_set_error*(
    info: duckdb_function_info_2181038744, error: cstring
  ): void {.cdecl, importc: "duckdb_scalar_function_set_error".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_scalar_function_set_error" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_scalar_function_set):
  proc duckdb_create_scalar_function_set*(
    name: cstring
  ): duckdb_scalar_function_set_2181038756 {.
    cdecl, importc: "duckdb_create_scalar_function_set"
  .}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_scalar_function_set" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_scalar_function_set):
  proc duckdb_destroy_scalar_function_set*(
    scalar_function_set: ptr duckdb_scalar_function_set_2181038756
  ): void {.cdecl, importc: "duckdb_destroy_scalar_function_set".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_scalar_function_set" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_add_scalar_function_to_set):
  proc duckdb_add_scalar_function_to_set*(
    set: duckdb_scalar_function_set_2181038756,
    function: duckdb_scalar_function_2181038752,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_add_scalar_function_to_set".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_add_scalar_function_to_set" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_register_scalar_function_set):
  proc duckdb_register_scalar_function_set*(
    con: duckdb_connection_2181038688, set: duckdb_scalar_function_set_2181038756
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_register_scalar_function_set".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_register_scalar_function_set" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_selection_vector):
  proc duckdb_create_selection_vector*(
    size: idx_t_2181038559
  ): duckdb_selection_vector_2181038656 {.
    cdecl, importc: "duckdb_create_selection_vector"
  .}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_selection_vector" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_selection_vector):
  proc duckdb_destroy_selection_vector*(
    vector: duckdb_selection_vector_2181038656
  ): void {.cdecl, importc: "duckdb_destroy_selection_vector".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_selection_vector" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_selection_vector_get_data_ptr):
  proc duckdb_selection_vector_get_data_ptr*(
    vector: duckdb_selection_vector_2181038656
  ): ptr sel_t_2181038561 {.cdecl, importc: "duckdb_selection_vector_get_data_ptr".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_selection_vector_get_data_ptr" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_aggregate_function):
  proc duckdb_create_aggregate_function*(): duckdb_aggregate_function_2181038764 {.
    cdecl, importc: "duckdb_create_aggregate_function"
  .}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_aggregate_function" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_aggregate_function):
  proc duckdb_destroy_aggregate_function*(
    aggregate_function: ptr duckdb_aggregate_function_2181038764
  ): void {.cdecl, importc: "duckdb_destroy_aggregate_function".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_aggregate_function" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_aggregate_function_set_name):
  proc duckdb_aggregate_function_set_name*(
    aggregate_function: duckdb_aggregate_function_2181038764, name: cstring
  ): void {.cdecl, importc: "duckdb_aggregate_function_set_name".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_function_set_name" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_aggregate_function_add_parameter):
  proc duckdb_aggregate_function_add_parameter*(
    aggregate_function: duckdb_aggregate_function_2181038764,
    type_arg: duckdb_logical_type_2181038720,
  ): void {.cdecl, importc: "duckdb_aggregate_function_add_parameter".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_function_add_parameter" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_aggregate_function_set_return_type):
  proc duckdb_aggregate_function_set_return_type*(
    aggregate_function: duckdb_aggregate_function_2181038764,
    type_arg: duckdb_logical_type_2181038720,
  ): void {.cdecl, importc: "duckdb_aggregate_function_set_return_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_function_set_return_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_aggregate_function_set_functions):
  proc duckdb_aggregate_function_set_functions*(
    aggregate_function: duckdb_aggregate_function_2181038764,
    state_size: duckdb_aggregate_state_size_2181038774,
    state_init: duckdb_aggregate_init_t_2181038776,
    update: duckdb_aggregate_update_t_2181038780,
    combine: duckdb_aggregate_combine_t_2181038782,
    finalize: duckdb_aggregate_finalize_t_2181038784,
  ): void {.cdecl, importc: "duckdb_aggregate_function_set_functions".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_function_set_functions" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_aggregate_function_set_destructor):
  proc duckdb_aggregate_function_set_destructor*(
    aggregate_function: duckdb_aggregate_function_2181038764,
    destroy: duckdb_aggregate_destroy_t_2181038778,
  ): void {.cdecl, importc: "duckdb_aggregate_function_set_destructor".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_function_set_destructor" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_register_aggregate_function):
  proc duckdb_register_aggregate_function*(
    con: duckdb_connection_2181038688,
    aggregate_function: duckdb_aggregate_function_2181038764,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_register_aggregate_function".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_register_aggregate_function" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_aggregate_function_set_special_handling):
  proc duckdb_aggregate_function_set_special_handling*(
    aggregate_function: duckdb_aggregate_function_2181038764
  ): void {.cdecl, importc: "duckdb_aggregate_function_set_special_handling".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_function_set_special_handling" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_aggregate_function_set_extra_info):
  proc duckdb_aggregate_function_set_extra_info*(
    aggregate_function: duckdb_aggregate_function_2181038764,
    extra_info: pointer,
    destroy: duckdb_delete_callback_t_2181038563,
  ): void {.cdecl, importc: "duckdb_aggregate_function_set_extra_info".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_function_set_extra_info" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_aggregate_function_get_extra_info):
  proc duckdb_aggregate_function_get_extra_info*(
    info: duckdb_function_info_2181038744
  ): pointer {.cdecl, importc: "duckdb_aggregate_function_get_extra_info".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_function_get_extra_info" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_aggregate_function_set_error):
  proc duckdb_aggregate_function_set_error*(
    info: duckdb_function_info_2181038744, error: cstring
  ): void {.cdecl, importc: "duckdb_aggregate_function_set_error".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_aggregate_function_set_error" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_aggregate_function_set):
  proc duckdb_create_aggregate_function_set*(
    name: cstring
  ): duckdb_aggregate_function_set_2181038768 {.
    cdecl, importc: "duckdb_create_aggregate_function_set"
  .}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_aggregate_function_set" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_aggregate_function_set):
  proc duckdb_destroy_aggregate_function_set*(
    aggregate_function_set: ptr duckdb_aggregate_function_set_2181038768
  ): void {.cdecl, importc: "duckdb_destroy_aggregate_function_set".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_aggregate_function_set" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_add_aggregate_function_to_set):
  proc duckdb_add_aggregate_function_to_set*(
    set: duckdb_aggregate_function_set_2181038768,
    function: duckdb_aggregate_function_2181038764,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_add_aggregate_function_to_set".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_add_aggregate_function_to_set" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_register_aggregate_function_set):
  proc duckdb_register_aggregate_function_set*(
    con: duckdb_connection_2181038688, set: duckdb_aggregate_function_set_2181038768
  ): duckdb_state_2181038537 {.
    cdecl, importc: "duckdb_register_aggregate_function_set"
  .}

else:
  static:
    hint(
      "Declaration of " & "duckdb_register_aggregate_function_set" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_create_table_function):
  proc duckdb_create_table_function*(): duckdb_table_function_2181038788 {.
    cdecl, importc: "duckdb_create_table_function"
  .}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_table_function" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_table_function):
  proc duckdb_destroy_table_function*(
    table_function: ptr duckdb_table_function_2181038788
  ): void {.cdecl, importc: "duckdb_destroy_table_function".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_table_function" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_table_function_set_name):
  proc duckdb_table_function_set_name*(
    table_function: duckdb_table_function_2181038788, name: cstring
  ): void {.cdecl, importc: "duckdb_table_function_set_name".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_table_function_set_name" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_table_function_add_parameter):
  proc duckdb_table_function_add_parameter*(
    table_function: duckdb_table_function_2181038788,
    type_arg: duckdb_logical_type_2181038720,
  ): void {.cdecl, importc: "duckdb_table_function_add_parameter".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_table_function_add_parameter" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_table_function_add_named_parameter):
  proc duckdb_table_function_add_named_parameter*(
    table_function: duckdb_table_function_2181038788,
    name: cstring,
    type_arg: duckdb_logical_type_2181038720,
  ): void {.cdecl, importc: "duckdb_table_function_add_named_parameter".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_table_function_add_named_parameter" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_table_function_set_extra_info):
  proc duckdb_table_function_set_extra_info*(
    table_function: duckdb_table_function_2181038788,
    extra_info: pointer,
    destroy: duckdb_delete_callback_t_2181038563,
  ): void {.cdecl, importc: "duckdb_table_function_set_extra_info".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_table_function_set_extra_info" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_table_function_set_bind):
  proc duckdb_table_function_set_bind*(
    table_function: duckdb_table_function_2181038788,
    bind_arg: duckdb_table_function_bind_t_2181038794,
  ): void {.cdecl, importc: "duckdb_table_function_set_bind".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_table_function_set_bind" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_table_function_set_init):
  proc duckdb_table_function_set_init*(
    table_function: duckdb_table_function_2181038788,
    init: duckdb_table_function_init_t_2181038796,
  ): void {.cdecl, importc: "duckdb_table_function_set_init".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_table_function_set_init" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_table_function_set_local_init):
  proc duckdb_table_function_set_local_init*(
    table_function: duckdb_table_function_2181038788,
    init: duckdb_table_function_init_t_2181038796,
  ): void {.cdecl, importc: "duckdb_table_function_set_local_init".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_table_function_set_local_init" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_table_function_set_function):
  proc duckdb_table_function_set_function*(
    table_function: duckdb_table_function_2181038788,
    function: duckdb_table_function_t_2181038798,
  ): void {.cdecl, importc: "duckdb_table_function_set_function".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_table_function_set_function" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_table_function_supports_projection_pushdown):
  proc duckdb_table_function_supports_projection_pushdown*(
    table_function: duckdb_table_function_2181038788, pushdown: bool
  ): void {.cdecl, importc: "duckdb_table_function_supports_projection_pushdown".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_table_function_supports_projection_pushdown" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_register_table_function):
  proc duckdb_register_table_function*(
    con: duckdb_connection_2181038688, function: duckdb_table_function_2181038788
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_register_table_function".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_register_table_function" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_bind_get_extra_info):
  proc duckdb_bind_get_extra_info*(
    info: duckdb_bind_info_2181038748
  ): pointer {.cdecl, importc: "duckdb_bind_get_extra_info".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_bind_get_extra_info" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_bind_add_result_column):
  proc duckdb_bind_add_result_column*(
    info: duckdb_bind_info_2181038748,
    name: cstring,
    type_arg: duckdb_logical_type_2181038720,
  ): void {.cdecl, importc: "duckdb_bind_add_result_column".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_bind_add_result_column" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_bind_get_parameter_count):
  proc duckdb_bind_get_parameter_count*(
    info: duckdb_bind_info_2181038748
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_bind_get_parameter_count".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_bind_get_parameter_count" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_bind_get_parameter):
  proc duckdb_bind_get_parameter*(
    info: duckdb_bind_info_2181038748, index: idx_t_2181038559
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_bind_get_parameter".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_bind_get_parameter" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_bind_get_named_parameter):
  proc duckdb_bind_get_named_parameter*(
    info: duckdb_bind_info_2181038748, name: cstring
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_bind_get_named_parameter".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_bind_get_named_parameter" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_bind_set_bind_data):
  proc duckdb_bind_set_bind_data*(
    info: duckdb_bind_info_2181038748,
    bind_data: pointer,
    destroy: duckdb_delete_callback_t_2181038563,
  ): void {.cdecl, importc: "duckdb_bind_set_bind_data".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_bind_set_bind_data" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_bind_set_cardinality):
  proc duckdb_bind_set_cardinality*(
    info: duckdb_bind_info_2181038748, cardinality: idx_t_2181038559, is_exact: bool
  ): void {.cdecl, importc: "duckdb_bind_set_cardinality".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_bind_set_cardinality" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_bind_set_error):
  proc duckdb_bind_set_error*(
    info: duckdb_bind_info_2181038748, error: cstring
  ): void {.cdecl, importc: "duckdb_bind_set_error".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_bind_set_error" & " already exists, not redeclaring"
    )
when not declared(duckdb_init_get_extra_info):
  proc duckdb_init_get_extra_info*(
    info: duckdb_init_info_2181038792
  ): pointer {.cdecl, importc: "duckdb_init_get_extra_info".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_init_get_extra_info" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_init_get_bind_data):
  proc duckdb_init_get_bind_data*(
    info: duckdb_init_info_2181038792
  ): pointer {.cdecl, importc: "duckdb_init_get_bind_data".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_init_get_bind_data" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_init_set_init_data):
  proc duckdb_init_set_init_data*(
    info: duckdb_init_info_2181038792,
    init_data: pointer,
    destroy: duckdb_delete_callback_t_2181038563,
  ): void {.cdecl, importc: "duckdb_init_set_init_data".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_init_set_init_data" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_init_get_column_count):
  proc duckdb_init_get_column_count*(
    info: duckdb_init_info_2181038792
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_init_get_column_count".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_init_get_column_count" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_init_get_column_index):
  proc duckdb_init_get_column_index*(
    info: duckdb_init_info_2181038792, column_index: idx_t_2181038559
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_init_get_column_index".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_init_get_column_index" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_init_set_max_threads):
  proc duckdb_init_set_max_threads*(
    info: duckdb_init_info_2181038792, max_threads: idx_t_2181038559
  ): void {.cdecl, importc: "duckdb_init_set_max_threads".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_init_set_max_threads" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_init_set_error):
  proc duckdb_init_set_error*(
    info: duckdb_init_info_2181038792, error: cstring
  ): void {.cdecl, importc: "duckdb_init_set_error".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_init_set_error" & " already exists, not redeclaring"
    )
when not declared(duckdb_function_get_extra_info):
  proc duckdb_function_get_extra_info*(
    info: duckdb_function_info_2181038744
  ): pointer {.cdecl, importc: "duckdb_function_get_extra_info".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_function_get_extra_info" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_function_get_bind_data):
  proc duckdb_function_get_bind_data*(
    info: duckdb_function_info_2181038744
  ): pointer {.cdecl, importc: "duckdb_function_get_bind_data".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_function_get_bind_data" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_function_get_init_data):
  proc duckdb_function_get_init_data*(
    info: duckdb_function_info_2181038744
  ): pointer {.cdecl, importc: "duckdb_function_get_init_data".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_function_get_init_data" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_function_get_local_init_data):
  proc duckdb_function_get_local_init_data*(
    info: duckdb_function_info_2181038744
  ): pointer {.cdecl, importc: "duckdb_function_get_local_init_data".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_function_get_local_init_data" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_function_set_error):
  proc duckdb_function_set_error*(
    info: duckdb_function_info_2181038744, error: cstring
  ): void {.cdecl, importc: "duckdb_function_set_error".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_function_set_error" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_add_replacement_scan):
  proc duckdb_add_replacement_scan*(
    db: duckdb_database_2181038684,
    replacement: duckdb_replacement_callback_t_2181038810,
    extra_data: pointer,
    delete_callback: duckdb_delete_callback_t_2181038563,
  ): void {.cdecl, importc: "duckdb_add_replacement_scan".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_add_replacement_scan" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_replacement_scan_set_function_name):
  proc duckdb_replacement_scan_set_function_name*(
    info: duckdb_replacement_scan_info_2181038808, function_name: cstring
  ): void {.cdecl, importc: "duckdb_replacement_scan_set_function_name".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_replacement_scan_set_function_name" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_replacement_scan_add_parameter):
  proc duckdb_replacement_scan_add_parameter*(
    info: duckdb_replacement_scan_info_2181038808, parameter: duckdb_value_2181038732
  ): void {.cdecl, importc: "duckdb_replacement_scan_add_parameter".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_replacement_scan_add_parameter" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_replacement_scan_set_error):
  proc duckdb_replacement_scan_set_error*(
    info: duckdb_replacement_scan_info_2181038808, error: cstring
  ): void {.cdecl, importc: "duckdb_replacement_scan_set_error".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_replacement_scan_set_error" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_get_profiling_info):
  proc duckdb_get_profiling_info*(
    connection: duckdb_connection_2181038688
  ): duckdb_profiling_info_2181038736 {.cdecl, importc: "duckdb_get_profiling_info".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_get_profiling_info" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_profiling_info_get_value):
  proc duckdb_profiling_info_get_value*(
    info: duckdb_profiling_info_2181038736, key: cstring
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_profiling_info_get_value".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_profiling_info_get_value" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_profiling_info_get_metrics):
  proc duckdb_profiling_info_get_metrics*(
    info: duckdb_profiling_info_2181038736
  ): duckdb_value_2181038732 {.cdecl, importc: "duckdb_profiling_info_get_metrics".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_profiling_info_get_metrics" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_profiling_info_get_child_count):
  proc duckdb_profiling_info_get_child_count*(
    info: duckdb_profiling_info_2181038736
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_profiling_info_get_child_count".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_profiling_info_get_child_count" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_profiling_info_get_child):
  proc duckdb_profiling_info_get_child*(
    info: duckdb_profiling_info_2181038736, index: idx_t_2181038559
  ): duckdb_profiling_info_2181038736 {.
    cdecl, importc: "duckdb_profiling_info_get_child"
  .}

else:
  static:
    hint(
      "Declaration of " & "duckdb_profiling_info_get_child" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_appender_create):
  proc duckdb_appender_create*(
    connection: duckdb_connection_2181038688,
    schema: cstring,
    table: cstring,
    out_appender: ptr duckdb_appender_2181038708,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_appender_create".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_appender_create" & " already exists, not redeclaring"
    )
when not declared(duckdb_appender_create_ext):
  proc duckdb_appender_create_ext*(
    connection: duckdb_connection_2181038688,
    catalog: cstring,
    schema: cstring,
    table: cstring,
    out_appender: ptr duckdb_appender_2181038708,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_appender_create_ext".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_appender_create_ext" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_appender_column_count):
  proc duckdb_appender_column_count*(
    appender: duckdb_appender_2181038708
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_appender_column_count".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_appender_column_count" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_appender_column_type):
  proc duckdb_appender_column_type*(
    appender: duckdb_appender_2181038708, col_idx: idx_t_2181038559
  ): duckdb_logical_type_2181038720 {.cdecl, importc: "duckdb_appender_column_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_appender_column_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_appender_error):
  proc duckdb_appender_error*(
    appender: duckdb_appender_2181038708
  ): cstring {.cdecl, importc: "duckdb_appender_error".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_appender_error" & " already exists, not redeclaring"
    )
when not declared(duckdb_appender_flush):
  proc duckdb_appender_flush*(
    appender: duckdb_appender_2181038708
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_appender_flush".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_appender_flush" & " already exists, not redeclaring"
    )
when not declared(duckdb_appender_close):
  proc duckdb_appender_close*(
    appender: duckdb_appender_2181038708
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_appender_close".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_appender_close" & " already exists, not redeclaring"
    )
when not declared(duckdb_appender_destroy):
  proc duckdb_appender_destroy*(
    appender: ptr duckdb_appender_2181038708
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_appender_destroy".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_appender_destroy" & " already exists, not redeclaring"
    )
when not declared(duckdb_appender_add_column):
  proc duckdb_appender_add_column*(
    appender: duckdb_appender_2181038708, name: cstring
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_appender_add_column".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_appender_add_column" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_appender_clear_columns):
  proc duckdb_appender_clear_columns*(
    appender: duckdb_appender_2181038708
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_appender_clear_columns".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_appender_clear_columns" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_appender_begin_row):
  proc duckdb_appender_begin_row*(
    appender: duckdb_appender_2181038708
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_appender_begin_row".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_appender_begin_row" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_appender_end_row):
  proc duckdb_appender_end_row*(
    appender: duckdb_appender_2181038708
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_appender_end_row".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_appender_end_row" & " already exists, not redeclaring"
    )
when not declared(duckdb_append_default):
  proc duckdb_append_default*(
    appender: duckdb_appender_2181038708
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_default".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_append_default" & " already exists, not redeclaring"
    )
when not declared(duckdb_append_default_to_chunk):
  proc duckdb_append_default_to_chunk*(
    appender: duckdb_appender_2181038708,
    chunk: duckdb_data_chunk_2181038728,
    col: idx_t_2181038559,
    row: idx_t_2181038559,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_default_to_chunk".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_append_default_to_chunk" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_append_bool):
  proc duckdb_append_bool*(
    appender: duckdb_appender_2181038708, value: bool
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_bool".}

else:
  static:
    hint("Declaration of " & "duckdb_append_bool" & " already exists, not redeclaring")
when not declared(duckdb_append_int8):
  proc duckdb_append_int8*(
    appender: duckdb_appender_2181038708, value: int8
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_int8".}

else:
  static:
    hint("Declaration of " & "duckdb_append_int8" & " already exists, not redeclaring")
when not declared(duckdb_append_int16):
  proc duckdb_append_int16*(
    appender: duckdb_appender_2181038708, value: int16
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_int16".}

else:
  static:
    hint("Declaration of " & "duckdb_append_int16" & " already exists, not redeclaring")
when not declared(duckdb_append_int32):
  proc duckdb_append_int32*(
    appender: duckdb_appender_2181038708, value: int32
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_int32".}

else:
  static:
    hint("Declaration of " & "duckdb_append_int32" & " already exists, not redeclaring")
when not declared(duckdb_append_int64):
  proc duckdb_append_int64*(
    appender: duckdb_appender_2181038708, value: int64
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_int64".}

else:
  static:
    hint("Declaration of " & "duckdb_append_int64" & " already exists, not redeclaring")
when not declared(duckdb_append_hugeint):
  proc duckdb_append_hugeint*(
    appender: duckdb_appender_2181038708, value: duckdb_hugeint_2181038617
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_hugeint".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_append_hugeint" & " already exists, not redeclaring"
    )
when not declared(duckdb_append_uint8):
  proc duckdb_append_uint8*(
    appender: duckdb_appender_2181038708, value: uint8
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_uint8".}

else:
  static:
    hint("Declaration of " & "duckdb_append_uint8" & " already exists, not redeclaring")
when not declared(duckdb_append_uint16):
  proc duckdb_append_uint16*(
    appender: duckdb_appender_2181038708, value: uint16
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_uint16".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_append_uint16" & " already exists, not redeclaring"
    )
when not declared(duckdb_append_uint32):
  proc duckdb_append_uint32*(
    appender: duckdb_appender_2181038708, value: uint32
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_uint32".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_append_uint32" & " already exists, not redeclaring"
    )
when not declared(duckdb_append_uint64):
  proc duckdb_append_uint64*(
    appender: duckdb_appender_2181038708, value: uint64
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_uint64".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_append_uint64" & " already exists, not redeclaring"
    )
when not declared(duckdb_append_uhugeint):
  proc duckdb_append_uhugeint*(
    appender: duckdb_appender_2181038708, value: duckdb_uhugeint_2181038628
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_uhugeint".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_append_uhugeint" & " already exists, not redeclaring"
    )
when not declared(duckdb_append_float):
  proc duckdb_append_float*(
    appender: duckdb_appender_2181038708, value: cfloat
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_float".}

else:
  static:
    hint("Declaration of " & "duckdb_append_float" & " already exists, not redeclaring")
when not declared(duckdb_append_double):
  proc duckdb_append_double*(
    appender: duckdb_appender_2181038708, value: cdouble
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_double".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_append_double" & " already exists, not redeclaring"
    )
when not declared(duckdb_append_date):
  proc duckdb_append_date*(
    appender: duckdb_appender_2181038708, value: duckdb_date_2181038569
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_date".}

else:
  static:
    hint("Declaration of " & "duckdb_append_date" & " already exists, not redeclaring")
when not declared(duckdb_append_time):
  proc duckdb_append_time*(
    appender: duckdb_appender_2181038708, value: duckdb_time_2181038577
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_time".}

else:
  static:
    hint("Declaration of " & "duckdb_append_time" & " already exists, not redeclaring")
when not declared(duckdb_append_timestamp):
  proc duckdb_append_timestamp*(
    appender: duckdb_appender_2181038708, value: duckdb_timestamp_2181038593
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_timestamp".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_append_timestamp" & " already exists, not redeclaring"
    )
when not declared(duckdb_append_interval):
  proc duckdb_append_interval*(
    appender: duckdb_appender_2181038708, value: duckdb_interval_2181038613
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_interval".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_append_interval" & " already exists, not redeclaring"
    )
when not declared(duckdb_append_varchar):
  proc duckdb_append_varchar*(
    appender: duckdb_appender_2181038708, val: cstring
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_varchar".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_append_varchar" & " already exists, not redeclaring"
    )
when not declared(duckdb_append_varchar_length):
  proc duckdb_append_varchar_length*(
    appender: duckdb_appender_2181038708, val: cstring, length: idx_t_2181038559
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_varchar_length".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_append_varchar_length" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_append_blob):
  proc duckdb_append_blob*(
    appender: duckdb_appender_2181038708, data: pointer, length: idx_t_2181038559
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_blob".}

else:
  static:
    hint("Declaration of " & "duckdb_append_blob" & " already exists, not redeclaring")
when not declared(duckdb_append_null):
  proc duckdb_append_null*(
    appender: duckdb_appender_2181038708
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_null".}

else:
  static:
    hint("Declaration of " & "duckdb_append_null" & " already exists, not redeclaring")
when not declared(duckdb_append_value):
  proc duckdb_append_value*(
    appender: duckdb_appender_2181038708, value: duckdb_value_2181038732
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_value".}

else:
  static:
    hint("Declaration of " & "duckdb_append_value" & " already exists, not redeclaring")
when not declared(duckdb_append_data_chunk):
  proc duckdb_append_data_chunk*(
    appender: duckdb_appender_2181038708, chunk: duckdb_data_chunk_2181038728
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_append_data_chunk".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_append_data_chunk" & " already exists, not redeclaring"
    )
when not declared(duckdb_table_description_create):
  proc duckdb_table_description_create*(
    connection: duckdb_connection_2181038688,
    schema: cstring,
    table: cstring,
    out_arg: ptr duckdb_table_description_2181038712,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_table_description_create".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_table_description_create" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_table_description_create_ext):
  proc duckdb_table_description_create_ext*(
    connection: duckdb_connection_2181038688,
    catalog: cstring,
    schema: cstring,
    table: cstring,
    out_arg: ptr duckdb_table_description_2181038712,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_table_description_create_ext".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_table_description_create_ext" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_table_description_destroy):
  proc duckdb_table_description_destroy*(
    table_description: ptr duckdb_table_description_2181038712
  ): void {.cdecl, importc: "duckdb_table_description_destroy".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_table_description_destroy" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_table_description_error):
  proc duckdb_table_description_error*(
    table_description: duckdb_table_description_2181038712
  ): cstring {.cdecl, importc: "duckdb_table_description_error".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_table_description_error" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_column_has_default):
  proc duckdb_column_has_default*(
    table_description: duckdb_table_description_2181038712,
    index: idx_t_2181038559,
    out_arg: ptr bool,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_column_has_default".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_column_has_default" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_table_description_get_column_name):
  proc duckdb_table_description_get_column_name*(
    table_description: duckdb_table_description_2181038712, index: idx_t_2181038559
  ): cstring {.cdecl, importc: "duckdb_table_description_get_column_name".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_table_description_get_column_name" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_query_arrow):
  proc duckdb_query_arrow*(
    connection: duckdb_connection_2181038688,
    query: cstring,
    out_result: ptr duckdb_arrow_2181038814,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_query_arrow".}

else:
  static:
    hint("Declaration of " & "duckdb_query_arrow" & " already exists, not redeclaring")
when not declared(duckdb_query_arrow_schema):
  proc duckdb_query_arrow_schema*(
    result: duckdb_arrow_2181038814, out_schema: ptr duckdb_arrow_schema_2181038822
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_query_arrow_schema".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_query_arrow_schema" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_prepared_arrow_schema):
  proc duckdb_prepared_arrow_schema*(
    prepared: duckdb_prepared_statement_2181038696,
    out_schema: ptr duckdb_arrow_schema_2181038822,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_prepared_arrow_schema".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_prepared_arrow_schema" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_result_arrow_array):
  proc duckdb_result_arrow_array*(
    result: duckdb_result_2181038676,
    chunk: duckdb_data_chunk_2181038728,
    out_array: ptr duckdb_arrow_array_2181038826,
  ): void {.cdecl, importc: "duckdb_result_arrow_array".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_result_arrow_array" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_query_arrow_array):
  proc duckdb_query_arrow_array*(
    result: duckdb_arrow_2181038814, out_array: ptr duckdb_arrow_array_2181038826
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_query_arrow_array".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_query_arrow_array" & " already exists, not redeclaring"
    )
when not declared(duckdb_arrow_column_count):
  proc duckdb_arrow_column_count*(
    result: duckdb_arrow_2181038814
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_arrow_column_count".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_arrow_column_count" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_arrow_row_count):
  proc duckdb_arrow_row_count*(
    result: duckdb_arrow_2181038814
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_arrow_row_count".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_arrow_row_count" & " already exists, not redeclaring"
    )
when not declared(duckdb_arrow_rows_changed):
  proc duckdb_arrow_rows_changed*(
    result: duckdb_arrow_2181038814
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_arrow_rows_changed".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_arrow_rows_changed" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_query_arrow_error):
  proc duckdb_query_arrow_error*(
    result: duckdb_arrow_2181038814
  ): cstring {.cdecl, importc: "duckdb_query_arrow_error".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_query_arrow_error" & " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_arrow):
  proc duckdb_destroy_arrow*(
    result: ptr duckdb_arrow_2181038814
  ): void {.cdecl, importc: "duckdb_destroy_arrow".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_arrow" & " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_arrow_stream):
  proc duckdb_destroy_arrow_stream*(
    stream_p: ptr duckdb_arrow_stream_2181038818
  ): void {.cdecl, importc: "duckdb_destroy_arrow_stream".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_arrow_stream" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_execute_prepared_arrow):
  proc duckdb_execute_prepared_arrow*(
    prepared_statement: duckdb_prepared_statement_2181038696,
    out_result: ptr duckdb_arrow_2181038814,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_execute_prepared_arrow".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_execute_prepared_arrow" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_arrow_scan):
  proc duckdb_arrow_scan*(
    connection: duckdb_connection_2181038688,
    table_name: cstring,
    arrow: duckdb_arrow_stream_2181038818,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_arrow_scan".}

else:
  static:
    hint("Declaration of " & "duckdb_arrow_scan" & " already exists, not redeclaring")
when not declared(duckdb_arrow_array_scan):
  proc duckdb_arrow_array_scan*(
    connection: duckdb_connection_2181038688,
    table_name: cstring,
    arrow_schema: duckdb_arrow_schema_2181038822,
    arrow_array: duckdb_arrow_array_2181038826,
    out_stream: ptr duckdb_arrow_stream_2181038818,
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_arrow_array_scan".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_arrow_array_scan" & " already exists, not redeclaring"
    )
when not declared(duckdb_execute_tasks):
  proc duckdb_execute_tasks*(
    database: duckdb_database_2181038684, max_tasks: idx_t_2181038559
  ): void {.cdecl, importc: "duckdb_execute_tasks".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_execute_tasks" & " already exists, not redeclaring"
    )
when not declared(duckdb_create_task_state):
  proc duckdb_create_task_state*(
    database: duckdb_database_2181038684
  ): duckdb_task_state_2181038565 {.cdecl, importc: "duckdb_create_task_state".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_task_state" & " already exists, not redeclaring"
    )
when not declared(duckdb_execute_tasks_state):
  proc duckdb_execute_tasks_state*(
    state: duckdb_task_state_2181038565
  ): void {.cdecl, importc: "duckdb_execute_tasks_state".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_execute_tasks_state" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_execute_n_tasks_state):
  proc duckdb_execute_n_tasks_state*(
    state: duckdb_task_state_2181038565, max_tasks: idx_t_2181038559
  ): idx_t_2181038559 {.cdecl, importc: "duckdb_execute_n_tasks_state".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_execute_n_tasks_state" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_finish_execution):
  proc duckdb_finish_execution*(
    state: duckdb_task_state_2181038565
  ): void {.cdecl, importc: "duckdb_finish_execution".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_finish_execution" & " already exists, not redeclaring"
    )
when not declared(duckdb_task_state_is_finished):
  proc duckdb_task_state_is_finished*(
    state: duckdb_task_state_2181038565
  ): bool {.cdecl, importc: "duckdb_task_state_is_finished".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_task_state_is_finished" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_task_state):
  proc duckdb_destroy_task_state*(
    state: duckdb_task_state_2181038565
  ): void {.cdecl, importc: "duckdb_destroy_task_state".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_task_state" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_execution_is_finished):
  proc duckdb_execution_is_finished*(
    con: duckdb_connection_2181038688
  ): bool {.cdecl, importc: "duckdb_execution_is_finished".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_execution_is_finished" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_stream_fetch_chunk):
  proc duckdb_stream_fetch_chunk*(
    result: duckdb_result_2181038676
  ): duckdb_data_chunk_2181038728 {.cdecl, importc: "duckdb_stream_fetch_chunk".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_stream_fetch_chunk" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_fetch_chunk):
  proc duckdb_fetch_chunk*(
    result: duckdb_result_2181038676
  ): duckdb_data_chunk_2181038728 {.cdecl, importc: "duckdb_fetch_chunk".}

else:
  static:
    hint("Declaration of " & "duckdb_fetch_chunk" & " already exists, not redeclaring")
when not declared(duckdb_create_cast_function):
  proc duckdb_create_cast_function*(): duckdb_cast_function_2181038802 {.
    cdecl, importc: "duckdb_create_cast_function"
  .}

else:
  static:
    hint(
      "Declaration of " & "duckdb_create_cast_function" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_cast_function_set_source_type):
  proc duckdb_cast_function_set_source_type*(
    cast_function: duckdb_cast_function_2181038802,
    source_type: duckdb_logical_type_2181038720,
  ): void {.cdecl, importc: "duckdb_cast_function_set_source_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_cast_function_set_source_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_cast_function_set_target_type):
  proc duckdb_cast_function_set_target_type*(
    cast_function: duckdb_cast_function_2181038802,
    target_type: duckdb_logical_type_2181038720,
  ): void {.cdecl, importc: "duckdb_cast_function_set_target_type".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_cast_function_set_target_type" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_cast_function_set_implicit_cast_cost):
  proc duckdb_cast_function_set_implicit_cast_cost*(
    cast_function: duckdb_cast_function_2181038802, cost: int64
  ): void {.cdecl, importc: "duckdb_cast_function_set_implicit_cast_cost".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_cast_function_set_implicit_cast_cost" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_cast_function_set_function):
  proc duckdb_cast_function_set_function*(
    cast_function: duckdb_cast_function_2181038802,
    function: duckdb_cast_function_t_2181038804,
  ): void {.cdecl, importc: "duckdb_cast_function_set_function".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_cast_function_set_function" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_cast_function_set_extra_info):
  proc duckdb_cast_function_set_extra_info*(
    cast_function: duckdb_cast_function_2181038802,
    extra_info: pointer,
    destroy: duckdb_delete_callback_t_2181038563,
  ): void {.cdecl, importc: "duckdb_cast_function_set_extra_info".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_cast_function_set_extra_info" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_cast_function_get_extra_info):
  proc duckdb_cast_function_get_extra_info*(
    info: duckdb_function_info_2181038744
  ): pointer {.cdecl, importc: "duckdb_cast_function_get_extra_info".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_cast_function_get_extra_info" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_cast_function_get_cast_mode):
  proc duckdb_cast_function_get_cast_mode*(
    info: duckdb_function_info_2181038744
  ): duckdb_cast_mode_2181038557 {.
    cdecl, importc: "duckdb_cast_function_get_cast_mode"
  .}

else:
  static:
    hint(
      "Declaration of " & "duckdb_cast_function_get_cast_mode" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_cast_function_set_error):
  proc duckdb_cast_function_set_error*(
    info: duckdb_function_info_2181038744, error: cstring
  ): void {.cdecl, importc: "duckdb_cast_function_set_error".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_cast_function_set_error" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_cast_function_set_row_error):
  proc duckdb_cast_function_set_row_error*(
    info: duckdb_function_info_2181038744,
    error: cstring,
    row: idx_t_2181038559,
    output: duckdb_vector_2181038652,
  ): void {.cdecl, importc: "duckdb_cast_function_set_row_error".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_cast_function_set_row_error" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_register_cast_function):
  proc duckdb_register_cast_function*(
    con: duckdb_connection_2181038688, cast_function: duckdb_cast_function_2181038802
  ): duckdb_state_2181038537 {.cdecl, importc: "duckdb_register_cast_function".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_register_cast_function" &
        " already exists, not redeclaring"
    )
when not declared(duckdb_destroy_cast_function):
  proc duckdb_destroy_cast_function*(
    cast_function: ptr duckdb_cast_function_2181038802
  ): void {.cdecl, importc: "duckdb_destroy_cast_function".}

else:
  static:
    hint(
      "Declaration of " & "duckdb_destroy_cast_function" &
        " already exists, not redeclaring"
    )
