import std/[unittest, tables]
import ../../src/[types, database, dataframe, query, query_result, value, vector, table_scan]

suite "Table Scan":
  test "Test register dataframe":
    let
      con = connect()
      df = newDataFrame(
        {"foo": newVector(@[10, 30, 20]),
          "bar": newVector(@["a", "b", "c"])}.toTable)
    con.register("df", df)
    let outcome = con.execute("SELECT * FROM df ORDER BY foo;").fetchAllNamed()
    assert outcome["foo"].valueBigint == @[10'i64, 20'i64, 30'i64]
    assert outcome["bar"].valueVarchar == @["a", "c", "b"]
