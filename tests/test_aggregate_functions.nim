import std/options
import std/strutils
import unittest2
import ../src/[database, query, types, qresult, exceptions, aggregate_functions]

# ── Shared state type ───────────────────────────────────────────────────────
type WSum = object
  s: int64
  c: uint64

proc winit(s: var WSum) = s.s = 0; s.c = 0
proc wupd(s: var WSum, v, w: int64) = s.s += v * w; inc s.c
proc wcomb(dest: var WSum, src: WSum) = dest.s += src.s; dest.c += src.c
proc wfin(s: WSum): Option[int64] =
  if s.c == 0: none(int64) else: some(s.s)

# ── T1 ──────────────────────────────────────────────────────────────────────
test "T1: weighted_sum int64 Tier A, no GROUP BY":
  let conn = newDatabase().connect()
  conn.registerAggregate("wsum", winit, wupd, wcomb, wfin)
  var got: int64 = 0
  for chunk in conn.execute("SELECT wsum(i, 2) FROM range(5) t(i)"):
    let c = chunk.vector(0).bindAs DuckType.BigInt
    got = c[0]
  check got == 20

# ── T2 ──────────────────────────────────────────────────────────────────────
test "T2: weighted_sum int64 Tier A with GROUP BY":
  let conn = newDatabase().connect()
  conn.registerAggregate("wsum", winit, wupd, wcomb, wfin)
  var rows: seq[(int32, int64)]
  for chunk in conn.execute(
      "SELECT (i%2)::INTEGER AS g, wsum(i, 2)::BIGINT FROM range(100) t(i) " &
      "GROUP BY g ORDER BY g"):
    let g = chunk.vector(0).bindAs DuckType.Integer
    let a = chunk.vector(1).bindAs DuckType.BigInt
    for i in 0 ..< g.len: rows.add((g[i], a[i]))
  check rows == @[(0'i32, 4900'i64), (1'i32, 5000'i64)]

# ── T3 ──────────────────────────────────────────────────────────────────────
test "T3: NULL-on-empty via Option[T] — all-NULL group → NULL":
  let conn = newDatabase().connect()
  conn.registerAggregate("wsum", winit, wupd, wcomb, wfin)
  var sawNull = false
  for chunk in conn.execute(
      "SELECT wsum(CASE WHEN i<0 THEN i END, 1) FROM range(5) t(i)"):
    let c = chunk.vector(0).bindAs DuckType.BigInt
    sawNull = not c.valid(0)
  check sawNull

# ── T4 ──────────────────────────────────────────────────────────────────────
test "T4: NULL input filtered — standard SQL semantics":
  let conn = newDatabase().connect()
  conn.registerAggregate("wsum4", winit, wupd, wcomb, wfin)
  var got = -1'i64
  for chunk in conn.execute(
      "SELECT wsum4(v, w) FROM (VALUES (5::BIGINT, NULL::BIGINT), " &
      "(5::BIGINT, 2::BIGINT)) t(v,w)"):
    let c = chunk.vector(0).bindAs DuckType.BigInt
    got = c[0]
  check got == 10

# ── T5 ──────────────────────────────────────────────────────────────────────
test "T5: exception in update → OperationError":
  type Boom = object
    x: int64
  proc binit(s: var Boom) = s.x = 0
  proc bupd(s: var Boom, v: int64) = raise newException(ValueError, "boom")
  proc bcomb(dest: var Boom, src: Boom) = discard
  proc bfin(s: Boom): int64 = s.x
  let conn = newDatabase().connect()
  conn.registerAggregate("boomagg", binit, bupd, bcomb, bfin)
  expect(OperationError):
    discard conn.execute("SELECT boomagg(i) FROM range(3) t(i)")

# ── T6 ──────────────────────────────────────────────────────────────────────
test "T6: Option[T] args auto-enable special NULL handling":
  type Ncount = object
    seen: uint64
    nulls: uint64
  proc ninit(s: var Ncount) = s.seen = 0; s.nulls = 0
  proc nupd(s: var Ncount, v: Option[int64]) =
    if v.isSome: inc s.seen else: inc s.nulls
  proc ncomb(dest: var Ncount, src: Ncount) =
    dest.seen += src.seen; dest.nulls += src.nulls
  proc nfin(s: Ncount): int64 = int64(s.nulls)
  let conn = newDatabase().connect()
  conn.registerAggregate("countnulls", ninit, nupd, ncomb, nfin)
  var got = -1'i64
  # range(5) = 0,1,2,3,4; CASE i%2=0 keeps even, nulls odd → rows 1,3 NULL.
  for chunk in conn.execute(
      "SELECT countnulls(CASE WHEN i%2=0 THEN i END) FROM range(5) t(i)"):
    let c = chunk.vector(0).bindAs DuckType.BigInt
    got = c[0]
  check got == 2

# ── T7 ──────────────────────────────────────────────────────────────────────
test "T7: owning state with destroy proc — string list concat":
  type ListState = object
    parts: seq[string]
  proc linit(s: var ListState) = s.parts = @[]
  proc lupd(s: var ListState, v: string) = s.parts.add(v)
  proc lcomb(dest: var ListState, src: ListState) = dest.parts.add(src.parts)
  proc lfin(s: ListState): string = s.parts.join(",")
  proc ldestroy(s: var ListState) = s.parts.setLen(0)
  let conn = newDatabase().connect()
  conn.registerAggregate("listcat", linit, lupd, lcomb, lfin, destroy = ldestroy)
  var got = ""
  for chunk in conn.execute(
      "SELECT listcat(n::VARCHAR) FROM (VALUES ('a'),('b'),('c')) t(n)"):
    let c = chunk.vector(0).bindAs DuckType.Varchar
    got = c[0]
  check got == "a,b,c"

# ── T8 ──────────────────────────────────────────────────────────────────────
test "T8: Tier B equivalence — wsumv(i, 2) GROUP BY":
  proc winitv(s: var WSum) = s.s = 0; s.c = 0
  proc wupdv(states: States[WSum],
             v: Vector[DuckType.BigInt], w: Vector[DuckType.BigInt]) =
    for i in 0 ..< states.len:
      if v.valid(i) and w.valid(i):
        states[i].s += v[i] * w[i]
        inc states[i].c
  proc wcombv(dest, src: States[WSum]) =
    for i in 0 ..< dest.len:
      dest[i].s += src[i].s
      dest[i].c += src[i].c
  proc wfinv(src: States[WSum], outVec: var Vector[DuckType.BigInt],
             count, offset: int) =
    for i in 0 ..< count:
      if src[i].c == 0: outVec.setNull(offset + i)
      else: outVec[offset + i] = src[i].s
  let conn = newDatabase().connect()
  registerAggregate(conn, "wsumv", winitv, wupdv, wcombv, wfinv)
  var rows: seq[(int32, int64)]
  for chunk in conn.execute(
      "SELECT (i%2)::INTEGER AS g, wsumv(i, 2)::BIGINT FROM range(100) t(i) " &
      "GROUP BY g ORDER BY g"):
    let g = chunk.vector(0).bindAs DuckType.Integer
    let a = chunk.vector(1).bindAs DuckType.BigInt
    for i in 0 ..< g.len: rows.add((g[i], a[i]))
  check rows == @[(0'i32, 4900'i64), (1'i32, 5000'i64)]

# ── T9 ──────────────────────────────────────────────────────────────────────
test "T9: Tier B NULL-on-empty via user-driven setNull":
  proc winitv(s: var WSum) = s.s = 0; s.c = 0
  proc wupdv(states: States[WSum],
             v: Vector[DuckType.BigInt], w: Vector[DuckType.BigInt]) =
    for i in 0 ..< states.len:
      if v.valid(i) and w.valid(i):
        states[i].s += v[i] * w[i]
        inc states[i].c
  proc wcombv(dest, src: States[WSum]) =
    for i in 0 ..< dest.len:
      dest[i].s += src[i].s
      dest[i].c += src[i].c
  proc wfinv(src: States[WSum], outVec: var Vector[DuckType.BigInt],
             count, offset: int) =
    for i in 0 ..< count:
      if src[i].c == 0: outVec.setNull(offset + i)
      else: outVec[offset + i] = src[i].s
  let conn = newDatabase().connect()
  registerAggregate(conn, "wsumvN", winitv, wupdv, wcombv, wfinv)
  var sawNull = false
  for chunk in conn.execute(
      "SELECT wsumvN(CASE WHEN i<0 THEN i END, 1) FROM range(5) t(i)"):
    let c = chunk.vector(0).bindAs DuckType.BigInt
    sawNull = not c.valid(0)
  check sawNull

# ── T10 — compile-time rejections ──────────────────────────────────────────
proc goodInit(s: var WSum) = discard
proc goodUpd(s: var WSum, v: int64) = discard
proc goodComb(dest: var WSum, src: WSum) = discard
proc goodFin(s: WSum): int64 = 0

proc badInitNoVar(s: WSum) = discard
proc badUpdState(s: var int64, v: int64) = discard
proc badCombArity(dest: var WSum, src: WSum, extra: int) = discard
proc badCombVarSrc(dest: var WSum, src: var WSum) = discard
proc badFinVoid(s: WSum): void = discard
proc badFinVarState(s: var WSum): int64 = 0
proc badUpdUnsupported(s: var WSum, v: string) = discard
proc badDestroy(d: var int64) = discard
proc goodDestroy(s: var WSum) = discard
proc specialNonOpt(s: var WSum, v: int64) = discard

test "T10a: init not `var S` rejected":
  let conn = newDatabase().connect()
  check not compiles(conn.registerAggregate("x", badInitNoVar, goodUpd,
    goodComb, goodFin))

test "T10b: update state type mismatch rejected":
  let conn = newDatabase().connect()
  check not compiles(conn.registerAggregate("x", goodInit, badUpdState,
    goodComb, goodFin))

test "T10c: combine arity rejected":
  let conn = newDatabase().connect()
  check not compiles(conn.registerAggregate("x", goodInit, goodUpd,
    badCombArity, goodFin))

test "T10d: combine var src rejected":
  let conn = newDatabase().connect()
  check not compiles(conn.registerAggregate("x", goodInit, goodUpd,
    badCombVarSrc, goodFin))

test "T10e: finalize void return rejected":
  let conn = newDatabase().connect()
  check not compiles(conn.registerAggregate("x", goodInit, goodUpd,
    goodComb, badFinVoid))

test "T10f: finalize var state rejected":
  let conn = newDatabase().connect()
  check not compiles(conn.registerAggregate("x", goodInit, goodUpd,
    goodComb, badFinVarState))

test "T10g: destroy state mismatch rejected":
  let conn = newDatabase().connect()
  check not compiles(conn.registerAggregate("x", goodInit, goodUpd,
    goodComb, goodFin, destroy = badDestroy))

test "T11: Tier A aggregate with GROUP BY HAVING":
  let conn = newDatabase().connect()
  conn.registerAggregate("wsum_h", winit, wupd, wcomb, wfin)
  var got: int64 = 0
  for chunk in conn.execute(
    "SELECT wsum_h(i, 2) FROM range(100) t(i) WHERE i > 0 " &
    "HAVING wsum_h(i, 2) > 1000"):
    let c = chunk.vector(0).bindAs DuckType.BigInt
    got = c[0]
  # range(100) filtered to 1..99 → sum = 4950, weighted by 2 → 9900.
  # HAVING (>1000) keeps the single group.
  check got == 9900

test "T12: Exception in finalize → OperationError":
  type BoomFin = object
    x: int64
  proc binit(s: var BoomFin) = s.x = 0
  proc bupd(s: var BoomFin, v: int64) = s.x += v
  proc bcomb(dest: var BoomFin, src: BoomFin) = dest.x += src.x
  proc bfin(s: BoomFin): int64 =
    raise newException(ValueError, "finalize boom")
  let conn = newDatabase().connect()
  conn.registerAggregate("boomfin", binit, bupd, bcomb, bfin)
  expect(OperationError):
    discard conn.execute("SELECT boomfin(i) FROM range(3) t(i)")