# import unittest2
# import ../src/[database, qresult, types, table_scan, query]

# suite "Table Scan":

#   test "Test register dataframe int and varchar":
#     skip()
#     let
#       duck = newDatabase().connect()
#       df = duck.executeMaterialized(
#         "SELECT 10::BIGINT AS foo, 'a' AS bar " &
#         "UNION ALL SELECT 30::BIGINT, 'b' " &
#         "UNION ALL SELECT 20::BIGINT, 'c'"
#       )
#     duck.register("df", df)
#     let r = duck.executeMaterialized("SELECT * FROM df ORDER BY foo")
#     for chunk in r:
#       let vFoo = chunk.bindAs("foo", DuckType.BigInt)
#       let vBar = chunk.bindAs("bar", DuckType.Varchar)
#       check vFoo.toSeq == @[10'i64, 20'i64, 30'i64]
#       check vBar.toSeq == @["a", "c", "b"]

#   test "Test view into mutable dataframe":
#     skip()
#     let
#       duck = newDatabase().connect()
#       df = duck.executeMaterialized(
#         "SELECT 'a' AS bar UNION ALL SELECT 'b' UNION ALL SELECT 'c'"
#       )
#     duck.register("df", df)
#     let r = duck.executeMaterialized("SELECT bar FROM df")
#     for chunk in r:
#       let vBar = chunk.bindAs("bar", DuckType.Varchar)
#       check vBar.toSeq == @["a", "b", "c"]
