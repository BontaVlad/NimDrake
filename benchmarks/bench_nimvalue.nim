import criterion
import ../src/nimdrake
import ./[config, tools]

const Rows = 2_000

proc materializeScalar() =
  let conn = newDatabase().connect()
  let resultSet = conn.execute("SELECT i::BIGINT FROM range(" & $Rows & ") t(i)")
  var values: seq[NimValue] = @[]
  for chunk in resultSet:
    values.add chunk.vector(0).toNimValues
  doAssert values.len == Rows
  doAssert values[Rows - 1].intVal == (Rows - 1).int64

proc materializeNested() =
  let conn = newDatabase().connect()
  let resultSet = conn.execute("SELECT [i, i + 1, NULL] FROM range(" & $Rows & ") t(i)")
  var values: seq[NimValue] = @[]
  for chunk in resultSet:
    values.add chunk.vector(0).toNimValues
  doAssert values.len == Rows
  doAssert values[0].listVal[2].kind == nvNull

proc formatNested() =
  let value = NimValue(kind: nvList, listVal: @[
    NimValue(kind: nvString, strVal: "alpha"),
    NimValue(kind: nvStruct, fields: @[
      ("id", NimValue(kind: nvInt, intVal: 42)),
      ("text", NimValue(kind: nvString, strVal: "O'Reilly"))])])
  let text = $value
  doAssert text == "['alpha', {'id': 42, 'text': O'Reilly}]", "got: " & text

proc runProfile(options: ProfileOptions) =
  case options.caseName
  of "scalar_materialization": repeatProfile(options, materializeScalar)
  of "nested_materialization": repeatProfile(options, materializeNested)
  of "nested_format": repeatProfile(options, formatNested)
  else: raise newException(ValueError, "unknown NimValue profile case: " & options.caseName)

let options = profileOptions()
if profilingRequested(options):
  runProfile(options)
else:
  let cfg = benchmarkConfig()
  benchmark cfg:
    proc benchmarkScalarMaterialization() {.measure.} = materializeScalar()
    proc benchmarkNestedMaterialization() {.measure.} = materializeNested()
    proc benchmarkNestedFormat() {.measure.} = formatNested()
