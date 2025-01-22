import std/[tables]
import unittest2
import ../../src/[types, database, dataframe, query, query_result, vector, table_scan]

# suite "Table Scan":
#   test "Test register dataframe":
#     let
#       conn = newDatabase().connect()
#       df = newDataFrame(
#         {"foo": newVector(@[10, 30, 20]), "bar": newVector(@["a", "b", "c"])}.toTable
#       )
#     conn.register("df", df)
#     let outcome = conn.execute("SELECT * FROM df ORDER BY foo;").fetchAllNamed()
#     assert outcome["foo"].valueBigint == @[10'i64, 20'i64, 30'i64]
#     assert outcome["bar"].valueVarchar == @["a", "c", "b"]
