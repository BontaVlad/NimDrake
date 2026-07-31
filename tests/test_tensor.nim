import unittest2
# TODO: The tensor tests are disabled by default. Building with
# `-d:features.nimdrake.tensor` currently fails to compile because
# arraymancer's transitive dependency nimblas 0.3.1 references the
# `Complex32`/`Complex64` types without importing std/complex (Nim 2.2+
# removed the implicit alias). Fix requires pinning/updating nimblas
# or adding an import shim — outside NimDrake scope. To run once fixed:
#   nim c -d:features.nimdrake.tensor tests/test_tensor.nim
when defined(features.nimdrake.tensor):
  import arraymancer
  import ../src/[ffi, database, qresult, query, types, table_scan]
  import ../src/compatibility/tensor_table

  suite "Tensor table registration":
    test "registerTensor 2D int32 tensor is queryable":
      let conn = newDatabase().connect()
      let t = [[1'i32, 2, 3], [4, 5, 6]].toTensor()
      conn.registerTensor("t1", t, @["a", "b", "c"])
      let r = conn.execute("SELECT a, b, c FROM t1 ORDER BY a")
      var rows = 0
      for chunk in r:
        check chunk.columnCount == 3
        check chunk.bindAs(0, DuckType.Integer).toSeq == @[1'i32, 4]
        check chunk.bindAs(1, DuckType.Integer).toSeq == @[2'i32, 5]
        check chunk.bindAs(2, DuckType.Integer).toSeq == @[3'i32, 6]
        rows += chunk.len
      check rows == 2

    test "registerTensor 2D float64 tensor with default column names":
      let conn = newDatabase().connect()
      let t = [[1.5'f64, 2.5], [3.5, 4.5]].toTensor()
      conn.registerTensor("t2", t)
      let r = conn.execute("SELECT col_0, col_1 FROM t2 ORDER BY col_0")
      var rows = 0
      for chunk in r:
        check chunk.bindAs(0, DuckType.Double).toSeq == @[1.5'f64, 3.5]
        check chunk.bindAs(1, DuckType.Double).toSeq == @[2.5'f64, 4.5]
        rows += chunk.len
      check rows == 2
else:
  suite "Tensor table registration (disabled)":
    test "registerTensor requires -d:features.nimdrake.tensor":
      check true
