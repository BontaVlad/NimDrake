import std/[options, times]
import ../src/[ffi, database, query, table_functions, qresult, types, exceptions]
import unittest2

iterator countToN(n: int): int {.closure.} =
  for i in 0 ..< n:
    yield i

test "T1: low-level manual table function":
  let conn = newDatabase().connect()

  type
    BindData = ref object
      count: int
    InitData = ref object
      pos: int

  proc destroyBind(p: pointer) {.cdecl.} =
    `=destroy`(cast[BindData](p))

  proc destroyInit(p: pointer) {.cdecl.} =
    `=destroy`(cast[InitData](p))

  proc bindProc(info: BindInfo) {.cdecl.} =
    let param = info.getParameter(0)
    let count = int(duckdb_get_int64(param))
    duckdb_destroy_value(param.addr)
    info.addResultColumn("my_column", DuckType.Integer)
    let data = BindData(count: count)
    GC_ref(data)
    info.setBindData(cast[pointer](data), destroyBind)

  proc initProc(info: InitInfo) {.cdecl.} =
    let data = InitData(pos: 0)
    GC_ref(data)
    info.setInitData(cast[pointer](data), destroyInit)

  proc mainProc(info: FunctionInfo, rawChunk: duckdb_data_chunk) {.cdecl.} =
    var initData = cast[InitData](info.getInitData())
    let vec = duckdb_data_chunk_get_vector(rawChunk, 0.idx_t)
    let raw = duckdb_vector_get_data(vec)
    var resultArray = cast[ptr UncheckedArray[int32]](raw)
    var count = 0
    let maxCount = 2048
    while initData.pos < maxCount and count < maxCount:
      resultArray[count] = 42 + int32(count)
      inc count
      inc initData.pos
    duckdb_data_chunk_set_size(rawChunk, count.idx_t)

  let tf = newTableFunction(
    name = "my_function",
    parameters = @[newLogicalType(DuckType.BigInt)],
    bindProc = bindProc,
    initProc = initProc,
    mainProc = mainProc,
  )
  conn.register(tf)
  let outcome = conn.execute("SELECT * FROM my_function(5::BIGINT)")
  for chunk in outcome:
    let v = chunk.vector(0).bindAs DuckType.Integer
    check v.len > 0

# ── T2: registerTableFunction countToN (1 param, int output) ──────────────────

test "T2: registerTableFunction countToN(n)":
  let conn = newDatabase().connect()
  conn.registerTableFunction(countToN)
  let r = conn.execute("SELECT * FROM countToN(5)")
  var vals: seq[int64]
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.BigInt
    for i in 0 ..< v.len:
      vals.add v[i]
  check vals == @[0'i64, 1'i64, 2'i64, 3'i64, 4'i64]

# ── T3: multi-param iterator ─────────────────────────────────────────────────
iterator countToNStep(count, step, val: int): int {.closure.} =
  for i in countup(0, count, step):
    yield val

test "T3: registerTableFunction countToNStep(count, step, val)":
  let conn = newDatabase().connect()
  conn.registerTableFunction(countToNStep)
  let r = conn.execute("SELECT * FROM countToNStep(9, 3, -1)")
  var vals: seq[int64]
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.BigInt
    for i in 0 ..< v.len:
      vals.add v[i]
  check vals == @[-1'i64, -1'i64, -1'i64, -1'i64]

# ── T4: string output ────────────────────────────────────────────────────────
iterator progress(count: int, sigil: string): string {.closure.} =
  var output = ""
  for _ in 0 ..< count:
    output &= sigil
    yield output

test "T4: registerTableFunction progress(count, sigil) — string output":
  let conn = newDatabase().connect()
  conn.registerTableFunction(progress)
  let r = conn.execute("SELECT * FROM progress(5, '#')")
  var vals: seq[string]
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.Varchar
    for i in 0 ..< v.len:
      vals.add v[i]
  check vals == @["#", "##", "###", "####", "#####"]

# ── T5: infinite iterator + LIMIT ─────────────────────────────────────────────
iterator floatCounter(): float {.closure.} =
  var counter = 0.0
  while true:
    yield counter
    counter += 1.0

test "T5: registerTableFunction floatCounter() + LIMIT":
  let conn = newDatabase().connect()
  conn.registerTableFunction(floatCounter)
  let r = conn.execute("SELECT * FROM floatCounter() LIMIT 5")
  var vals: seq[float64]
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.Double
    for i in 0 ..< v.len:
      vals.add v[i]
  check vals == @[0.0, 1.0, 2.0, 3.0, 4.0]

# ── Compile-time rejections ──────────────────────────────────────────────────

iterator voidIterator(): void {.closure.} =
  yield

test "T6: registerTableFunction rejects void return":
  let conn = newDatabase().connect()
  check not compiles(conn.registerTableFunction(voidIterator))

iterator genericIter[T](x: T): int {.closure.} =
  yield 42

test "T7: registerTableFunction rejects generic iterator":
  let conn = newDatabase().connect()
  check not compiles(conn.registerTableFunction(genericIter))

iterator defaultParam(n: int = 0): int {.closure.} =
  yield n

test "T8: registerTableFunction rejects default param values":
  let conn = newDatabase().connect()
  check not compiles(conn.registerTableFunction(defaultParam))

iterator nonClosure(n: int): int =
  for i in 0..<n: yield i

test "T9: registerTableFunction rejects non-closure iterator":
  let conn = newDatabase().connect()
  check not compiles(conn.registerTableFunction(nonClosure))

test "T10: registerTableFunction rejects non-iterator symbol":
  let conn = newDatabase().connect()
  check not compiles(conn.registerTableFunction(int64))

# ── T11: anonymous tuple yields (v2) ─────────────────────────────────────────
iterator tupleIter(n: int): (int, string) {.closure.} =
  for i in 0 ..< n: yield (i, $i)

test "T11: tuple yields — anonymous tuple (int, string)":
  let conn = newDatabase().connect()
  conn.registerTableFunction(tupleIter)
  let r = conn.execute("SELECT * FROM tupleIter(3)")
  check r.column(0).name == "col0"
  check r.column(1).name == "col1"
  var vi: seq[int64]
  var vs: seq[string]
  for chunk in r:
    let v0 = chunk.vector(0).bindAs DuckType.BigInt
    let v1 = chunk.vector(1).bindAs DuckType.Varchar
    for i in 0 ..< v0.len:
      vi.add v0[i]
      vs.add v1[i]
  check vi == @[0'i64, 1'i64, 2'i64]
  check vs == @["0", "1", "2"]

# ── T12: named tuple yields (v2) ─────────────────────────────────────────────
iterator namedTupleIter(n: int): tuple[idx: int, label: string] {.closure.} =
  for i in 0 ..< n: yield (idx: i, label: $i)

test "T12: tuple yields — named tuple":
  let conn = newDatabase().connect()
  conn.registerTableFunction(namedTupleIter)
  let r = conn.execute("SELECT * FROM namedTupleIter(3)")
  check r.column(0).name == "idx"
  check r.column(1).name == "label"
  var vi: seq[int64]
  var vs: seq[string]
  for chunk in r:
    let v0 = chunk.vector(0).bindAs DuckType.BigInt
    let v1 = chunk.vector(1).bindAs DuckType.Varchar
    for i in 0 ..< v0.len:
      vi.add v0[i]
      vs.add v1[i]
  check vi == @[0'i64, 1'i64, 2'i64]
  check vs == @["0", "1", "2"]

# ── T13: projection pushdown (v2) ────────────────────────────────────────────
test "T13: projection pushdown — select single column from tuple":
  let conn = newDatabase().connect()
  conn.registerTableFunction(tupleIter)
  let r = conn.execute("SELECT col1 FROM tupleIter(5)")
  check r.columnCount == 1
  check r.column(0).name == "col1"
  var vs: seq[string]
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.Varchar
    for i in 0 ..< v.len:
      vs.add v[i]
  check vs == @["0", "1", "2", "3", "4"]

# ── T14: projection pushdown with named tuple ────────────────────────────────
test "T14: projection pushdown — select single named col from tuple":
  let conn = newDatabase().connect()
  conn.registerTableFunction(namedTupleIter)
  let r = conn.execute("SELECT label FROM namedTupleIter(4)")
  check r.columnCount == 1
  check r.column(0).name == "label"
  var vs: seq[string]
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.Varchar
    for i in 0 ..< v.len:
      vs.add v[i]
  check vs == @["0", "1", "2", "3"]

# ── T15: column name for single-column = function name ───────────────────────
test "T15: single-col result has function name as column name":
  let conn = newDatabase().connect()
  conn.registerTableFunction(countToN)
  let r = conn.execute("SELECT * FROM countToN(3)")
  check r.column(0).name == "countToN"

# ═══ v3: Option[T] yields ══════════════════════════════════════════════════════

iterator optYield(n: int): Option[int] {.closure.} =
  for i in 0 ..< n:
    if i mod 2 == 0: yield some(i)
    else: yield none(int)

test "T16: Option[int] yield — NULL on odd rows":
  let conn = newDatabase().connect()
  conn.registerTableFunction(optYield)
  let r = conn.execute("SELECT * FROM optYield(5)")
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.BigInt
    for i in 0 ..< v.len:
      if i mod 2 == 0:
        check v.valid(i)
        check v[i] == int64(i)
      else:
        check not v.valid(i)

iterator optTupleYield(n: int): (Option[int], string) {.closure.} =
  for i in 0 ..< n:
    if i mod 2 == 0: yield (some(i), $i)
    else: yield (none(int), "NULL")

test "T17: Option[int] in tuple column — NULL on odd rows":
  let conn = newDatabase().connect()
  conn.registerTableFunction(optTupleYield)
  let r = conn.execute("SELECT * FROM optTupleYield(5)")
  var ints: seq[int64]
  var strs: seq[string]
  for chunk in r:
    let v0 = chunk.vector(0).bindAs DuckType.BigInt
    let v1 = chunk.vector(1).bindAs DuckType.Varchar
    for i in 0 ..< v0.len:
      check v1.valid(i)
      strs.add v1[i]
      if v0.valid(i):
        ints.add v0[i]
  check ints == @[0'i64, 2'i64, 4'i64]
  check strs == @["0", "NULL", "2", "NULL", "4"]

# ═══ v3: Option[T] params (NULL param passing) ═════════════════════════════════

iterator optParam(x: Option[int]): int {.closure.} =
  if x.isSome: yield x.get * 2
  else: yield -1

test "T18: Option[int] param — NULL → none, non-NULL → some":
  let conn = newDatabase().connect()
  conn.registerTableFunction(optParam)
  let r = conn.execute("SELECT * FROM optParam(10)")
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.BigInt
    check v[0] == 20'i64
  let r2 = conn.execute("SELECT * FROM optParam(NULL::BIGINT)")
  for chunk in r2:
    let v = chunk.vector(0).bindAs DuckType.BigInt
    check v[0] == -1'i64

test "T19: non-Option param with NULL input raises error":
  let conn = newDatabase().connect()
  conn.registerTableFunction(countToN)
  expect(OperationError):
    discard conn.execute("SELECT * FROM countToN(NULL::BIGINT)")

# ═══ v3: Cardinality hint ══════════════════════════════════════════════════════

test "T20: cardinality hint via macro argument":
  let conn = newDatabase().connect()
  conn.registerTableFunction(countToN, cardinality = 10)
  let r = conn.execute("SELECT * FROM countToN(5)")
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.BigInt
    check v.len == 5

# ═══ v3: Producer pragma ═══════════════════════════════════════════════════════

iterator prodTest(n: int): int {.producer, closure.} =
  for i in 0 ..< n: yield i * 10

test "T21: producer pragma generates registerProc":
  let conn = newDatabase().connect()
  registerProdTest(conn)
  let r = conn.execute("SELECT * FROM prodTest(3)")
  var vals: seq[int64]
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.BigInt
    for i in 0 ..< v.len: vals.add v[i]
  check vals == @[0'i64, 10'i64, 20'i64]

# ═══ v3: Local init hook ═══════════════════════════════════════════════════════

proc localInitNoop(info: InitInfo) {.cdecl.} =
  discard

test "T22: localInit callback accepted by registerTableFunction":
  let conn = newDatabase().connect()
  conn.registerTableFunction(countToN, localInit = localInitNoop)
  let r = conn.execute("SELECT * FROM countToN(3)")
  var vals: seq[int64]
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.BigInt
    for i in 0 ..< v.len: vals.add v[i]
  check vals == @[0'i64, 1'i64, 2'i64]

# ═══ v3: Named parameters ═════════════════════════════════════════════════════

test "T23: named params — named SQL call syntax works":
  let conn = newDatabase().connect()
  conn.registerTableFunction(countToN, named = true)
  let r = conn.execute("SELECT * FROM countToN(n := 4)")
  var vals: seq[int64]
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.BigInt
    for i in 0 ..< v.len: vals.add v[i]
  check vals == @[0'i64, 1'i64, 2'i64, 3'i64]

# ═══ Exception handling ════════════════════════════════════════════════════════

iterator crashIter(n: int): int {.closure.} =
  for i in 0 ..< n:
    if i == 2: raise newException(ValueError, "boom!")
    yield i

test "T24: exception in iterator body → error reported to DuckDB":
  let conn = newDatabase().connect()
  conn.registerTableFunction(crashIter)
  expect(OperationError):
    discard conn.execute("SELECT * FROM crashIter(5)")

# ═══ Exact cardinality ═════════════════════════════════════════════════════════

test "T25: exact cardinality hint":
  let conn = newDatabase().connect()
  conn.registerTableFunction(countToN, cardinality = 10, exact = true)
  let r = conn.execute("SELECT * FROM countToN(3)")
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.BigInt
    check v.len == 3

# ═══ Column name override ══════════════════════════════════════════════════════

test "T26: columnNames override for anonymous tuple":
  let conn = newDatabase().connect()
  conn.registerTableFunction(tupleIter, columnNames = @["num", "text"])
  let r = conn.execute("SELECT * FROM tupleIter(2)")
  check r.column(0).name == "num"
  check r.column(1).name == "text"
  var vs: seq[string]
  for chunk in r:
    let v = chunk.vector(1).bindAs DuckType.Varchar
    for i in 0 ..< v.len: vs.add v[i]
  check vs == @["0", "1"]

# ═══ ZonedTime type support ════════════════════════════════════════════════════

iterator zonedIter(): ZonedTime {.closure.} =
  yield ZonedTime()

test "T27: registerTableFunction accepts ZonedTime return type":
  let conn = newDatabase().connect()
  check compiles(conn.registerTableFunction(zonedIter))
