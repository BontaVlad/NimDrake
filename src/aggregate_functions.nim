import std/[macros, strformat, sequtils, tables, enumerate]
import fusion/[matching, astdsl]
import /[api, types, database, exceptions, query_result]

type
  FunctionInfo* = object of duckdbFunctionInfo
  AggregateState* = object of duckdbAggregateState
  AggregateFunctionBase* = object of RootObj
    name*: string
    handle*: duckdbAggregateFunction

  AggregateFunction* = ref object of AggregateFunctionBase
  ValidityMaskRegistry* = Table[string, ValidityMask]

proc `=destroy`(agg: AggregateFunctionBase) =
  if not isNil(agg.addr):
    duckdb_destroy_aggregate_function(agg.handle.addr)

proc isAggregateStateType(node: NimNode): bool =
  case node.kind
  of nnkRefTy:
    # For ref types, look at their object definition
    return isAggregateStateType(node[0])
  of nnkObjectTy:
    # Check if this object inherits from AggregateState
    let inheritance = node[1] # Get inheritance part
    if inheritance.kind == nnkOfInherit and
        inheritance[0].getTypeInst == getTypeInst(AggregateState):
      return true
    else:
      return false
  else:
    return false

macro newAggregateFunction*(
    name: static[string],
    stateInit: typed,
    update: typed,
    combine: typed,
    finalize: typed,
): untyped =
  expectKind(stateInit, {nnkSym, nnkLambda, nnkProcDef})
  expectKind(update, {nnkSym, nnkLambda, nnkProcDef})
  expectKind(combine, {nnkSym, nnkLambda, nnkProcDef})
  expectKind(finalize, {nnkSym, nnkLambda, nnkProcDef})

  let
    callbackObjName = newIdentNode("CAPICallbacks")
    stateSizeCallbackName = newIdentNode("stateSize")
    initParameters = stateInit.getTypeImpl()[0]
    stateParamType = initParameters[1]
    stateType = stateParamType[1]

  if len(initParameters) != 2:
    error("Init proc takes only one parameter")

  if not isAggregateStateType(stateType.getImpl()[2]):
    error(
      fmt"{initParameters[1][0]} parameter must be of [{stateType} = ref object of AggregateState]"
    )

  let
    stateInitImpl = getTypeInst(stateInit)
    updateImpl = getTypeInst(update)
    combineImpl = getTypeInst(combine)
    finalizeImpl = finalize.getTypeImpl
    stateSizeWrapperName = newIdentNode("stateSizeWrapper")
    stateInitWrapperName = newIdentNode("stateInitWrapper")
    updateWrapperName = newIdentNode("updateWrapper")
    combineWrapperName = newIdentNode("combineWrapper")
    finalizeWrapperName = newIdentNode("finalizeWrapper")

      # initFun: `@ stateInitImpl`
      # combineFun: `@ combineImpl`
  # let foo = newTree(nnkProcTy, combineImpl[0], newTree(nnkEmpty))
  # echo foo.treeRepr
  # echo combineImpl.repr
  # echo combineImpl[0][0].repr
  # combineFun: `@ foo`
  let callBackObjDefinition = quote("@"):
    type `@ callbackObjName` = ref object
      sizeFun: proc(info: FunctionInfo): int
      initFun: proc(state: `@ stateType`)
      updateFun: proc(info: FunctionInfo, states: seq[`@ stateType`]): string
      combineFun: proc(
        info: FunctionInfo, source: `@ stateType`, target: `@ stateType`, count: int
      )
      finalizeFun: proc(
        info: FunctionInfo,
        source: `@ stateType`,
        output: duckdb_vector,
        count: int,
        offset: int,
      )

    # let callBackObjDefinition = quote("@"):
    #   type `@ callbackObjName` = object
    #     sizeFun: proc(info: FunctionInfo): int {.nimcall.}
    #     initFun: `@ stateInitImpl`
    #     updateFun: `@ updateImpl`
    #     combineFun: `@ combineImpl`
    #     finalizeFun: `@ finalizeImpl`
    proc destroyCallbackFunction(p: pointer) {.cdecl.} =
      var callback = cast[`@ callbackObjName`](p)
      `=destroy`(callback)

  let callbacksProcedures = quote:
    proc `stateSizeCallbackName`(info: FunctionInfo): int =
      return sizeof(`stateType`)

    proc `stateSizeWrapperName`(info: duckdb_function_info): idx_t {.cdecl.} =
      let callback =
        cast[`callbackObjName`](duckdb_aggregate_function_get_extra_info(info))
      echo callback.repr
      return callback.sizeFun(cast[FunctionInfo](info)).idx_t

    proc `stateInitWrapperName`(
        info: duckdb_function_info, state: duckdb_aggregate_state
    ) {.cdecl.} =
      let callback =
        cast[`callbackObjName`](duckdb_aggregate_function_get_extra_info(info))
      callback.initFun(cast[`stateType`](state))

    proc `updateWrapperName`(
        info: duckdb_function_info,
        chunk: duckdb_data_chunk,
        state: ptr duckdb_aggregate_state,
    ) {.cdecl.} =
      let callback =
        cast[`callbackObjName`](duckdb_aggregate_function_get_extra_info(info))
      # callback.updateFun(cast[FunctionInfo](info), chunk, cast[ptr `stateType`](state))

    proc `combineWrapperName`(
        info: duckdb_function_info,
        source: ptr duckdb_aggregate_state,
        target: ptr duckdb_aggregate_state,
        count: idx_t,
    ) {.cdecl.} =
      let callback =
        cast[`callbackObjName`](duckdb_aggregate_function_get_extra_info(info))
      # callback.combineFun(
      #   cast[FunctionInfo](info),
      #   cast[ptr `stateType`](source),
      #   cast[ptr `stateType`](target),
      #   count.int,
      # )

    proc `finalizeWrapperName`(
        info: duckdb_function_info,
        state: ptr duckdb_aggregate_state,
        output: duckdb_vector,
        count: idx_t,
        offset: idx_t,
    ) {.cdecl.} =
      let callback =
        cast[`callbackObjName`](duckdb_aggregate_function_get_extra_info(info))
      # callback.finalizeFun(cast[FunctionInfo](info), cast[`stateType`](source), output, count, offset)

  let aggregationFunctionDefinition = quote:
    block:
      var aggFun =
        AggregateFunction(name: `name`, handle: duckdbCreateAggregateFunction())

      var callbacks = `callbackObjName`(
        sizeFun: `stateSizeCallbackName`,
        initFun: `stateInit`,
        updateFun: `update`,
        combineFun: `combine`,
        finalizeFun: `finalize`,
      )

      GC_ref(callbacks)
      duckdbAggregateFunctionSetExtraInfo(
        aggFun.handle, cast[ptr `callbackObjName`](callbacks), destroyCallbackFunction
      )

      let returnType = newLogicalType(DuckType.VARCHAR)
      duckdbaggregateFunctionSetReturnType(aggFun.handle, returnType.handle)
      duckdbAggregateFunctionAddParameter(aggFun.handle, returnType.handle)

      duckdbAggregateFunctionSetName(aggFun.handle, cstring(`name`))
      duckdbAggregateFunctionSetFunctions(
        aggFun.handle, `stateSizeWrapperName`, `stateInitWrapperName`,
        `updateWrapperName`, `combineWrapperName`, `finalizeWrapperName`,
      )
      aggFun

  result = newStmtList()
  result.add quote do:
    `callBackObjDefinition`
    `callbacksProcedures`
    `aggregationFunctionDefinition`
  echo result.repr

proc register*(con: Connection, fun: AggregateFunction) =
  check(
    duckdb_register_aggregate_function(con.handle, fun.handle),
    fmt"Failed to register function '{fun.name}'",
  )
