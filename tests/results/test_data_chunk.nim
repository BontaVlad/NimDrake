import std/[unittest, macros, tables, sequtils]
import ../../src/[api, datachunk, types, vector, query_result]

suite "Test datachunk":
  test "Test datachunk creation":
    let columns =
      @[
        newColumn(idx = 0, name = "index", kind = DuckType.Integer),
        newColumn(idx = 1, name = "name", kind = DuckType.Varchar),
        newColumn(idx = 2, name = "truth", kind = DuckType.Boolean),
      ]
    var chunk = newDataChunk(columns = columns)
    let
      intValues = @[1'i32, 2'i32, 3'i32]
      strValues = @["foo", "bar", "baz"]
      boolValues = @[true, false, true]

    chunk[0] = intValues
    chunk[1] = strValues
    chunk[2] = boolValues
    check chunk.len == len(intValues)

    check bool(chunk) is bool
    check chunk[0].valueInteger == intValues
    check chunk[1].valueVarchar == strValues
    check chunk[2].valueBoolean == boolValues
