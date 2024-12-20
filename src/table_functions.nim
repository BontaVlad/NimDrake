import std/[macros, tables, sequtils, sugar]
import fusion/[matching, astdsl]
import /[api, datachunk, database, types, exceptions, value]

type
  FunctionInfo* = object of duckdb_function_info
  TableFunction* = ref object
    name: string
    handle: duckdb_table_function
    bindFunc: proc(info: BindInfo)
    initFunc: proc(info: InitInfo)
    initLocalFunc: proc(info: InitInfo)
    mainFunc: proc(info: FunctionInfo, chunk: duckdb_datachunk)
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

proc tableMain(info: duckdb_function_info, chunk: duckdb_datachunk) {.cdecl.} =
  let tf = cast[TableFunction](duckdb_function_get_extra_info(info))
  tf.mainFunc(info, chunk)

proc newTableFunction*(
    name: string,
    parameters: seq[LogicalType],
    bindFunc: proc(info: BindInfo),
    initFunc: proc(info: InitInfo),
    initLocalFunc: proc(info: InitInfo),
    mainFunc: proc(info: FunctionInfo, chunk: duckdb_datachunk),
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

proc arguments(params: seq[NimNode]): seq[NimNode] =
  result = newSeq[NimNode]()
  for param in params[1 ..^ 1]:
    let tp = param[^2]
    for p in param[0 ..^ 3]:
      if param[^1].kind == nnkEmpty:
        result.add(newIdentDefs(ident($p), tp))
      else:
        result.add(newIdentDefs(ident($p), tp, param[^1]))

proc createBindData(name: NimNode, params: seq[NimNode]): NimNode =
  let objFields = arguments(params)

  result = buildAst(stmtList):
    TypeSection:
      TypeDef:
        name
        empty()
        RefTy:
          ObjectTy:
            empty()
            empty()
            RecList:
              objFields

proc createInitData(name: NimNode): NimNode =
  result = quote:
    type `name` = ref object
      pos: int
      exausted: bool

proc createBindFunctionStmt(
    returnColumnName: string,
    bindDataName, bindFunctionName, destroyBindData: NimNode,
    params: seq[NimNode],
    producerReturnType: DuckType,
): NimNode =
  let typeToField = {
    DuckType.Invalid: ident"valueInvalid",
    DuckType.ANY: ident"valueInvalid",
    DuckType.VARINT: ident"valueInvalid",
    DuckType.SQLNULL: ident"valueInvalid",
    DuckType.Boolean: ident"valueBoolean",
    DuckType.TinyInt: ident"valueTinyint",
    DuckType.SmallInt: ident"valueSmallint",
    DuckType.Integer: ident"valueInteger",
    DuckType.BigInt: ident"valueBigint",
    DuckType.UTinyInt: ident"valueUTinyint",
    DuckType.USmallInt: ident"valueUSmallint",
    DuckType.UInteger: ident"valueUInteger",
    DuckType.UBigInt: ident"valueUBigint",
    DuckType.Float: ident"valueFloat",
    DuckType.Double: ident"valueDouble",
    DuckType.Timestamp: ident"valueTimestamp",
    DuckType.Date: ident"valueDate",
    DuckType.Time: ident"valueTime",
    DuckType.Interval: ident"valueInterval",
    DuckType.HugeInt: ident"valueHugeint",
    DuckType.Varchar: ident"valueVarchar",
    DuckType.Blob: ident"valueBlob",
    DuckType.Decimal: ident"valueDecimal",
    DuckType.TimestampS: ident"valueTimestampS",
    DuckType.TimestampMs: ident"valueTimestampMs",
    DuckType.TimestampNs: ident"valueTimestampNs",
    DuckType.Enum: ident"valueEnum",
    DuckType.List: ident"valueList",
    DuckType.Struct: ident"valueStruct",
    DuckType.Map: ident"valueMap",
    DuckType.UUID: ident"valueUUID",
    DuckType.Union: ident"valueUnion",
    DuckType.Bit: ident"valueBit",
    DuckType.TimeTz: ident"valueTimeTz",
  }.toTable

  var bindDataCreateStmt = newNimNode(nnkObjConstr).add(bindDataName)
  var paramCount = 0
  let paramSeqName = ident"parameter"
  for param in params[1 ..^ 1]:
    let tp = param[^2]
    for p in param[0 ..^ 3]:
      let i = newLit paramCount
      let tp = ident typeToField[newDuckType(tp)]
      let node = newNimNode(nnkExprColonExpr).add(
          p,
          quote do:
            `paramSeqName`[`i`].`tp`,
        )
      bindDataCreateStmt.add(node)
      paramCount += 1

  result = quote:
    proc `bindFunctionName`(info: BindInfo) =
      info.add_result_column(`returnColumnName`, `producerReturnType`)
      let
        `paramSeqName` = info.parameters.toSeq
        data = `bindDataCreateStmt`
      GC_ref(data)
      duckdb_bind_set_bind_data(
        info.handle, cast[ptr `bindDataName`](data), `destroyBindData`
      )

# TODO: prototype code, take what is in scalar functions and build some abstractions
# from what we learn here
macro producer*(body: typed): untyped =
  # will be refactored out(duplicated from scalar_functions.nim)

  if body.kind != nnkIteratorDef:
    error("The {.producer.} pragma can only be applied to iterator definitions.")

  body.assertMatch:
    IteratorDef:
      Sym(strVal: @name) | Postfix[_, Sym(strVal: @name)] # callback proc name
      _ # Term rewriting template
      _ # Generic params
      @formalParams # parameters passed to the callback
      @pragmas # callback pragmas
      _ # Reserved
      @implementation # callback body
      all _

  let closurePragma = pragmas.toSeq.filter(p => p.strVal == "closure")
  if len(closurePragma) == 0:
    error("Only closure iterators are supported, consider adding a {.closure.} pragma")

  let
    params = formalParams.toSeq
    producerName = ident(name)
    producerCallback = ident(name & "callBack")
    initFunctionName = genSym(nskProc, "initFunction")
    bindFunctionName = genSym(nskProc, "bindFunction")
    mainFunctionName = genSym(nskProc, "mainFunction")
    returnTp = params[0]
    producerReturnType = newDuckType(returnTp)
    bindDataName = genSym(nskType, "BindData")
    bindDataSymName = genSym(nskVar, "bindData")
    initDataName = genSym(nskType, "InitData")
    # destroyBindDataName = ident(genSym(nskProc, "destroyBind"))
    destroyBindData = genSym(nskProc, "destroyBind")
    # destroyInitDataName = genSym(nskProc, "destroyInit")
    destroyInitData = genSym(nskProc, "destroyInit")

  let bindDataNode = createBindData(bindDataName, params)
  let initDataNode = createInitData(initDataName)

  let typeDefinitions = quote("@"):
    `@ bindDataNode`
    `@ initDataNode`

    proc `@ destroyBindData`(p: pointer) {.cdecl.} =
      `=destroy`(cast[@bindDataName](p))

    proc `@ destroyInitData`(p: pointer) {.cdecl.} =
      `=destroy`(cast[`@ initDataName`](p))

  let bindFunctionStmt = createBindFunctionStmt(
    name, bindDataName, bindFunctionName, destroyBindData, params, producerReturnType
  )

  let initFunctionStmt = quote:
    proc `initFunctionName`(info: InitInfo) =
      let data = `initDataName`(pos: 0, exausted: false)
      GC_ref(data)
      duckdb_init_set_init_data(
        info.handle, cast[ptr `initDataName`](data), `destroyInitData`
      )

  let producerFactory = newNimNode(nnkIteratorDef).add(
      producerCallback,
      newEmptyNode(),
      newEmptyNode(),
      newNimNode(nnkFormalParams).add(returnTp).add(formalParams[1 ..^ 1]),
      pragmas,
      newEmptyNode(),
      implementation,
    )

  let
    producerIteratorName = ident"producerIterator"
    producerArguments = arguments(params).map(p => newDotExpr(bindDataSymName, p[0]))
    producerIterator = newLetStmt(producerIteratorName, producerCallback)
    producerInvoke = newCall(producerIteratorName, producerArguments)

  let mainFunctionStmt = quote:
    proc `mainFunctionName`(info: FunctionInfo, rawChunk: duckdb_datachunk) =
      var `bindDataSymName` = cast[`bindDataName`](duckdb_function_get_bind_data(info))
      var initInfo = cast[`initDataName`](duckdb_function_get_init_data(info))

      `producerFactory`

      let vecPtr = duckdb_data_chunk_get_vector(rawChunk, 0.idx_t)

      `producerIterator`

      var count = 0
      while not initInfo.exausted and initInfo.pos < duckdb_vector_size().int:
        let res = `producerInvoke`
        if finished(`producerIteratorName`):
          initInfo.exausted = true
          break
        vecPtr[count] = res
        count += 1
        initInfo.pos += 1
      duckdb_data_chunk_set_size(rawChunk, count.idx_t)

  var tableFunctionParameters = newSeq[NimNode]()
  for param in params[1 ..^ 1]:
    let tp = param[^2]
    for p in param[0 ..^ 3]:
      echo p.repr
      tableFunctionParameters.add(
        newCall(bindSym"newLogicalType", newLit newDuckType(tp))
      )

  let tblFuncParams = buildAst(stmtList):
    Prefix:
      ident "@"
      Bracket:
        tableFunctionParameters

  let tableFunction = quote:
    let `producerName` = newTableFunction(
      name = `name`,
      parameters = `tblFuncParams`,
      bindFunc = `bindFunctionName`,
      initFunc = `initFunctionName`,
      initLocalFunc = proc(_: InitInfo) =
        discard,
      mainFunc = `mainFunctionName`,
      extraData = nil,
      projectionPushdown = true,
    )

  result = nnkStmtList.newTree()
  result.add quote do:
    `typeDefinitions`

    `bindFunctionStmt`
    `initFunctionStmt`
    `mainFunctionStmt`

    `tableFunction`

proc register*(con: Connection, fun: TableFunction) =
  check(duckdb_register_table_function(con, fun.handle), "Failed to regiter function")

proc unregister*(con: Connection, name: string) {.discardable.} =
  discard
