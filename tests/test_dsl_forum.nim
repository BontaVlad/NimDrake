import std/times
import unittest2
import ../src/nimdrake
import nimdrake/dsl/queries

proc freshCon(): Connection =
  result = newDatabase().connect()
  result.execute("create table if not exists thread (id integer primary key, name varchar(100) not null, views integer not null default 0, modified timestamp not null)")
  result.execute("create table if not exists person (id integer primary key, name varchar(64) not null, email varchar(128) not null, status varchar(30) not null default 'active')")
  result.execute("create table if not exists post (id integer primary key, author integer not null, thread integer not null, header varchar(160) not null, content text not null, views integer not null default 0, created timestamp not null, foreign key (thread) references thread(id), foreign key (author) references person(id))")

proc tdt(year = 2024, month = mJan, day = 1, hour = 0, min = 0, sec = 0): DateTime =
  dateTime(year, month, day, hour, min, sec, zone = utc())

proc addOne(a: int64): int64 = a + 1

proc ints(res: QResult[Materialized], col = 0): seq[int64] =
  for chunk in res.chunks:
    for v in chunk.bindAs(col, DuckType.Integer):
      result.add v

proc strs(res: QResult[Materialized], col = 0): seq[string] =
  for chunk in res.chunks:
    for v in chunk.bindAs(col, DuckType.Varchar):
      result.add v

suite "NimDrake DSL — query macro (forum model)":

  test "insert / select round trip":
    let con = freshCon()
    discard query(con):
      insert thread(id = ?(1), name = ?"intro", views = ?(0), modified = ?tdt())
    discard query(con):
      insert thread(id = ?(2), name = ?"deep dive", views = ?(3),
                    modified = ?tdt(2024, mJan, 2))
    let res = query(con):
      select thread(id, name)
    check res.len == 2
    check ints(res, 0) == @[1'i64, 2'i64]
    check strs(res, 1) == @["intro", "deep dive"]

  test "insert returning id":
    let con = freshCon()
    let res = query(con):
      insert thread(id = ?(5), name = ?"ret", views = ?(0), modified = ?tdt(day = 5))
      returning id
    check ints(res) == @[5'i64]
    let back = query(con):
      select thread(name)
      where id == ?(5)
    check strs(back) == @["ret"]

  test "update":
    let con = freshCon()
    discard query(con):
      insert thread(id = ?(1), name = ?"intro", views = ?(0), modified = ?tdt())
    discard query(con):
      update thread(name = ?"intro v2", views = ?(7))
      where id == ?(1)
    let res = query(con):
      select thread(name, views)
      where id == ?(1)
    check strs(res, 0) == @["intro v2"]
    check ints(res, 1) == @[7'i64]

  test "delete":
    let con = freshCon()
    discard query(con):
      insert thread(id = ?(1), name = ?"intro", views = ?(0), modified = ?tdt())
    discard query(con):
      delete thread
      where id == ?(1)
    let res = query(con):
      select thread(id)
    check res.len == 0

  test "where with multiple params":
    let con = freshCon()
    for i in 1 .. 3:
      discard query(con):
        insert thread(id = ?(i), name = ?("t" & $i), views = ?(i),
                      modified = ?tdt(day = i))
    let res = query(con):
      select thread(id)
      where id == ?(1) and name == ?"t1"
    check ints(res) == @[1'i64]

  test "orderby limit offset":
    let con = freshCon()
    for i in 1 .. 10:
      discard query(con):
        insert thread(id = ?(i), name = ?("p" & $i), views = ?(0),
                      modified = ?tdt(day = i))
    let res = query(con):
      select thread(id)
      orderby desc(id)
      limit 3 offset 2
    check ints(res) == @[8'i64, 7'i64, 6'i64]

  test "explicit join (filter on primary, project joined column)":
    let con = freshCon()
    discard query(con):
      insert thread(id = ?(1), name = ?"intro", views = ?(0), modified = ?tdt())
    discard query(con):
      insert person(id = ?(1), name = ?"Alice", email = ?"a@x", status = ?"active")
    discard query(con):
      insert post(id = ?(1), author = ?(1), thread = ?(1),
                  header = ?"hi", content = ?"body",
                  views = ?(0), created = ?tdt(hour = 12))
    # The DSL auto-aliases tables (`t1`, `t2`, …). When a column name is
    # ambiguous between the two sides of the join, qualify it with the
    # generated alias explicitly.
    let res = query(con):
      select post(header, id)
      join person(name) on t1.author == t2.id
      where t1.id == ?(1)
    # Result columns: t1.header, t1.id, t2.name (join adds its columns).
    check res.len == 1
    check strs(res, 0) == @["hi"]
    check strs(res, 2) == @["Alice"]

  test "distinct and count":
    let con = freshCon()
    for i in 1 .. 4:
      discard query(con):
        insert person(id = ?(i), name = ?"dup",
                      email = ?("p" & $i & "@x"), status = ?"active")
    let names = query(con):
      select `distinct` person(name)
    check strs(names) == @["dup"]
    let cnt = query(con):
      select person(count(distinct name))
    var counts: seq[int64]
    for chunk in cnt.chunks:
      for v in chunk.bindAs(0, DuckType.BigInt):
        counts.add v
    check counts == @[1'i64]

  test "ilike":
    let con = freshCon()
    discard query(con):
      insert thread(id = ?(1), name = ?"Introduction",
                    views = ?(0), modified = ?tdt())
    let res = query(con):
      select thread(id)
      where name `ilike` ?"intro%"
    check ints(res) == @[1'i64]

  test "in range":
    let con = freshCon()
    for i in 1 .. 3:
      discard query(con):
        insert thread(id = ?(i), name = ?("t" & $i), views = ?(0),
                      modified = ?tdt(day = i))
    let res = query(con):
      select thread(id)
      where id in ?(1) .. ?(2)
    check ints(res) == @[1'i64, 2'i64]

  test "as alias":
    let con = freshCon()
    discard query(con):
      insert thread(id = ?(1), name = ?"intro", views = ?(0), modified = ?tdt())
    let res = query(con):
      select thread(name as topic)
    check strs(res) == @["intro"]

  test "transaction commit and rollback":
    let con = freshCon()
    con.transaction:
      discard query(con):
        insert thread(id = ?(1), name = ?"intro", views = ?(0), modified = ?tdt())
    check con.execute("select count(*) from thread").chunks[0]
      .bindAs(0, DuckType.BigInt).toSeq == @[1'i64]
    var failed = false
    try:
      con.transaction:
        discard query(con):
          insert thread(id = ?(1), name = ?"dup", views = ?(0), modified = ?tdt())
    except OperationError:
      failed = true
    check failed
    check con.execute("select count(*) from thread").chunks[0]
      .bindAs(0, DuckType.BigInt).toSeq == @[1'i64]

  test "onconflict doupdate":
    let con = freshCon()
    discard query(con):
      insert thread(id = ?(1), name = ?"intro", views = ?(10), modified = ?tdt())
    discard query(con):
      insert thread(id = ?(1), name = ?"intro", views = ?(20), modified = ?tdt())
      onconflict(id)
      doupdate(views = ?(20))
    let res = query(con):
      select thread(views)
      where id == ?(1)
    check ints(res) == @[20'i64]

  test "onconflict donothing":
    let con = freshCon()
    discard query(con):
      insert thread(id = ?(1), name = ?"intro", views = ?(10), modified = ?tdt())
    discard query(con):
      insert thread(id = ?(1), name = ?"intro", views = ?(30), modified = ?tdt())
      onconflict(id)
      donothing()
    let res = query(con):
      select thread(views)
      where id == ?(1)
    check ints(res) == @[10'i64]

  test "query errors raise OperationError":
    let con = freshCon()
    discard query(con):
      insert thread(id = ?(1), name = ?"intro", views = ?(0), modified = ?tdt())
    expect(OperationError):
      discard query(con):
        insert thread(id = ?(1), name = ?"dup", views = ?(0), modified = ?tdt())

  test "swallow errors via try/except":
    let con = freshCon()
    discard query(con):
      insert thread(id = ?(1), name = ?"intro", views = ?(0), modified = ?tdt())
    try:
      discard query(con):
        insert thread(id = ?(1), name = ?"dup", views = ?(0), modified = ?tdt())
    except OperationError:
      discard
    check con.execute("select count(*) from thread").chunks[0]
      .bindAs(0, DuckType.BigInt).toSeq == @[1'i64]

  test "raw sql splice":
    let con = freshCon()
    discard query(con):
      insert thread(id = ?(1), name = !!"'raw'", views = ?(0), modified = ?tdt())
    let res = query(con):
      select thread(name)
      where id == ?(1)
    check strs(res) == @["raw"]

  test "function call (registered scalar) in where":
    let con = freshCon()
    con.registerScalar(addOne)
    discard query(con):
      insert thread(id = ?(1), name = ?"intro", views = ?(0), modified = ?tdt())
    let res = query(con):
      select thread(id)
      where addOne(id) == ?(2)
    check ints(res) == @[1'i64]
