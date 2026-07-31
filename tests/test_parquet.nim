import std/os
import unittest2
import ../src/[database, qresult, query, types]

suite "Parquet round-trip via SQL":
  test "COPY TO parquet then parquet_scan read-back":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE pt (i INTEGER, s VARCHAR)")
    conn.execute("INSERT INTO pt VALUES (1, 'a'), (2, 'b'), (3, 'c')")
    let parquetPath = getTempDir() / "nimdrake_test.parquet"
    removeFile(parquetPath)
    defer: removeFile(parquetPath)
    conn.executeMaterialized("COPY pt TO ? (FORMAT PARQUET)", (parquetPath,))
    let r = conn.execute("SELECT * FROM parquet_scan(?) ORDER BY i", (parquetPath,))
    var rows = 0
    for chunk in r:
      check chunk.bindAs(0, DuckType.Integer).toSeq == @[1'i32, 2, 3]
      check chunk.bindAs(1, DuckType.Varchar).toSeq == @["a", "b", "c"]
      rows += chunk.len
    check rows == 3

  test "Parquet preserves NULLs in nullable columns":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE pnull (i INTEGER, s VARCHAR)")
    conn.execute("INSERT INTO pnull VALUES (1, 'x'), (NULL, NULL), (3, 'z')")
    let parquetPath = getTempDir() / "nimdrake_pnull.parquet"
    removeFile(parquetPath)
    defer: removeFile(parquetPath)
    conn.executeMaterialized("COPY pnull TO ? (FORMAT PARQUET)", (parquetPath,))
    let r = conn.execute("SELECT * FROM parquet_scan(?) ORDER BY i NULLS LAST", (parquetPath,))
    var rows = 0
    for chunk in r:
      let vi = chunk.bindAs(0, DuckType.Integer)
      let vs = chunk.bindAs(1, DuckType.Varchar)
      for j in 0 ..< chunk.len:
        if vi.valid(j):
          check vi[j] == 1'i32 or vi[j] == 3'i32
        else:
          check not vs.valid(j)
      rows += chunk.len
    check rows == 3

  test "Parquet reads nested types (LIST and STRUCT)":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE pnest (l INTEGER[], st STRUCT(a INTEGER, b VARCHAR))")
    conn.execute("INSERT INTO pnest VALUES ([1, 2, 3], {'a': 10, 'b': 'x'}), ([4], {'a': 20, 'b': 'y'})")
    let parquetPath = getTempDir() / "nimdrake_pnest.parquet"
    removeFile(parquetPath)
    defer: removeFile(parquetPath)
    conn.executeMaterialized("COPY pnest TO ? (FORMAT PARQUET)", (parquetPath,))
    let r = conn.execute("SELECT * FROM parquet_scan(?) ORDER BY l[1]", (parquetPath,))
    var rows = 0
    for chunk in r:
      check chunk.columnCount >= 2
      rows += chunk.len
    check rows == 2
