import std/[tables]
import /[api, database, types, exceptions, value]

type
  FunctionInfo* = object of duckdb_function_info
  TableFunction* = ref object
    name: string
    handle: duckdb_table_function
    bindFunc: proc(info: BindInfo)
    initFunc: proc(info: InitInfo)
    initLocalFunc: proc(info: InitInfo)
    mainFunc: proc(info: FunctionInfo, chunk: DataChunk)
    extraData*: ref RootObj # globalObjects*: Table[string, DataFrame]

  BindInfo* = object
    handle*: duckdb_bind_info
    mainFunction*: TableFunction

  InitInfo* = object
    handle*: duckdb_init_info
    mainFunction*: TableFunction # globalLock::ReentrantLock

converter toC*(fi: FunctionInfo): duckdb_function_info =
  cast[duckdb_function_info](fi)

converter toNim*(fi: duckdb_function_info): FunctionInfo =
  cast[FunctionInfo](fi)

converter toCptr*(fi: ptr FunctionInfo): ptr duckdb_function_info =
  cast[ptr duckdb_function_info](fi)

proc destroyTableFunction(p: pointer) {.cdecl.} =
  let tf = cast[TableFunction](p)
  duckdb_destroy_table_function(tf.handle.addr)
  `=destroy`(tf)

proc `$`*(tf: TableFunction): string =
  result = tf.name

proc parameter_count*(info: BindInfo): int =
  duckdb_bind_get_parameter_count(info.handle).int

proc get_parameter(info: BindInfo, index: int): Value =
  result = newValue(newDuckValue(duckdb_bind_get_parameter(info.handle, index.idx_t)))

iterator parameters*(info: BindInfo): Value =
  for idx in 0 ..< info.parameter_count:
    yield info.get_parameter(idx)

proc add_result_column*(info: BindInfo, name: string, tp: LogicalType) =
  duckdb_bind_add_result_column(info.handle, name.cstring, tp.handle)

proc add_result_column*(info: BindInfo, name: string, tp: DuckType) =
  info.add_result_column(name, newLogicalType(tp))

proc tableBind(info: duckdb_bind_info) {.cdecl.} =
  let tf = cast[TableFunction](duckdb_bind_get_extra_info(info))
  tf.bindFunc(BindInfo(handle: info, mainFunction: tf))

proc tableInit(info: duckdb_init_info) {.cdecl.} =
  let tf = cast[TableFunction](duckdb_init_get_extra_info(info))
  tf.initFunc(InitInfo(handle: info, mainFunction: tf))

proc tableLocalInit(info: duckdb_init_info) {.cdecl.} =
  let tf = cast[TableFunction](duckdb_init_get_extra_info(info))
  tf.initLocalFunc(InitInfo(handle: info, mainFunction: tf))

proc tableMain(info: duckdb_function_info, chunkHandle: duckdb_datachunk) {.cdecl.} =
  let tf = cast[TableFunction](duckdb_function_get_extra_info(info))
  var chunk = newDataChunk(chunkHandle)
  GC_ref(chunk)
  tf.mainFunc(info, chunk)

proc newTableFunction*(
    name: string,
    parameters: seq[LogicalType],
    bindFunc: proc(info: BindInfo),
    initFunc: proc(info: InitInfo),
    initLocalFunc: proc(info: InitInfo),
    mainFunc: proc(info: FunctionInfo, chunk: DataChunk),
    extraData: RootRef,
    projectionPushdown: bool,
): TableFunction =
  result = TableFunction(
    name: name,
    handle: duckdb_create_table_function(),
    bindFunc: bindFunc,
    initFunc: initFunc,
    initLocalFunc: initLocalFunc,
    mainFunc: mainFunc,
    extraData: extraData,
  )

  duckdb_table_function_set_name(result.handle, name.cstring)

  for param in parameters:
    duckdb_table_function_add_parameter(result.handle, param.handle)

  GC_ref(result)
  duckdb_table_function_set_extra_info(
    result.handle, cast[ptr TableFunction](result), destroyTableFunction
  )

  # Register the callbacks
  duckdb_table_function_set_bind(result.handle, tableBind)
  duckdb_table_function_set_init(result.handle, tableInit)
  duckdb_table_function_set_local_init(result.handle, tableLocalInit)
  duckdb_table_function_set_function(result.handle, tableMain)

  duckdb_table_function_supports_projection_pushdown(result.handle, projectionPushdown)

proc register*(con: Connection, fun: TableFunction) =
  check(duckdb_register_table_function(con, fun.handle), "Failed to regiter function")

proc unregister*(con: Connection, name: string) {.discardable.} =
  discard
