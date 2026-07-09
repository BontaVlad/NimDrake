import std/[macros]
import /[ffi, database, types, exceptions]

type
  FunctionInfo* = object of duckdbFunctionInfo
  TableFunction* = ref object
    name: string
    handle: duckdbTableFunction
    bindFunc: proc(info: BindInfo)
    initFunc: proc(info: InitInfo)
    initLocalFunc: proc(info: InitInfo)
    mainFunc: proc(info: FunctionInfo, chunk: duckdbDatachunk)
    extraData*: ref RootObj # globalObjects*: Table[string, DataFrame]

  BindInfo* = object
    handle*: duckdbBindInfo
    mainFunction*: TableFunction

  InitInfo* = object
    handle*: duckdbInitInfo
    mainFunction*: TableFunction # globalLock::ReentrantLock

  BindParameter* = object
    kind*: DuckType
    isValid*: bool

converter toC*(fi: FunctionInfo): duckdbFunctionInfo =
  cast[duckdbFunctionInfo](fi)

converter toNim*(fi: duckdbFunctionInfo): FunctionInfo =
  cast[FunctionInfo](fi)

converter toCptr*(fi: ptr FunctionInfo): ptr duckdbFunctionInfo =
  cast[ptr duckdbFunctionInfo](fi)

proc destroyTableFunction(p: pointer) {.cdecl.} =
  let tf = cast[TableFunction](p)
  duckdbDestroyTableFunction(tf.handle.addr)
  `=destroy`(tf)

proc `$`*(tf: TableFunction): string =
  result = tf.name

proc parameterCount*(info: BindInfo): int =
  duckdbBindGetParameterCount(info.handle).int

proc getParameter(info: BindInfo, index: int): BindParameter =
  let handle = duckdbBindGetParameter(info.handle, index.idx_t)
  let logicalTp = duckdb_get_value_type(handle)
  let kind = toDuckType(duckdbGetTypeId(logicalTp))
  result = BindParameter(kind: kind, isValid: not duckdb_is_null_value(handle).bool)

iterator parameters*(info: BindInfo): BindParameter =
  for idx in 0 ..< info.parameterCount:
    yield info.getParameter(idx)

proc addResultColumn*(info: BindInfo, name: string, tp: LogicalType) =
  duckdbBindAddResultColumn(info.handle, name.cstring, tp.handle)

proc addResultColumn*(info: BindInfo, name: string, tp: DuckType) =
  info.addResultColumn(name, newLogicalType(tp))

proc tableBind(info: duckdbBindInfo) {.cdecl.} =
  let tf = cast[TableFunction](duckdbBindGetExtraInfo(info))
  tf.bindFunc(BindInfo(handle: info, mainFunction: tf))

proc tableInit(info: duckdbInitInfo) {.cdecl.} =
  let tf = cast[TableFunction](duckdbInitGetExtraInfo(info))
  tf.initFunc(InitInfo(handle: info, mainFunction: tf))

proc tableLocalInit(info: duckdbInitInfo) {.cdecl.} =
  let tf = cast[TableFunction](duckdbInitGetExtraInfo(info))
  tf.initLocalFunc(InitInfo(handle: info, mainFunction: tf))

proc tableMain(info: duckdbFunctionInfo, chunk: duckdbDatachunk) {.cdecl.} =
  let tf = cast[TableFunction](duckdbFunctionGetExtraInfo(info))
  tf.mainFunc(info, chunk)

proc newTableFunction*(
    name: string,
    parameters: seq[LogicalType],
    bindFunc: proc(info: BindInfo),
    initFunc: proc(info: InitInfo),
    initLocalFunc: proc(info: InitInfo),
    mainFunc: proc(info: FunctionInfo, chunk: duckdbDatachunk),
    extraData: RootRef,
    projectionPushdown: bool,
): TableFunction =
  result = TableFunction(
    name: name,
    handle: duckdbCreateTableFunction(),
    bindFunc: bindFunc,
    initFunc: initFunc,
    initLocalFunc: initLocalFunc,
    mainFunc: mainFunc,
    extraData: extraData,
  )

  duckdbTableFunctionSetName(result.handle, name.cstring)

  for param in parameters:
    duckdbTableFunctionAddParameter(result.handle, param.handle)

  GC_ref(result)
  duckdbTableFunctionSetExtraInfo(
    result.handle, cast[ptr TableFunction](result), destroyTableFunction
  )

  # Register the callbacks
  duckdbTableFunctionSetBind(result.handle, tableBind)
  duckdbTableFunctionSetInit(result.handle, tableInit)
  duckdbTableFunctionSetLocalInit(result.handle, tableLocalInit)
  duckdbTableFunctionSetFunction(result.handle, tableMain)

  duckdbTableFunctionSupportsProjectionPushdown(result.handle, projectionPushdown)

macro producer*(body: typed): untyped =
  ## UDF table macro — currently stubbed. Will be revived in a future pass.
  if body.kind != nnkIteratorDef:
    error("The {.producer.} pragma can only be applied to iterator definitions.")
  result = quote do:
    raise newException(
      OperationError,
      "UDF table macros need updating for the new qresult/Vector[kt] API.",
    )

proc register*(con: Connection, fun: TableFunction) =
  check(
    duckdbRegisterTableFunction(con.rawHandle, fun.handle), "Failed to regiter function"
  )
