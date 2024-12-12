import std/[unittest, tables]
import ../../src/[database, dataframe, query, query_result, value, vector, table_scan]

suite "Table Scan":
  test "Test register dataframe":
    let
      con = connect()
      df = newDataFrame(
        {"foo": newVector(@[10, 20, 30]), "bar": newVector(@["a", "atehunb", "c"])}.toTable
      )
    con.register("df", df)
    echo con.execute("SELECT foo, bar FROM df;").df()
