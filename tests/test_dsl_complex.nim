## Complex OLAP queries through the NimDrake DSL, driven by the bundled
## TPC-H extension (https://duckdb.org/docs/stable/core_extensions/tpch).
##
## Data is generated in-memory with `CALL dbgen(sf = 0.01)` (~80k rows total):
##   customer(1500), lineitem(60175), nation(25), orders(15000),
##   part(2000), partsupp(8000), region(5), supplier(100)
##
## These tests are deliberately heavier than the forum-model suite: they
## stress the DSL with multi-way joins, grouped aggregates, CTEs, set
## operations, window functions, correlated subqueries, raw SQL splices,
## and bound parameters over realistic data. They double as executable
## documentation of what the DSL can express.
##
## DSL notes worth remembering:
## - The table of a `select` is alias `t1`; each `join` table gets `t2`,
##   `t3`, ... in order. Columns of later tables must be qualified with
##   their alias (`t2.n_name`) in the select/where/orderby clauses.
## - For grouped queries, keep join projections empty (`join orders() on ...`)
##   and put aggregates in the select, qualified by the owning table alias.
## - Window calls wrap the aggregate: `over(sum(x), partitionby(y) orderby(z))`.
## - A bare identifier in a where/orderby/having after a join is emitted
##   against the *first* table (t1) — qualify explicitly when ambiguous.
## - `except` is a Nim keyword, so the set op is spelled `` `except`(...) ``.
## - Correlated subqueries reference the outer row via its alias (`t1.`).
## - SQL's `*` is spelled `_` inside the DSL (e.g. `count(_)`).
##
## Note on `dsl/queries`: the extension is installed/loaded per fresh
## connection, so each test seeds its own dbgen dataset (cheap at sf=0.01).
## Expected values were captured against DuckDB 1.5.4 + tpch at sf=0.01.

import std/[algorithm, sequtils, strutils]
import unittest2
import decimal
import ../src/nimdrake
import nimdrake/dsl/queries

proc freshCon(): Connection =
  result = newDatabase().connect()
  result.execute("INSTALL tpch")
  result.execute("LOAD tpch")
  result.execute("CALL dbgen(sf = 0.01)")

proc ints(res: QResult[Materialized], col = 0): seq[int64] =
  for chunk in res.chunks:
    let kind = chunk.vector(col).kind
    if kind in {DuckType.Bigint, DuckType.Hugeint}:
      for v in chunk.bindAs(col, DuckType.Bigint):
        result.add v
    elif kind == DuckType.Integer:
      for v in chunk.bindAs(col, DuckType.Integer):
        result.add v.int64
    else:
      doAssert false, "unhandled int kind: " & $kind

proc strs(res: QResult[Materialized], col = 0): seq[string] =
  for chunk in res.chunks:
    for v in chunk.bindAs(col, DuckType.Varchar):
      result.add v

proc countRows(res: QResult[Materialized]): int64 =
  for chunk in res.chunks:
    for v in chunk.bindAs(0, DuckType.Bigint):
      result = v

suite "NimDrake DSL — TPC-H complex queries":

  test "Q1 style: single-table grouped aggregation (sum/avg/count)":
    let con = freshCon()
    let res = query(con):
      select lineitem(l_returnflag, l_linestatus,
                      sum(l_quantity) as sum_qty,
                      avg(l_quantity) as avg_qty,
                      count(l_orderkey) as count_order)
      where l_shipdate <= !!"DATE '1998-09-02'"
      groupby(l_returnflag, l_linestatus)
      orderby l_returnflag
    # All (returnflag, linestatus) buckets present in the dataset.
    check res.len == 4
    let flags = strs(res, 0)
    let statuses = strs(res, 1)
    check flags == @["A", "N", "N", "R"]
    check statuses == @["F", "F", "O", "F"]
    # Bucket counts (col 4) sum to the rows surviving the date filter.
    check ints(res, 4).foldl(a + b) == 59307

  test "Q1 style: group ordering is deterministic via orderby":
    let con = freshCon()
    let res = query(con):
      select lineitem(l_returnflag,
                      sum(l_extendedprice) as total)
      groupby(l_returnflag)
      orderby desc(total)
    check res.len == 3
    check strs(res, 0) == @["N", "R", "A"]

  test "Q3 style: 3-way join with filter, order, and limit":
    let con = freshCon()
    let res = query(con):
      select customer(c_name, t2.o_orderkey, t3.l_extendedprice)
      join orders() on t1.c_custkey == t2.o_custkey
      join lineitem() on t2.o_orderkey == t3.l_orderkey
      where t1.c_mktsegment == ?"BUILDING" and t2.o_orderdate < !!"DATE '1995-03-15'"
      orderby desc(t3.l_extendedprice)
      limit 10
    check res.len == 10
    check ints(res, 1).allIt(it > 0)

  test "Q5 style: 4-way join with groupby + having + order":
    let con = freshCon()
    let res = query(con):
      select nation(n_name, sum(t4.l_extendedprice) as revenue)
      join customer() on t1.n_nationkey == t2.c_nationkey
      join orders() on t2.c_custkey == t3.o_custkey
      join lineitem() on t3.o_orderkey == t4.l_orderkey
      groupby(t1.n_name)
      having sum(t4.l_extendedprice) > ?"0.0"
      orderby desc(revenue)
      limit 5
    check res.len == 5
    check strs(res, 0) == @["CANADA", "EGYPT", "IRAN", "BRAZIL", "ALGERIA"]

  test "Q7 style: string concat + case expression in select":
    let con = freshCon()
    let res = query(con):
      select supplier(s_nationkey,
                      (if s_acctbal > ?"8000": !!"'high'" else: !!"'low'") as bucket)
      join nation() on t1.s_nationkey == t2.n_nationkey
      where t2.n_name == ?"FRANCE" or t2.n_name == ?"GERMANY"
      orderby t1.s_nationkey
      limit 5
    check res.len == 5
    # FRANCE and GERMANY are nation keys 6 and 7 in the generated dataset.
    check ints(res, 0).allIt(it in @[6'i64, 7'i64])
    for b in strs(res, 1):
      check b in ["high", "low"]

  test "CTE: with select-grouped then aggregated on top":
    let con = freshCon()
    let res = query(con):
      with nationTotal(select lineitem(l_suppkey, sum(l_extendedprice) as tot) groupby(l_suppkey))
      select nationTotal(count(_) as suppliers)
    # 100 suppliers -> 100 grouped rows in the CTE.
    check countRows(res) == 100

  test "CTE with inline where inside the body":
    let con = freshCon()
    let res = query(con):
      with bigOrders(select orders(o_custkey, o_totalprice) where o_totalprice > ?(90000))
      select bigOrders(count(_) as n)
    check countRows(res) == 10268

  test "set op union: region names across two branches":
    let con = freshCon()
    let res = query(con):
      union(
        select region(r_name) where r_regionkey == ?(0),
        select region(r_name) where r_regionkey == ?(1))
    check strs(res).sorted == @["AFRICA", "AMERICA"]

  test "set op except: regions minus one":
    let con = freshCon()
    let res = query(con):
      `except`(
        select region(r_regionkey) where r_regionkey in ?(0) .. ?(4),
        select region(r_regionkey) where r_regionkey == ?(0))
    check ints(res).sorted == @[1'i64, 2'i64, 3'i64, 4'i64]

  test "set op intersect: AFRICA nations below key 10":
    let con = freshCon()
    let res = query(con):
      intersect(
        select nation(n_nationkey) where n_regionkey == ?(0),
        select nation(n_nationkey) where n_nationkey < ?(10))
    # AFRICA (region 0) holds nations 0 and 5 below key 10.
    check ints(res) == @[0'i64, 5'i64] or ints(res) == @[5'i64, 0'i64]

  test "window function: row_number over order":
    let con = freshCon()
    let res = query(con):
      select customer(c_custkey, over(row_number(), orderby(c_custkey)))
      limit 5
    check ints(res, 0) == @[1'i64, 2'i64, 3'i64, 4'i64, 5'i64]
    check ints(res, 1) == @[1'i64, 2'i64, 3'i64, 4'i64, 5'i64]

  when defined(i386) or defined(amd64):
    test "window function: sum over partition":
      let con = freshCon()
      let res = query(con):
        select lineitem(l_orderkey,
                        over(sum(l_quantity), partitionby(l_returnflag)))
        where l_returnflag == ?"R"
        groupby(l_orderkey, l_returnflag, l_quantity)
        orderby l_orderkey
        limit 5
      check res.len == 5
      # The windowed sum is a DECIMAL(38,2); every group has positive quantity.
      for chunk in res.chunks:
        for v in chunk.bindAs(1, DuckType.Decimal):
          let s = $v
          check s[0] != '-'
          check s != "0.00"

  test "correlated subquery with exists":
    let con = freshCon()
    let res = query(con):
      select customer(c_name)
      where exists(select orders(o_orderkey) where o_custkey == t1.c_custkey and o_totalprice > ?"99000")
      orderby c_name
      limit 3
    check res.len == 3
    check strs(res) == @["Customer#000000001", "Customer#000000002", "Customer#000000004"]

  test "subquery with in + not in":
    let con = freshCon()
    let res = query(con):
      select supplier(s_name)
      where s_nationkey notin (select nation(n_nationkey) where n_regionkey == ?(0))
      orderby s_name
      limit 3
    check res.len == 3
    check strs(res) == @["Supplier#000000001", "Supplier#000000003", "Supplier#000000005"]

  test "between + ilike filtering":
    let con = freshCon()
    let res = query(con):
      select part(p_name)
      where p_partkey in ?(500) .. ?(510) and p_name `ilike` ?"%goldenrod%"
      orderby p_name
      limit 3
    check res.len <= 3
    for n in strs(res):
      check n.toLowerAscii.contains("goldenrod")

  when defined(i386) or defined(amd64):
    test "parameter binds: decimal, int, string in one query":
      let con = freshCon()
      let minBal = newDecimal("0.00")
      let res = query(con):
        select supplier(s_name, s_acctbal)
        where s_acctbal >= ?minBal and s_suppkey < ?(10) and s_nationkey == ?(1)
      check res.len == 1
      check strs(res, 0) == @["Supplier#000000003"]
      # s_acctbal comes back as DECIMAL; assert it round-trips the bind ceiling.
      for chunk in res.chunks:
        for v in chunk.bindAs(1, DuckType.Decimal):
          check $v == "4192.40"

  test "leftjoin keeps unmatched rows with nulls":
    let con = freshCon()
    discard query(con):
      insert region(r_regionkey = ?(99), r_name = ?"NIM", r_comment = ?"none")
    let res = query(con):
      select region(r_name, t2.n_name)
      leftjoin nation() on t1.r_regionkey == t2.n_regionkey
      where r_regionkey == ?(99)
    check res.len == 1
    check strs(res, 0) == @["NIM"]
    # No nation references region 99, so the joined column is NULL.
    var nulls = 0
    for chunk in res.chunks:
      if not chunk.vector(1).valid(0):
        inc nulls
    check nulls == 1

  test "DML round-trip: insert / update / delete on TPC-H tables":
    let con = freshCon()
    let ins = query(con):
      insert nation(n_nationkey = ?(90), n_name = ?"NIM", n_regionkey = ?(0), n_comment = ?"added")
    check ins.rowsChanged == 1
    let upd = query(con):
      update nation(n_name = ?"NIM2")
      where n_nationkey == ?(90)
    check upd.rowsChanged == 1
    let sel = query(con):
      select nation(n_name)
      where n_nationkey == ?(90)
    check strs(sel) == @["NIM2"]
    let del = query(con):
      delete nation
      where n_nationkey == ?(90)
    check del.rowsChanged == 1
    let gone = query(con):
      select nation(n_name)
      where n_nationkey == ?(90)
    check gone.len == 0

  test "raw sql splice in expression":
    let con = freshCon()
    let res = query(con):
      select region(r_name & !!"', '" & r_comment as joined)
      where r_regionkey == ?(0)
    check res.len == 1
    check strs(res)[0].startsWith("AFRICA, ")
