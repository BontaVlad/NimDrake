import std/[macros, strformat]
import /[ffi, database, types, qresult, exceptions]
import /tools/wrench

type
  FunctionInfo* = object
    handle*: duckdb_function_info

  TableFunctionBase* = object of RootObj
    name*: string
    handle*: duckdb_table_function
    bindProc: proc(info: BindInfo) {.cdecl.}
    initProc: proc(info: InitInfo) {.cdecl.}
    initLocalProc: proc(info: InitInfo) {.cdecl.}
    mainProc: proc(info: FunctionInfo, chunk: duckdb_data_chunk) {.cdecl.}

  TableFunction* = ref object of TableFunctionBase
    extraData*: ref RootObj

  BindInfo* = object
    handle*: duckdb_bind_info

  InitInfo* = object
    handle*: duckdb_init_info

proc `=destroy`(tf: TableFunctionBase) =
  if tf.handle != nil:
    duckdb_destroy_table_function(tf.handle.addr)

proc `=wasMoved`(tf: var TableFunctionBase) =
  tf.handle = nil
  tf.name = ""

proc `$`*(tf: TableFunction): string =
  tf.name

# ---------------------------------------------------------------------------
# BindInfo accessors
# ---------------------------------------------------------------------------

proc parameterCount*(info: BindInfo): int =
  duckdb_bind_get_parameter_count(info.handle).int

proc getParameter*(info: BindInfo, index: int): duckdb_value =
  duckdb_bind_get_parameter(info.handle, index.idx_t)

proc getNamedParameter*(info: BindInfo, name: string): duckdb_value =
  duckdb_bind_get_named_parameter(info.handle, name.cstring)

iterator parameters*(info: BindInfo): duckdb_value =
  for idx in 0 ..< info.parameterCount:
    yield info.getParameter(idx)

proc addResultColumn*(info: BindInfo, name: string, tp: LogicalType) =
  duckdb_bind_add_result_column(info.handle, name.cstring, tp.handle)

proc addResultColumn*(info: BindInfo, name: string, tp: DuckType) =
  info.addResultColumn(name, newLogicalType(tp))

proc setBindData*(info: BindInfo, data: pointer, destroy: duckdb_delete_callback_t) =
  duckdb_bind_set_bind_data(info.handle, data, destroy)

proc setCardinality*(info: BindInfo, cardinality: int, isExact: bool) =
  duckdb_bind_set_cardinality(info.handle, cardinality.idx_t, isExact)

proc setError*(info: BindInfo, msg: string) =
  duckdb_bind_set_error(info.handle, msg.cstring)

# ---------------------------------------------------------------------------
# InitInfo accessors
# ---------------------------------------------------------------------------

proc getBindData*(info: InitInfo): pointer =
  duckdb_init_get_bind_data(info.handle)

proc setInitData*(info: InitInfo, data: pointer, destroy: duckdb_delete_callback_t) =
  duckdb_init_set_init_data(info.handle, data, destroy)

proc columnCount*(info: InitInfo): int =
  duckdb_init_get_column_count(info.handle).int

proc columnIndex*(info: InitInfo, col: int): int =
  duckdb_init_get_column_index(info.handle, col.idx_t).int

proc setMaxThreads*(info: InitInfo, maxThreads: int) =
  duckdb_init_set_max_threads(info.handle, maxThreads.idx_t)

proc setError*(info: InitInfo, msg: string) =
  duckdb_init_set_error(info.handle, msg.cstring)

# ---------------------------------------------------------------------------
# FunctionInfo accessors
# ---------------------------------------------------------------------------

proc getBindData*(info: FunctionInfo): pointer =
  duckdb_function_get_bind_data(info.handle)

proc getInitData*(info: FunctionInfo): pointer =
  duckdb_function_get_init_data(info.handle)

proc getLocalInitData*(info: FunctionInfo): pointer =
  duckdb_function_get_local_init_data(info.handle)

proc setError*(info: FunctionInfo, msg: string) =
  duckdb_function_set_error(info.handle, msg.cstring)

# ---------------------------------------------------------------------------
# Internal callback wrappers
# ---------------------------------------------------------------------------

proc destroyExtraInfo(p: pointer) {.cdecl.} =
  if p != nil:
    GC_unref(cast[ref RootObj](p))

proc tableBind(info: duckdb_bind_info) {.cdecl.} =
  let tf = cast[ptr TableFunctionBase](duckdb_bind_get_extra_info(info))
  if tf[].bindProc != nil:
    tf[].bindProc(BindInfo(handle: info))

proc tableInit(info: duckdb_init_info) {.cdecl.} =
  let tf = cast[ptr TableFunctionBase](duckdb_init_get_extra_info(info))
  if tf[].initProc != nil:
    tf[].initProc(InitInfo(handle: info))

proc tableLocalInit(info: duckdb_init_info) {.cdecl.} =
  let tf = cast[ptr TableFunctionBase](duckdb_init_get_extra_info(info))
  if tf[].initLocalProc != nil:
    tf[].initLocalProc(InitInfo(handle: info))

proc tableMain(info: duckdb_function_info, chunk: duckdb_data_chunk) {.cdecl.} =
  let tf = cast[ptr TableFunctionBase](duckdb_function_get_extra_info(info))
  if tf[].mainProc != nil:
    tf[].mainProc(FunctionInfo(handle: info), chunk)

# ---------------------------------------------------------------------------
# Low-level table function construction
# ---------------------------------------------------------------------------

proc newTableFunction*(
    name: string,
    parameters: seq[LogicalType] = @[],
    bindProc: proc(info: BindInfo) {.cdecl.} = nil,
    initProc: proc(info: InitInfo) {.cdecl.} = nil,
    initLocalProc: proc(info: InitInfo) {.cdecl.} = nil,
    mainProc: proc(info: FunctionInfo, chunk: duckdb_data_chunk) {.cdecl.} = nil,
    extraData: ref RootObj = nil,
    projectionPushdown: bool = false,
): TableFunction =
  result = TableFunction(
    name: name,
    handle: duckdb_create_table_function(),
    bindProc: bindProc,
    initProc: initProc,
    initLocalProc: initLocalProc,
    mainProc: mainProc,
    extraData: extraData,
  )
  duckdb_table_function_set_name(result.handle, name.cstring)

  for param in parameters:
    duckdb_table_function_add_parameter(result.handle, param.handle)

  GC_ref(result)
  duckdb_table_function_set_extra_info(
    result.handle, cast[pointer](result), destroyExtraInfo)
  duckdb_table_function_set_bind(result.handle, tableBind)
  duckdb_table_function_set_init(result.handle, tableInit)
  duckdb_table_function_set_local_init(result.handle, tableLocalInit)
  duckdb_table_function_set_function(result.handle, tableMain)

  duckdb_table_function_supports_projection_pushdown(result.handle, projectionPushdown)

proc register*(con: Connection, fun: TableFunction) =
  check(
    duckdb_register_table_function(con.rawHandle, fun.handle),
    fmt"Failed to register table function '{fun.name}'",
  )

# ---------------------------------------------------------------------------
# registerTableFunction macro — closure iterator → DuckDB table function
# ---------------------------------------------------------------------------

macro registerTableFunction*(con: typed, iterSym: typed,
    extraArgs: varargs[untyped]): untyped =
  proc getter(nmt: string, val: NimNode): NimNode =
    case nmt
    of "bool": newCall(bindSym"duckdb_get_bool", val)
    of "int8": newCall(bindSym"duckdb_get_int8", val)
    of "int16": newCall(bindSym"duckdb_get_int16", val)
    of "int32": newCall(bindSym"duckdb_get_int32", val)
    of "int64": newCall(bindSym"duckdb_get_int64", val)
    of "int": nnkCall.newTree(ident"int",
      newCall(bindSym"duckdb_get_int64", val))
    of "uint8", "byte": newCall(bindSym"duckdb_get_uint8", val)
    of "uint16": newCall(bindSym"duckdb_get_uint16", val)
    of "uint32": newCall(bindSym"duckdb_get_uint32", val)
    of "uint64", "uint": newCall(bindSym"duckdb_get_uint64", val)
    of "float32": nnkCast.newTree(ident"float32",
      newCall(bindSym"duckdb_get_float", val))
    of "float64", "float": nnkCast.newTree(ident"float64",
      newCall(bindSym"duckdb_get_double", val))
    of "string": nnkPrefix.newTree(ident"$",
      newCall(bindSym"duckdb_get_varchar", val))
    of "DateTime": nnkCall.newTree(ident"DateTime",
      newDotExpr(newCall(bindSym"duckdb_get_timestamp", val), ident"micros"))
    of "Time": nnkCall.newTree(ident"Time",
      newDotExpr(newCall(bindSym"duckdb_get_time", val), ident"micros"))
    else:
      error("unsupported bind-param type: " & nmt, val)

  let iterDef = iterSym.getImpl
  if iterDef.kind != nnkIteratorDef:
    error("registerTableFunction expects an iterator; got " & $iterDef.kind, iterSym)
  if iterDef[2].kind != nnkEmpty:
    error("registerTableFunction iterators cannot be generic.", iterSym)

  let pragmaNode = iterDef[4]
  proc hasClosurePragma(node: NimNode): bool =
    for ch in node:
      let s = if ch.kind == nnkIdent: ch.strVal elif ch.kind == nnkSym: ch.strVal else: ""
      if s == "closure": return true



  let hasClosure = pragmaNode.kind == nnkPragma and hasClosurePragma(pragmaNode)
  if not hasClosure:
    error("registerTableFunction requires a {.closure.} iterator.", iterSym)

  let formalParams = iterDef[3]
  let nameStr = iterSym.strVal

  let retTypeNode = formalParams[0]
  if retTypeNode.kind == nnkEmpty:
    error("registerTableFunction iterator must have a return type.", iterSym)

  let retTypeInst = getTypeInst(retTypeNode)

  type ColSpec = tuple
    name: string
    ktNode: NimNode
    fieldIdx: int
    isOption: bool

  proc extractCol(fieldType: NimNode, name: string, idx: int): ColSpec =
    let tinst = getTypeInst(fieldType)
    if tinst.kind == nnkBracketExpr and tinst[0].strVal == "Option":
      let innerNode = tinst[1]
      let ktn = duckTypeDotExpr(getTypeInst(innerNode))
      result = (name, ktn, idx, true)
    else:
      let ktn = duckTypeDotExpr(tinst)
      result = (name, ktn, idx, false)

  var outCols: seq[ColSpec]

  if retTypeInst.kind in {nnkTupleConstr, nnkTupleTy}:
    for i, child in retTypeInst:
      if child.kind == nnkIdentDefs:
        let fieldName = $child[0]
        outCols.add(extractCol(child[1], fieldName, i))
      else:
        outCols.add(extractCol(child, "col" & $i, i))
  else:
    outCols.add(extractCol(retTypeInst, nameStr, 0))

  let isMultiCol = outCols.len > 1

  var cardinalityExpr: NimNode = nil
  var cardinalityExact = false
  var namedParams = false
  var localInitExpr: NimNode = nil
  var columnNamesExpr: NimNode = nil

  for arg in extraArgs:
    if arg.kind == nnkExprEqExpr:
      let key = if arg[0].kind == nnkIdent: arg[0].strVal else: ""
      if key == "cardinality":
        cardinalityExpr = arg[1]
      elif key == "exact":
        cardinalityExact = arg[1].kind == nnkIdent and arg[1].strVal == "true"
      elif key == "named":
        namedParams = arg[1].kind == nnkIdent and arg[1].strVal == "true"
      elif key == "columnNames":
        columnNamesExpr = arg[1]
      elif key == "localInit":
        localInitExpr = arg[1]

  if columnNamesExpr != nil and columnNamesExpr.kind == nnkPrefix and
     columnNamesExpr[0].kind == nnkIdent and columnNamesExpr[0].strVal == "@" and
     columnNamesExpr[1].kind == nnkBracket:
    let namesNode = columnNamesExpr[1]
    for i in 0 ..< min(outCols.len, namesNode.len):
      if namesNode[i].kind == nnkStrLit:
        let newName = namesNode[i].strVal
        outCols[i].name = newName

  type Param = tuple[
    sym: NimNode, kt: NimNode, innerType: string,
    isOption: bool, typeNode: NimNode]
  var params: seq[Param]
  for j in 1 ..< formalParams.len:
    let id = formalParams[j]
    if id[^1].kind != nnkEmpty:
      error("registerTableFunction iterator params cannot have default values.", id)
    let tyNode = getTypeInst(id[^2])
    var kt: NimNode
    var innerT: string
    var isOpt = false
    if tyNode.kind == nnkBracketExpr and tyNode[0].strVal == "Option":
      let innerNode = tyNode[1]          # original (e.g. "int")
      kt = duckTypeDotExpr(getTypeInst(innerNode))
      innerT = repr(innerNode)
      isOpt = true
    else:
      kt = duckTypeDotExpr(tyNode)
      innerT = repr(tyNode)
    for k in 0 ..< id.len - 2:
      params.add((id[k], kt, innerT, isOpt, tyNode))

  let
    bindDataName = genSym(nskType, "BindData")
    initDataName = genSym(nskType, "InitData")
    bindProcName = genSym(nskProc, "bindProc")
    initProcName = genSym(nskProc, "initProc")
    mainProcName = genSym(nskProc, "mainProc")
    destroyBindName = genSym(nskProc, "destroyBind")
    destroyInitName = genSym(nskProc, "destroyInit")
    tfName = genSym(nskLet, "tf_")

  result = newStmtList()

  # --- BindData type ---
  var bindFields = newSeq[NimNode]()
  for p in params:
    bindFields.add(newIdentDefs(ident p.sym.strVal, p.typeNode))

  result.add(nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      bindDataName,
      newEmptyNode(),
      nnkRefTy.newTree(nnkObjectTy.newTree(
        newEmptyNode(),
        newEmptyNode(),
        nnkRecList.newTree(bindFields))))))

  # --- destroyBind ---
  result.add(newProc(
    name = destroyBindName,
    params = [newEmptyNode(),
      newIdentDefs(ident"p", bindSym"pointer")],
    body = newStmtList(
      newCall(bindSym"=destroy",
        nnkCast.newTree(bindDataName, ident"p"))),
    pragmas = nnkPragma.newTree(ident"cdecl")))

  # --- Bind proc ---
  var bindBody = newStmtList()
  bindBody.add(newLetStmt(ident"data",
    nnkCall.newTree(newDotExpr(bindDataName, ident"new"))))

  # Read each parameter
  for i, p in params:
    let valId = genSym(nskLet, "paramVal")
    if namedParams:
      bindBody.add(newLetStmt(valId,
        newCall(bindSym"duckdb_bind_get_named_parameter", ident"info",
          newDotExpr(newLit p.sym.strVal, ident"cstring"))))
    else:
      bindBody.add(newLetStmt(valId,
        newCall(bindSym"duckdb_bind_get_parameter", ident"info",
          newCall(bindSym"idx_t", newLit i))))

    let isNullCheck = newCall(bindSym"duckdb_is_null_value", valId)
    let field = newDotExpr(ident"data", ident p.sym.strVal)

    if p.isOption:
      bindBody.add(
        nnkIfStmt.newTree(
          nnkElifBranch.newTree(isNullCheck,
            newStmtList(
              nnkAsgn.newTree(field,
                nnkCall.newTree(ident"none", ident p.innerType)))),
          nnkElse.newTree(
            newStmtList(
              nnkAsgn.newTree(field,
                nnkCall.newTree(ident"some",
                  getter(p.innerType, valId)))))))
    else:
      bindBody.add(
        nnkIfStmt.newTree(
          nnkElifBranch.newTree(isNullCheck,
            newStmtList(
              newCall(bindSym"duckdb_destroy_value",
                nnkPrefix.newTree(ident"addr", valId)),
              newCall(bindSym"duckdb_bind_set_error", ident"info",
                newLit("parameter " & $i & " is NULL but type is not Option[" &
                  p.innerType & "]")),
              nnkReturnStmt.newTree(newEmptyNode())))))
      bindBody.add(
        nnkAsgn.newTree(field, getter(p.innerType, valId)))

    bindBody.add(newCall(bindSym"duckdb_destroy_value",
      nnkPrefix.newTree(ident"addr", valId)))

  for i, col in outCols:
    bindBody.add(newCall(bindSym"duckdb_bind_add_result_column",
      ident"info",
      newDotExpr(newLit col.name, ident"cstring"),
      newDotExpr(newCall(bindSym"newLogicalType", col.ktNode), ident"handle")))

  if cardinalityExpr != nil:
    bindBody.add(newCall(bindSym"duckdb_bind_set_cardinality",
      ident"info",
      nnkCall.newTree(ident"idx_t", cardinalityExpr),
      if cardinalityExact: ident"true" else: ident"false"))

  bindBody.add(newCall(bindSym"GC_ref", ident"data"))
  bindBody.add(newCall(bindSym"duckdb_bind_set_bind_data",
    ident"info",
    nnkCast.newTree(bindSym"pointer", ident"data"),
    destroyBindName))

  result.add(newProc(
    name = bindProcName,
    params = [newEmptyNode(),
      newIdentDefs(ident"info", bindSym"duckdb_bind_info")],
    body = bindBody,
    pragmas = nnkPragma.newTree(ident"cdecl")))

  # --- InitData type ---
  let iterTy = nnkIteratorTy.newTree(
    nnkFormalParams.newTree(retTypeNode),
    nnkPragma.newTree(ident"closure"))

  result.add(nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      initDataName,
      newEmptyNode(),
      nnkRefTy.newTree(nnkObjectTy.newTree(
        newEmptyNode(),
        newEmptyNode(),
        nnkRecList.newTree(
          newIdentDefs(ident"iter", iterTy),
          newIdentDefs(ident"projectedIds",
            nnkBracketExpr.newTree(ident"seq", ident"int"))))))))

  # --- destroyInit ---
  result.add(newProc(
    name = destroyInitName,
    params = [newEmptyNode(),
      newIdentDefs(ident"p", bindSym"pointer")],
    body = newStmtList(
      newCall(bindSym"=destroy",
        nnkCast.newTree(initDataName, ident"p"))),
    pragmas = nnkPragma.newTree(ident"cdecl")))

  # --- Init proc ---
  var initBody = newStmtList()

  initBody.add(newLetStmt(ident"bindData",
    nnkCast.newTree(bindDataName,
      newCall(bindSym"duckdb_init_get_bind_data", ident"info"))))

  var iterCallArgs = newSeq[NimNode]()
  for p in params:
    iterCallArgs.add(newDotExpr(ident"bindData", ident p.sym.strVal))

  let wrapperSym = genSym(nskIterator, "wrapper")
  let forBody = newStmtList(nnkYieldStmt.newTree(ident"val"))
  let forStmt = nnkForStmt.newTree(
    ident"val",
    newCall(iterSym, iterCallArgs),
    forBody)
  let wrapperIter = nnkIteratorDef.newTree(
    wrapperSym,
    newEmptyNode(),
    newEmptyNode(),
    nnkFormalParams.newTree(retTypeNode),
    nnkPragma.newTree(ident"closure"),
    newEmptyNode(),
    forStmt)
  initBody.add(wrapperIter)

  initBody.add(newVarStmt(ident"pids",
    nnkCall.newTree(
      nnkBracketExpr.newTree(ident"newSeq", ident"int"),
      newCall(bindSym"int",
        newCall(bindSym"duckdb_init_get_column_count", ident"info")))))
  initBody.add(nnkForStmt.newTree(
    ident"p",
    nnkInfix.newTree(ident"..<", newLit 0,
      newDotExpr(ident"pids", ident"len")),
    nnkAsgn.newTree(
      nnkBracketExpr.newTree(ident"pids", ident"p"),
      newCall(bindSym"int",
        newCall(bindSym"duckdb_init_get_column_index",
          ident"info", nnkCall.newTree(ident"idx_t", ident"p"))))))

  initBody.add(newLetStmt(ident"data",
    nnkObjConstr.newTree(
      initDataName,
      nnkExprColonExpr.newTree(ident"iter", wrapperSym),
      nnkExprColonExpr.newTree(ident"projectedIds", ident"pids"))))

  initBody.add(newCall(bindSym"GC_ref", ident"data"))
  initBody.add(newCall(bindSym"duckdb_init_set_init_data",
    ident"info",
    nnkCast.newTree(bindSym"pointer", ident"data"),
    destroyInitName))

  result.add(newProc(
    name = initProcName,
    params = [newEmptyNode(),
      newIdentDefs(ident"info", bindSym"duckdb_init_info")],
    body = initBody,
    pragmas = nnkPragma.newTree(ident"cdecl")))

  # --- Main proc ---
  let rawSym = ident"rawChunk"
  let itSym = genSym(nskVar, "it")
  let countSym = genSym(nskVar, "count")

  var mainBody = newStmtList()

  mainBody.add(newLetStmt(ident"initData",
    nnkCast.newTree(initDataName,
      newCall(bindSym"duckdb_function_get_init_data", ident"info"))))

  mainBody.add(newVarStmt(itSym,
    newDotExpr(ident"initData", ident"iter")))

  let sizeSym = genSym(nskLet, "size")
  mainBody.add(newLetStmt(sizeSym,
    newCall(bindSym"int",
      newCall(bindSym"duckdb_vector_size"))))

  if not isMultiCol:
    # ── Single-column fast path ──
    let col = outCols[0]
    let retKt = col.ktNode
    let outVecSym = genSym(nskVar, "outVec")
    let valSym = genSym(nskLet, "val")

    let outVecRaw = genSym(nskLet, "outVecRaw")
    mainBody.add(newLetStmt(outVecRaw,
      newCall(bindSym"duckdb_data_chunk_get_vector",
        rawSym, newCall(bindSym"idx_t", newLit 0))))
    mainBody.add(newVarStmt(outVecSym,
      newCall(nnkBracketExpr.newTree(bindSym"initVector", retKt),
        outVecRaw, sizeSym)))

    mainBody.add(newVarStmt(countSym, newLit 0))
    let whle = nnkWhileStmt.newTree(
      nnkInfix.newTree(ident"<", countSym, sizeSym),
      newStmtList())
    let loopBody = whle[1]
    loopBody.add(newLetStmt(valSym, newCall(itSym)))
    loopBody.add(nnkIfStmt.newTree(
      nnkElifBranch.newTree(
        newCall(bindSym"finished", itSym),
        nnkBreakStmt.newTree(newEmptyNode()))))

    if col.isOption:
      loopBody.add(nnkIfStmt.newTree(
        nnkElifBranch.newTree(
          newDotExpr(valSym, ident"isSome"),
          newStmtList(
            nnkAsgn.newTree(
              nnkBracketExpr.newTree(outVecSym, countSym),
              newDotExpr(valSym, ident"get")))),
        nnkElse.newTree(
          newStmtList(
            newCall(newDotExpr(outVecSym, ident"setNull"), countSym)))))
    else:
      loopBody.add(nnkAsgn.newTree(
        nnkBracketExpr.newTree(outVecSym, countSym), valSym))

    loopBody.add(newCall(ident"inc", countSym))
    let tryBody = newStmtList(whle)
    mainBody.add(nnkTryStmt.newTree(tryBody,
      nnkExceptBranch.newTree(newStmtList(
        newCall(bindSym"duckdb_function_set_error",
          ident"info",
          newDotExpr(newCall(ident"getCurrentExceptionMsg"),
            ident"cstring"))))))
    mainBody.add(newCall(bindSym"duckdb_data_chunk_set_size",
      rawSym, nnkCall.newTree(ident"idx_t", countSym)))

  else:
    # ── Multi-column buffered-write path (v2) ──
    let bufType = nnkBracketExpr.newTree(ident"seq", retTypeInst)
    let bufSym = genSym(nskVar, "buf")
    mainBody.add(nnkVarSection.newTree(
      newIdentDefs(bufSym, bufType, newEmptyNode())))

    mainBody.add(newVarStmt(countSym, newLit 0))
    let whleBuf = nnkWhileStmt.newTree(
      nnkInfix.newTree(ident"<", countSym, sizeSym),
      newStmtList())
    let bufLoop = whleBuf[1]
    let valSym = genSym(nskLet, "val")
    bufLoop.add(newLetStmt(valSym, newCall(itSym)))
    bufLoop.add(nnkIfStmt.newTree(
      nnkElifBranch.newTree(
        newCall(bindSym"finished", itSym),
        nnkBreakStmt.newTree(newEmptyNode()))))
    bufLoop.add(newCall(bindSym"add", bufSym, valSym))
    bufLoop.add(newCall(ident"inc", countSym))
    let tryBuf = newStmtList(whleBuf)
    mainBody.add(nnkTryStmt.newTree(tryBuf,
      nnkExceptBranch.newTree(newStmtList(
        newCall(bindSym"duckdb_function_set_error",
          ident"info",
          newDotExpr(newCall(ident"getCurrentExceptionMsg"),
            ident"cstring"))))))

    mainBody.add(newCall(bindSym"duckdb_data_chunk_set_size",
      rawSym, nnkCall.newTree(ident"idx_t", countSym)))

    let pidsSym = genSym(nskLet, "pids")
    mainBody.add(newLetStmt(pidsSym,
      newDotExpr(ident"initData", ident"projectedIds")))

    let pIdent = ident"p"
    var projLoop = nnkForStmt.newTree(
      pIdent,
      nnkInfix.newTree(ident"..<", newLit 0,
        newDotExpr(pidsSym, ident"len")),
      newStmtList())
    let projBody = projLoop[^1]

    let origSym = genSym(nskLet, "origIdx")
    projBody.add(newLetStmt(origSym,
      nnkBracketExpr.newTree(pidsSym, pIdent)))

    let iIdent = ident"i"
    var ifStmt: NimNode = nil
    for i, col in outCols:
      let vecSym = genSym(nskVar, "v")
      var branch = newStmtList()
      let vecRaw = genSym(nskLet, "vecRaw")
      let bufElem = nnkBracketExpr.newTree(bufSym, iIdent)
      branch.add(newLetStmt(vecRaw,
        newCall(bindSym"duckdb_data_chunk_get_vector",
          rawSym, nnkCall.newTree(ident"idx_t", pIdent))))
      branch.add(newVarStmt(vecSym,
        newCall(nnkBracketExpr.newTree(bindSym"initVector", col.ktNode),
          vecRaw, sizeSym)))
      var writeLoop = nnkForStmt.newTree(
        iIdent,
        nnkInfix.newTree(ident"..<", newLit 0, countSym),
        newStmtList())

      let colVal = nnkBracketExpr.newTree(bufElem, newLit col.fieldIdx)
      if col.isOption:
        writeLoop[^1].add(nnkIfStmt.newTree(
          nnkElifBranch.newTree(
            newDotExpr(colVal, ident"isSome"),
            newStmtList(
              nnkAsgn.newTree(
                nnkBracketExpr.newTree(vecSym, iIdent),
                newDotExpr(colVal, ident"get")))),
          nnkElse.newTree(
            newStmtList(
              newCall(newDotExpr(vecSym, ident"setNull"), iIdent)))))
      else:
        writeLoop[^1].add(nnkAsgn.newTree(
          nnkBracketExpr.newTree(vecSym, iIdent),
          colVal))
      branch.add(writeLoop)

      let cond = nnkInfix.newTree(ident"==", origSym, newLit i)
      if ifStmt.isNil:
        ifStmt = nnkIfStmt.newTree(
          nnkElifBranch.newTree(cond, branch))
      else:
        ifStmt.add(nnkElifBranch.newTree(cond, branch))

    projBody.add(ifStmt)

    mainBody.add(projLoop)

  result.add(newProc(
    name = mainProcName,
    params = [newEmptyNode(),
      newIdentDefs(ident"info", bindSym"duckdb_function_info"),
      newIdentDefs(rawSym, bindSym"duckdb_data_chunk")],
    body = mainBody,
    pragmas = nnkPragma.newTree(ident"cdecl")))

  # --- Build & register ---
  let pushdownVal = if isMultiCol: ident"true" else: ident"false"
  let regStmts = newStmtList()
  var tfArgs = newSeq[NimNode]()
  tfArgs.add(nnkExprEqExpr.newTree(ident"name", newLit nameStr))
  if namedParams:
    tfArgs.add(nnkExprEqExpr.newTree(ident"parameters",
      nnkPrefix.newTree(ident"@", nnkBracket.newTree())))
  else:
    var plist = nnkPrefix.newTree(ident"@", nnkBracket.newTree())
    for p in params:
      plist[1].add(newCall(bindSym"newLogicalType", p.kt))
    tfArgs.add(nnkExprEqExpr.newTree(ident"parameters", plist))
  tfArgs.add(nnkExprEqExpr.newTree(ident"projectionPushdown", pushdownVal))
  if localInitExpr != nil:
    tfArgs.add(nnkExprEqExpr.newTree(ident"initLocalProc", localInitExpr))

  regStmts.add(newLetStmt(tfName,
    newCall(bindSym"newTableFunction", tfArgs)))

  if namedParams:
    for p in params:
      regStmts.add(newCall(
        bindSym"duckdb_table_function_add_named_parameter",
        newDotExpr(tfName, ident"handle"),
        newDotExpr(newLit p.sym.strVal, ident"cstring"),
        newDotExpr(newCall(bindSym"newLogicalType", p.kt), ident"handle")))

  regStmts.add(newCall(bindSym"duckdb_table_function_set_bind",
    newDotExpr(tfName, ident"handle"), bindProcName))
  regStmts.add(newCall(bindSym"duckdb_table_function_set_init",
    newDotExpr(tfName, ident"handle"), initProcName))
  regStmts.add(newCall(bindSym"duckdb_table_function_set_function",
    newDotExpr(tfName, ident"handle"), mainProcName))
  regStmts.add(newCall(bindSym"register", con, tfName))
  result.add(regStmts)


