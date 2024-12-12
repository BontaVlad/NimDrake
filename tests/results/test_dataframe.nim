import std/[unittest, tables, sequtils]
import ../../src/[dataframe, vector]

suite "Test Dataframe":
  let df = newDataFrame(
    {
      "foo": newVector(@[10, 20]),
      "bar": newVector(@["a", "b"]),
    }.toTable
  )

  test "Test dataframe columns":
    assert df.columns == @["foo", "bar"]

  test "Test dataframe columns accessed by name":
    assert df["foo"].valueBigInt == @[10'i64, 20'i64]
    assert df["bar"].valueVarchar == @["a", "b"]

  test "Test dataframe access per row basis":
    let row = df.rows.toSeq[1]
    assert row[0].valueBigint == 20
    assert row[1].valueVarchar == "b"

  test "Test invalid column name":
    doAssertRaises(ValueError):
      discard df["something that does not exist"]

  test "Test echo the dataframe":
    let output = $df
    assert output == """
┌─────┬─────────────┬─────────────┐
│  #  │     foo     │     bar     │
├─────┼─────────────┼─────────────┤
│  0  │     10      │     a       │
│  1  │     20      │     b       │
└─────┴─────────────┴─────────────┘
"""
