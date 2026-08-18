import criterion
import ../src/nimdrake
import ./[config, tools]

let bindingConnection = newDatabase().connect()
let listValue = NimValue(kind: nvList, listVal: @[
  NimValue(kind: nvInt, intVal: 1),
  NimValue(kind: nvInt, intVal: 2),
  NimValue(kind: nvInt, intVal: 3)])
let structValue = NimValue(kind: nvStruct, fields: @[
  ("id", NimValue(kind: nvInt, intVal: 42)),
  ("name", NimValue(kind: nvString, strVal: "answer"))])
let emptyListValue = NimValue(kind: nvList, listVal: @[])
let nullFirstListValue = NimValue(kind: nvList, listVal: @[
  NimValue(kind: nvNull), NimValue(kind: nvInt, intVal: 7)])

proc bindList() =
  var statement = bindingConnection.newStatement("SELECT ?::BIGINT[]")
  doAssert statement.bindVal(1, listValue) == DuckState.Duckdbsuccess
  let resultSet = bindingConnection.executeMaterialized(statement)
  let back = resultSet.scalar()
  doAssert back.kind == nvList and back.listVal.len == 3

proc bindStruct() =
  var statement = bindingConnection.newStatement(
    "SELECT ?::STRUCT(id BIGINT, name VARCHAR)")
  doAssert statement.bindVal(1, structValue) == DuckState.Duckdbsuccess
  let resultSet = bindingConnection.executeMaterialized(statement)
  let back = resultSet.scalar()
  doAssert back.kind == nvStruct and back.fields.len == 2

proc bindEmptyList() =
  var statement = bindingConnection.newStatement("SELECT ?::BIGINT[]")
  doAssert statement.bindVal(1, emptyListValue) == DuckState.Duckdbsuccess
  let resultSet = bindingConnection.executeMaterialized(statement)
  doAssert resultSet.scalar().listVal.len == 0

proc bindNullFirstList() =
  var statement = bindingConnection.newStatement("SELECT ?::BIGINT[]")
  doAssert statement.bindVal(1, nullFirstListValue) == DuckState.Duckdbsuccess
  let resultSet = bindingConnection.executeMaterialized(statement)
  let back = resultSet.scalar()
  doAssert back.listVal[0].kind == nvNull and back.listVal[1].intVal == 7

proc runProfile(options: ProfileOptions) =
  case options.caseName
  of "list": repeatProfile(options, bindList)
  of "struct": repeatProfile(options, bindStruct)
  of "empty_list": repeatProfile(options, bindEmptyList)
  of "null_first_list": repeatProfile(options, bindNullFirstList)
  else: raise newException(ValueError, "unknown binding profile case: " & options.caseName)

let options = profileOptions()
if profilingRequested(options):
  runProfile(options)
else:
  let cfg = benchmarkConfig()
  benchmark cfg:
    proc benchmarkListBinding() {.measure.} = bindList()
    proc benchmarkStructBinding() {.measure.} = bindStruct()
    proc benchmarkEmptyListBinding() {.measure.} = bindEmptyList()
    proc benchmarkNullFirstListBinding() {.measure.} = bindNullFirstList()
