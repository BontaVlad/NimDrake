import std/[tables]
import unittest2
import ../src/[types, database, dataframe, query, query_result, vector, table_scan]

suite "Table Scan":

  test "Test register dataframe int and varchar":
    let
      conn = newDatabase().connect()
      df = newDataFrame(
        {"foo": newVector(@[10, 30, 20]), "bar": newVector(@["a", "b", "c"])}.toTable
      )
    conn.register("df", df)
    let outcome = conn.execute("SELECT * FROM df ORDER BY foo;").fetchAllNamed()
    check outcome["foo"].valueBigint == @[10'i64, 20'i64, 30'i64]
    check outcome["bar"].valueVarchar == @["a", "c", "b"]

  test "Test view into mutable dataframe":
    let
      conn = newDatabase().connect()
      df = newDataFrame({"bar": newVector(@["a", "b", "c"])}.toTable
      )

    conn.register("df", df)

    let firstOutcome = conn.execute("SELECT bar FROM df;").fetchAllNamed()
    check firstOutcome["bar"].valueVarchar == @["a", "b", "c"]

    df["bar"].valueVarchar[1] = "d"
    let secondOutcome = conn.execute("SELECT bar FROM df;").fetchAllNamed()
    check secondOutcome["bar"].valueVarchar == @["a", "d", "c"]
