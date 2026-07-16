import ../src/[database, query, qresult, table_scan, types, ffi]
import std/[strutils, math]
import unittest2

test "register QResult[Materialized] and query via SQL":
  let conn = newDatabase().connect()
  let q = conn.execute(
    "SELECT 10::BIGINT AS foo, 'hello'::VARCHAR AS bar " &
    "UNION ALL SELECT 20::BIGINT, 'world'"
  )
  conn.register(q, name = "my_table")
  let r = conn.execute("SELECT foo, bar FROM my_table ORDER BY foo")
  check r.len == 2
  var fooVals: seq[int64] = @[]
  var barVals: seq[string] = @[]
  for chunk in r:
    fooVals.add chunk.bindAs(0, DuckType.BigInt).toSeq
    barVals.add chunk.bindAs(1, DuckType.Varchar).toSeq
  check fooVals == @[10'i64, 20'i64]
  check barVals == @["hello", "world"]

test "register QResult[Materialized] with null values":
  let conn = newDatabase().connect()
  let q = conn.execute(
    "SELECT CASE WHEN seq % 2 = 0 THEN seq ELSE NULL END AS maybe_int " &
    "FROM generate_series(1, 10) AS t(seq)"
  )
  conn.register(q, name = "null_table")
  let r = conn.execute("SELECT maybe_int FROM null_table ORDER BY maybe_int NULLS FIRST")
  check r.len == 10
  var nullCount = 0
  var nonNullCount = 0
  for chunk in r:
    let v = chunk.bindAs(0, DuckType.BigInt)
    for i in 0 ..< v.len:
      if v.valid(i): inc nonNullCount
      else: inc nullCount
  check nullCount == 5
  check nonNullCount == 5

test "register QResult[Streaming] — query on same conn":
  let db = newDatabase()
  let connReg = db.connect()
  let connQuery = db.connect()

  let stmt = connQuery.newStatement(
    "SELECT seq, seq || '_s' AS s FROM generate_series(1, 3) AS t(seq)"
  )
  let streamQr = connQuery.execute(stmt)

  connReg.register(streamQr, name = "stream_table")

  let r = connReg.execute("SELECT seq, s FROM stream_table ORDER BY seq")
  check r.len == 3
  var seqVals: seq[int64] = @[]
  var strVals: seq[string] = @[]
  for chunk in r:
    seqVals.add chunk.bindAs(0, DuckType.BigInt).toSeq
    strVals.add chunk.bindAs(1, DuckType.Varchar).toSeq
  check seqVals == @[1'i64, 2'i64, 3'i64]
  check strVals == @["1_s", "2_s", "3_s"]

test "register on two independent databases does not cross-contaminate":
  let dbA = newDatabase()
  let dbB = newDatabase()
  let connA = dbA.connect()
  let connB = dbB.connect()
  let qA = connA.execute("SELECT 1::BIGINT AS x")
  connA.register(qA, name = "t_a")
  let qB = connB.execute("SELECT 99::BIGINT AS y")
  connB.register(qB, name = "t_b")

  let rA = connA.execute("SELECT x FROM t_a")
  let rB = connB.execute("SELECT y FROM t_b")
  check rA.len == 1
  check rB.len == 1
  var xa: seq[int64] = @[]
  var yb: seq[int64] = @[]
  for c in rA: xa.add c.bindAs(0, DuckType.BigInt).toSeq
  for c in rB: yb.add c.bindAs(0, DuckType.BigInt).toSeq
  check xa == @[1'i64]
  check yb == @[99'i64]

test "register rejects struct column with a clean bind error":
  let conn = newDatabase().connect()
  let q = conn.execute("SELECT {'a': 1, 'b': 2} AS s")
  expect(Exception):
    conn.register(q, name = "struct_tbl")

test "register round-trips via parameterised view":
  let conn = newDatabase().connect()
  let q = conn.execute("SELECT 7::INTEGER AS v")
  conn.register(q, name = "normal_name")
  let r = conn.execute("SELECT v FROM normal_name")
  check r.len == 1
  var vs: seq[int32] = @[]
  for c in r: vs.add c.bindAs(0, DuckType.Integer).toSeq
  check vs == @[7'i32]

# ---------------------------------------------------------------------------
# Custom data structure: row-oriented in-memory table
# ---------------------------------------------------------------------------

type
  CellVal = object
    case isNull*: bool
    of false: strVal*: string
    of true: discard

  CustomTable = ref object
    columns: seq[Column]
    rows: seq[seq[CellVal]]

func cell(s: string): CellVal =
  CellVal(isNull: false, strVal: s)

func nullCell(): CellVal =
  CellVal(isNull: true)

proc newCustomTable(colDefs: varargs[(string, DuckType)]): CustomTable =
  var cols: seq[Column]
  for i, (name, kt) in colDefs:
    cols.add(newColumn(name, newLogicalType(kt), idx = i))
  CustomTable(columns: cols)

proc addRow(t: CustomTable, values: varargs[CellVal]) =
  var row = newSeq[CellVal](values.len)
  for i, v in values: row[i] = v
  t.rows.add(row)

proc columns(t: CustomTable): seq[Column] =
  t.columns

proc cardinality(t: CustomTable): Cardinality =
  knownCardinality(t.rows.len)

proc newFiller(t: CustomTable): FillFn =
  var cursor = 0
  let totalRows = t.rows.len
  let ncols = t.columns.len
  result = proc(chunk: duckdb_data_chunk): int {.closure, gcsafe.} =
    if cursor >= totalRows: return 0
    let n = min(totalRows - cursor, VECTOR_SIZE)
    for ci in 0 ..< ncols:
      let dstVec = duckdb_data_chunk_get_vector(chunk, ci.idx_t)
      case t.columns[ci].kind
      of DuckType.BigInt:
        var w = initVector[DuckType.BigInt](dstVec, n)
        for ri in 0 ..< n:
          let c = t.rows[cursor + ri][ci]
          if c.isNull: w.setNull(ri)
          else: w[ri] = parseInt(c.strVal).int64
      of DuckType.Integer:
        var w = initVector[DuckType.Integer](dstVec, n)
        for ri in 0 ..< n:
          let c = t.rows[cursor + ri][ci]
          if c.isNull: w.setNull(ri)
          else: w[ri] = parseInt(c.strVal).int32
      of DuckType.Double:
        var w = initVector[DuckType.Double](dstVec, n)
        for ri in 0 ..< n:
          let c = t.rows[cursor + ri][ci]
          if c.isNull: w.setNull(ri)
          else: w[ri] = parseFloat(c.strVal)
      of DuckType.Varchar:
        var w = initVector[DuckType.Varchar](dstVec, n)
        for ri in 0 ..< n:
          let c = t.rows[cursor + ri][ci]
          if c.isNull: w.setNull(ri)
          else: w[ri] = c.strVal
      else:
        raise newException(ValueError,
          "CustomTable: unsupported type " & $t.columns[ci].kind)
    cursor += n
    return n

# ---------------------------------------------------------------------------
# Tests: custom data structure registered via TableSource concept
# ---------------------------------------------------------------------------

test "register custom row-oriented table with BigInt and Varchar":
  let t = newCustomTable(("id", DuckType.BigInt), ("name", DuckType.Varchar))
  t.addRow(cell("1"), cell("Alice"))
  t.addRow(cell("2"), cell("Bob"))

  let conn = newDatabase().connect()
  conn.register(t, name = "people")

  let r = conn.execute("SELECT id, name FROM people ORDER BY id")
  check r.len == 2
  var ids: seq[int64] = @[]
  var names: seq[string] = @[]
  for chunk in r:
    ids.add chunk.bindAs(0, DuckType.BigInt).toSeq
    names.add chunk.bindAs(1, DuckType.Varchar).toSeq
  check ids == @[1'i64, 2'i64]
  check names == @["Alice", "Bob"]

test "custom table with nullable column via TableSource concept":
  let t = newCustomTable(("x", DuckType.BigInt))
  t.addRow(nullCell())
  t.addRow(cell("42"))
  t.addRow(nullCell())

  let conn = newDatabase().connect()
  conn.register(t, name = "nullable_x")

  let r = conn.execute("SELECT x FROM nullable_x ORDER BY x NULLS FIRST")
  check r.len == 3
  var nullCount = 0
  var presentCount = 0
  for chunk in r:
    let v = chunk.bindAs(0, DuckType.BigInt)
    for i in 0 ..< v.len:
      if v.valid(i): inc presentCount
      else: inc nullCount
  check nullCount == 2
  check presentCount == 1

test "custom table with Integer, Double and Varchar via TableSource concept":
  let t = newCustomTable(
    ("int_col", DuckType.Integer),
    ("float_col", DuckType.Double),
    ("str_col", DuckType.Varchar),
  )
  t.addRow(cell("10"), cell("3.14"), cell("pi"))
  t.addRow(cell("20"), cell("2.71"), cell("e"))

  let conn = newDatabase().connect()
  conn.register(t, name = "multi_type")

  let r = conn.execute("SELECT * FROM multi_type ORDER BY int_col")
  check r.len == 2
  var ints: seq[int32] = @[]
  var floats: seq[float64] = @[]
  var strs: seq[string] = @[]
  for chunk in r:
    ints.add chunk.bindAs(0, DuckType.Integer).toSeq
    floats.add chunk.bindAs(1, DuckType.Double).toSeq
    strs.add chunk.bindAs(2, DuckType.Varchar).toSeq
  check ints == @[10'i32, 20'i32]
  check floats == @[3.14, 2.71]
  check strs == @["pi", "e"]

test "custom table supports SQL filter and projection":
  let t = newCustomTable(("val", DuckType.BigInt), ("label", DuckType.Varchar))
  t.addRow(cell("5"), cell("low"))
  t.addRow(cell("15"), cell("mid"))
  t.addRow(cell("25"), cell("high"))

  let conn = newDatabase().connect()
  conn.register(t, name = "numbered")

  let r = conn.execute(
    "SELECT label FROM numbered WHERE val > 10 ORDER BY val")
  check r.len == 2
  var labels: seq[string] = @[]
  for chunk in r:
    labels.add chunk.bindAs(0, DuckType.Varchar).toSeq
  check labels == @["mid", "high"]

test "custom tables on two independent databases do not cross-contaminate":
  let tA = newCustomTable(("x", DuckType.BigInt))
  tA.addRow(cell("100"))
  let tB = newCustomTable(("y", DuckType.BigInt))
  tB.addRow(cell("999"))

  let dbA = newDatabase()
  let dbB = newDatabase()
  let connA = dbA.connect()
  let connB = dbB.connect()

  connA.register(tA, name = "ct_a")
  connB.register(tB, name = "ct_b")

  let rA = connA.execute("SELECT x FROM ct_a")
  let rB = connB.execute("SELECT y FROM ct_b")
  check rA.len == 1
  check rB.len == 1
  var xa: seq[int64] = @[]
  var yb: seq[int64] = @[]
  for c in rA: xa.add c.bindAs(0, DuckType.BigInt).toSeq
  for c in rB: yb.add c.bindAs(0, DuckType.BigInt).toSeq
  check xa == @[100'i64]
  check yb == @[999'i64]
