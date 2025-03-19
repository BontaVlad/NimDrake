import unittest2
import ../../src/[api, datachunk, types, query_result]

suite "Test datachunk":
  test "Test datachunk creation":
    let types =
      @[
        DuckType.Integer,
        DuckType.Varchar,
        DuckType.Boolean
      ]
    var chunk = newDataChunk(types)
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
