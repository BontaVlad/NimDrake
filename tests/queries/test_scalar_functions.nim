import unittest2
import ../../src/[api, database, vector, datachunk, query, query_result, scalar_functions, types]

suite "Test scalar functions":

  test "int64 input and output":
    let conn = newDatabase().connect()

    template doubleValue(val, bar: int64): int64 {.scalar.} =
      return val * bar

    conn.register(doubleValue)

    conn.execute("CREATE TABLE test_table AS SELECT i FROM range(3) t(i);")
    let outcome =
      conn.execute("SELECT i, doubleValue(i, i) as doubled FROM test_table").fetchAll()
    check outcome[0].valueBigInt == @[0'i64, 1'i64, 2'i64]
    check outcome[1].valueBigInt ==
      @[0'i64, 1'i64, 4'i64]

  test "scalar function with strings":
    let conn = newDatabase().connect()

    template myConcat(left, right: string): string {.scalar.} =
      # echo "called"
      # echo "left: ", left, " right ", right
      # return "foo" & "bar"
      return left & right

    conn.register(myConcat)

    conn.execute(
    """
        SELECT SETSEED(0.42);
        DROP TABLE IF EXISTS test_table;
        CREATE TABLE test_table (
            column1 VARCHAR,
            column2 VARCHAR,
        );

        INSERT INTO test_table (column1, column2)
        SELECT
            LEFT(md5(CAST(RANDOM() AS VARCHAR)), 8) AS column1,  -- Truncate to 8 characters
            LEFT(md5(CAST(RANDOM() AS VARCHAR)), 8) AS column2   -- Truncate to 8 characters
        FROM range(5);
    """
    )

    let outcome = conn.execute("SELECT CONCAT(column1, column2) AS correct, myConcat(column1, column2) as concatenated FROM test_table").fetchAll()

    for i, correct in outcome[0].valueVarchar:
      check correct == outcome[1].valueVarchar[i]
