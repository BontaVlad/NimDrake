import std/[unittest, tables]
import ../../src/[database, dataframe, query, query_result, value, vector]

suite "Dataframe":
  test "Test Boolean result type":
    let df = newDataFrame(
      {
        "foo": newVector(@[10, 20, 30, 40, 50, 60, 70]),
        "bar": newVector(@["a", "b", "c", "d", "e", "f", "g"]),
      }.toTable
    )
    echo df
