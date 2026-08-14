import std/[json, times, sequtils, options]
import unittest2
import decimal
import uuid4
import ../src/nimdrake
import nimdrake/dsl/queries

proc freshCon(): Connection =
  result = newDatabase().connect()
  result.execute("create table if not exists tb_boolean (typboolean boolean not null)")
  result.execute("create table if not exists tb_float (typfloat double not null)")
  result.execute("create table if not exists tb_string (typstring varchar not null)")
  result.execute("create table if not exists tb_timestamp (dt1 timestamp not null, dt2 timestamp not null)")
  result.execute("create table if not exists tb_date (dt date not null)")
  result.execute("create table if not exists tb_decimal (amount decimal(18, 2) not null)")
  result.execute("create table if not exists tb_uuid (uid uuid not null)")
  result.execute("create table if not exists tb_json (typjson json not null)")
  result.execute("create table if not exists tb_blob (id integer primary key, typblob blob not null)")
  result.execute("create table if not exists tb_nullable (id integer primary key, note varchar null)")

suite "NimDrake DSL — type round-trips":

  test "bool":
    let con = freshCon()
    discard query(con):
      insert tb_boolean(typboolean = ?(true))
    let res = query(con):
      select tb_boolean(typboolean)
    for chunk in res.chunks:
      check chunk.bindAs(0, DuckType.Boolean).toSeq == @[true]

  test "float":
    let con = freshCon()
    discard query(con):
      insert tb_float(typfloat = ?(3.14))
    let res = query(con):
      select tb_float(typfloat)
    for chunk in res.chunks:
      check chunk.bindAs(0, DuckType.Double).toSeq == @[3.14]

  test "string":
    let con = freshCon()
    discard query(con):
      insert tb_string(typstring = ?"hello world")
    let res = query(con):
      select tb_string(typstring)
    for chunk in res.chunks:
      check chunk.bindAs(0, DuckType.Varchar).toSeq == @["hello world"]

  test "blob":
    let con = freshCon()
    let blob = @[byte 0, 1, 2, 255]
    discard query(con):
      insert tb_blob(id = ?(1), typblob = ?blob)
    let res = query(con):
      select tb_blob(typblob)
    for chunk in res.chunks:
      check chunk.bindAs(0, DuckType.Blob).toSeq == @[blob]

  test "timestamp":
    let con = freshCon()
    let dt = dateTime(2024, mJan, 5, 10, 30, 0, zone = utc())
    discard query(con):
      insert tb_timestamp(dt1 = ?dt, dt2 = ?dt)
    let res = query(con):
      select tb_timestamp(dt1, dt2)
    for chunk in res.chunks:
      let d1 = chunk.bindAs(0, DuckType.Timestamp)
      let d2 = chunk.bindAs(1, DuckType.Timestamp)
      check d1.len == 1
      check DateTime(d1[0]) == dt
      check DateTime(d2[0]) == dt

  test "date":
    let con = freshCon()
    let d = dateTime(2024, mFeb, 29, zone = utc())
    discard query(con):
      insert tb_date(dt = ?d)
    let res = query(con):
      select tb_date(dt)
    for chunk in res.chunks:
      check chunk.bindAs(0, DuckType.Date).toSeq == @[d]

  test "decimal":
    let con = freshCon()
    let amount = newDecimal("123.45")
    discard query(con):
      insert tb_decimal(amount = ?amount)
    let res = query(con):
      select tb_decimal(amount)
    for chunk in res.chunks:
      let v = chunk.bindAs(0, DuckType.Decimal)
      check v.len == 1
      check $v[0] == "123.45"

  test "uuid":
    let con = freshCon()
    let uid = initUuid("a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11")
    discard query(con):
      insert tb_uuid(uid = ?uid)
    let res = query(con):
      select tb_uuid(uid)
    for chunk in res.chunks:
      check chunk.bindAs(0, DuckType.UUID).toSeq == @[uid]

  test "json":
    let con = freshCon()
    let payload = %*{"k": [1, 2], "s": "x"}
    discard query(con):
      insert tb_json(typjson = ?payload)
    let res = query(con):
      select tb_json(typjson)
    for chunk in res.chunks:
      check chunk.bindAs(0, DuckType.Varchar).toSeq.mapIt(parseJson(it)) == @[payload]

  test "null via Option":
    let con = freshCon()
    discard query(con):
      insert tb_nullable(id = ?(1), note = ?none(string))
    let res = query(con):
      select tb_nullable(id, note)
    for chunk in res.chunks:
      let idc = chunk.bindAs(0, DuckType.Integer)
      let note = chunk.vector(1)
      check idc.toSeq == @[1'i32]
      check note.valid(0) == false

  test "null via Option (note present)":
    let con = freshCon()
    discard query(con):
      insert tb_nullable(id = ?(1), note = ?"present")
    let res = query(con):
      select tb_nullable(note)
    for chunk in res.chunks:
      check chunk.bindAs(0, DuckType.Varchar).toSeq == @["present"]

  test "rowsChanged after insert":
    let con = freshCon()
    let r = query(con):
      insert tb_boolean(typboolean = ?(true))
    check r.rowsChanged == 1
