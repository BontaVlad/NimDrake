import std/[unittest]
import ../../src/[api, database, query, query_result, scalar_functions, types]

suite "Test scalar functions":
  test "Test scalar function int64":
    let con = connect()

    template doubleValue(val, bar: int64): int64 {.scalar.} =
      result = val * bar

    con.register(doubleValue)

    con.execute("CREATE TABLE test_table AS SELECT i FROM range(3) t(i);")
    let outcome =
      con.execute("SELECT i, doubleValue(i, i) as doubled FROM test_table").fetchAll()
    check outcome[0].valueBigInt == @[0'i64, 1'i64, 2'i64]
    check outcome[1].valueBigInt ==
      @[0'i64, 1'i64, 4'i64]

        # test "Test scalar function with strings":
        #   let con = connect()

        #   template myConcat(left, right: string): string {.scalar.} =
        #     result = left & right

        #   con.execute(
        #     """
        #       SELECT SETSEED(0.42);
        #       CREATE TABLE test_table (
        #           column1 VARCHAR,
        #           column2 VARCHAR
        #       );

        #       INSERT INTO test_table (column1, column2)
        #       SELECT
        #           LEFT(md5(CAST(RANDOM() AS VARCHAR)), 8) AS column1,  -- Truncate to 8 characters
        #           LEFT(md5(CAST(RANDOM() AS VARCHAR)), 8) AS column2   -- Truncate to 8 characters
        #       FROM range(5);
        #   """
        #   )
        #   echo con.execute("SELECT * from test_table;")

        #   con.register(myConcat)

        #   echo con.execute(
        #     "SELECT myConcat(column1, column2) as concatenated FROM test_table"
        #   )
        #   let outcome = con
        #     .execute("SELECT myConcat(column1, column2) as concatenated FROM test_table")
        #     .fetchAll()

        #   assert outcome[0].valueVarchar ==
        #     @[
        #       "697d2d000c905c7c", "e3238862a70f1078", "b7747524d912609f", "09cc03874e311ba1",
        #       "129634022d368161",
        #     ]
