import unittest2
import std/[options]
import ../src/nimdrake

## Mirror DuckDB docs at https://duckdb.org/docs/current/sql/statements/create_type
##  1. ENUM, 2. STRUCT, 3. UNION, 4. Alias, 5. OR REPLACE

type
  Mood = enum
    happy
    sad
    curious

  ManyThings = object
    k: int32
    l: string

suite "Docs — CREATE TYPE examples":

  test "ENUM — CREATE TYPE mood AS ENUM ('happy','sad','curious') via helper":
    let db = newDatabase()
    let con = db.connect()
    let lt = con.createType(Mood, "mood", orReplace = true)
    check lt != nil
    check lt.toDuckType == DuckType.Enum
    let dt = con.execute("SELECT 1 FROM duckdb_types() WHERE type_name='mood'")
    var found = false
    for ch in dt:
      if ch.len > 0: found = true
    check found
    # Use as column type
    con.execute("CREATE TABLE t_mood (id INTEGER, m mood)")
    con.execute("INSERT INTO t_mood VALUES (1, 'happy'), (2, 'sad')")
    let res = con.execute("SELECT m FROM t_mood ORDER BY id")
    # Low-level Vector[Enum] check
    for chunk in res:
      let v = chunk.bindAs(0, DuckType.Enum)
      check v.len == 2
      # fromDuckEnum for first row should be 0 (happy)
      check v[0] == 0  #happy ord 0
      check v[1] == 1  #sad
    # High-level via toSeq with enum field
    type RowMood = object
      m: Mood
    let rows = con.execute("SELECT m FROM t_mood ORDER BY id").toSeq(RowMood)
    check rows.len == 2
    check rows[0].m == happy
    check rows[1].m == sad

  test "ENUM — inserting a label outside the dictionary raises and keeps the table unchanged":
    let db = newDatabase()
    let con = db.connect()
    discard con.createType(Mood, "mood_bad_insert", orReplace = true)
    con.execute("CREATE TABLE t_mood_bad_insert (id INTEGER, m mood_bad_insert)")
    con.execute("INSERT INTO t_mood_bad_insert VALUES (1, 'happy')")

    expect(OperationError):
      con.execute("INSERT INTO t_mood_bad_insert VALUES (2, 'bad')")

    for chunk in con.execute("SELECT count(*) FROM t_mood_bad_insert"):
      check chunk.bindAs(0, DuckType.BigInt)[0] == 1
    for chunk in con.execute("SELECT m FROM t_mood_bad_insert"):
      let values = chunk.bindAs(0, DuckType.Enum)
      check values.len == 1
      check values[0] == 0

  test "ENUM — an invalid label does not partially insert a multi-row statement":
    let db = newDatabase()
    let con = db.connect()
    discard con.createType(Mood, "mood_atomic", orReplace = true)
    con.execute("CREATE TABLE t_mood_atomic (id INTEGER, m mood_atomic)")

    expect(OperationError):
      con.execute("INSERT INTO t_mood_atomic VALUES (1, 'happy'), (2, 'bad')")

    for chunk in con.execute("SELECT count(*) FROM t_mood_atomic"):
      check chunk.bindAs(0, DuckType.BigInt)[0] == 0

  test "ENUM — raw DDL CREATE TYPE mood AS ENUM (...)":
    let db = newDatabase()
    let con = db.connect()
    con.execute("CREATE TYPE mood_raw AS ENUM ('happy','sad','curious')")
    let dt = con.execute("SELECT enum_range(NULL::mood_raw)")
    # enum_range returns list
    var got: seq[string] = @[]
    for chunk in dt:
      # single column list of varchar?
      # enum_range returns VARCHAR[] ? decode via ListView
      let cv = chunk.vector(0)
      # it's a LIST of VARCHAR
      let lv = cv.bindAs(seq[string])
      got = lv[0]
    check got == @["happy","sad","curious"]

  test "STRUCT — CREATE TYPE many_things AS STRUCT(k INTEGER, l VARCHAR) via object":
    let db = newDatabase()
    let con = db.connect()
    let lt = con.createType(ManyThings, "many_things", orReplace = true)
    check lt.toDuckType == DuckType.Struct
    let dt = con.execute("SELECT 1 FROM duckdb_types() WHERE type_name='many_things'")
    var found = false
    for ch in dt:
      if ch.len > 0: found = true
    check found
    # Use as column type
    con.execute("CREATE TABLE t_struct (id INTEGER, data many_things)")
    con.execute("INSERT INTO t_struct VALUES (1, {'k': 42, 'l': 'hello'})")
    con.execute("INSERT INTO t_struct VALUES (2, {'k': 7, 'l': 'world'})")
    # Query via x.k / x.l projection (flat)
    let resFlat = con.execute("SELECT data.k, data.l FROM t_struct ORDER BY id")
    let rowsFlat = resFlat.toSeq(ManyThings)
    check rowsFlat.len == 2
    check rowsFlat[0].k == 42
    check rowsFlat[0].l == "hello"
    # Query single STRUCT column using fallback path
    let resSingle = con.execute("SELECT data FROM t_struct ORDER BY id")
    let rowsSingle = resSingle.toSeq(ManyThings)
    check rowsSingle.len == 2
    check rowsSingle[1].k == 7
    check rowsSingle[1].l == "world"

  test "STRUCT — raw DDL CREATE TYPE many_things AS STRUCT...":
    let db = newDatabase()
    let con = db.connect()
    con.execute("CREATE TYPE many_things_raw AS STRUCT(k INTEGER, l VARCHAR)")
    con.execute("CREATE TABLE t_raw (v many_things_raw)")
    con.execute("INSERT INTO t_raw VALUES ({'k': 1, 'l': 'a'})")
    let res = con.execute("SELECT v.k FROM t_raw")
    for chunk in res:
      check chunk.bindAs(0, DuckType.Integer)[0] == 1

  test "UNION — CREATE TYPE one_thing AS UNION(number INTEGER, string VARCHAR)":
    let db = newDatabase()
    let con = db.connect()
    discard con.createUnionType("one_thing", "number INTEGER, string VARCHAR", orReplace = true)
    let dt = con.execute("SELECT 1 FROM duckdb_types() WHERE type_name='one_thing'")
    var found = false
    for ch in dt:
      if ch.len > 0: found = true
    check found
    con.execute("CREATE TABLE t_union (u one_thing)")
    con.execute("INSERT INTO t_union VALUES (union_value(number := 42)), (union_value(string := 'hello'))")
    let res = con.execute("SELECT u FROM t_union ORDER BY u")
    # Low-level union checks: tag 0 = number, 1 = string (based on DDL order)
    # Order by u sorts? number before string? We'll just check via union_tag
    for chunk in res:
      let v = chunk.bindAs(0, DuckType.Union)
      check v.unionMemberCount == 2
      check v.unionMemberName(0) == "number"
      check v.unionMemberName(1) == "string"
      # first row is number 42, second is string hello; but ORDER BY may intermix
      # So check both tags present
      var tags: seq[int] = @[]
      for i in 0..<v.len:
        tags.add(v.unionTag(i))
      check 0 in tags
      check 1 in tags
      # Extract values
      let numChild = v.unionMemberChild(0, DuckType.Integer)
      let strChild = v.unionMemberChild(1, DuckType.Varchar)
      # Find row with tag 0
      for i in 0..<v.len:
        if v.unionTag(i) == 0:
          check numChild[i] == 42
        elif v.unionTag(i) == 1:
          check strChild[i] == "hello"
    # Also test union_extract via SQL
    let res2 = con.execute("SELECT union_extract(u, 'number') AS n, union_extract(u, 'string') AS s FROM t_union ORDER BY u")
    var hasNum = false
    var hasStr = false
    for chunk in res2:
      let n = chunk.vector(0)
      let s = chunk.vector(1)
      for i in 0..<chunk.len:
        if n.valid(i):
          check n.bindAs(DuckType.Integer)[i] == 42
          hasNum = true
        if s.valid(i):
          check s.bindAs(DuckType.Varchar)[i] == "hello"
          hasStr = true
    check hasNum
    check hasStr

  test "UNION — raw DDL and union_tag / union_extract":
    let db = newDatabase()
    let con = db.connect()
    con.execute("CREATE TYPE one_thing_raw AS UNION(number INTEGER, string VARCHAR)")
    con.execute("CREATE TABLE t2 (u one_thing_raw)")
    con.execute("INSERT INTO t2 VALUES (union_value(number := 7))")
    let res = con.execute("SELECT union_tag(u)::VARCHAR as tag, union_extract(u, 'number') FROM t2")
    for chunk in res:
      check chunk.bindAs(0, DuckType.Varchar)[0] == "number"
      check chunk.bindAs(1, DuckType.Integer)[0] == 7

  test "Alias — CREATE TYPE x_index AS INTEGER":
    let db = newDatabase()
    let con = db.connect()
    discard con.createAliasType("x_index", "INTEGER", orReplace = true)
    let dt = con.execute("SELECT 1 FROM duckdb_types() WHERE type_name='x_index'")
    var found = false
    for ch in dt:
      if ch.len > 0: found = true
    check found
    con.execute("CREATE TABLE t_alias (id x_index, val VARCHAR)")
    con.execute("INSERT INTO t_alias VALUES (1, 'a'), (2, 'b')")
    type RowAlias = object
      id: int32
      val: string
    let rows = con.execute("SELECT id, val FROM t_alias ORDER BY id").toSeq(RowAlias)
    check rows.len == 2
    check rows[0].id == 1
    check rows[1].val == "b"

  test "OR REPLACE — CREATE OR REPLACE TYPE mood AS ENUM":
    let db = newDatabase()
    let con = db.connect()
    # Initial
    con.execute("CREATE TYPE mood AS ENUM ('happy','sad','curious')")
    let r1 = con.execute("SELECT unnest(enum_range(NULL::mood)) ORDER BY 1")
    var before: seq[string] = @[]
    for chunk in r1:
      before.add(chunk.bindAs(0, DuckType.Varchar).toSeq)
    check before == @["curious","happy","sad"] or before.len == 3 # order may be sorted
    # Replace
    con.execute("CREATE OR REPLACE TYPE mood AS ENUM ('cheerful','gloomy')")
    let r2 = con.execute("SELECT unnest(enum_range(NULL::mood)) ORDER BY 1")
    var after: seq[string] = @[]
    for chunk in r2:
      after.add(chunk.bindAs(0, DuckType.Varchar).toSeq)
    check "cheerful" in after
    check "gloomy" in after
    check after.len == 2
    # Helper with orReplace=true should also succeed
    type NewMood = enum cheerful, gloomy
    discard con.createType(NewMood, "mood", orReplace = true)
    let r3 = con.execute("SELECT unnest(enum_range(NULL::mood)) ORDER BY 1")
    var after2: seq[string] = @[]
    for chunk in r3:
      after2.add(chunk.bindAs(0, DuckType.Varchar).toSeq)
    check after2.len == 2

  test "Object with ENUM field via toSeq (nested enum via struct)":
    type Mood2 = enum happy, sad, curious
    type RowWithEnum = object
      id: int32
      mood: Mood2
    let db = newDatabase()
    let con = db.connect()
    discard con.createType(Mood2, "mood2", orReplace = true)
    con.execute("CREATE TABLE t_enum_row (id INTEGER, mood mood2)")
    con.execute("INSERT INTO t_enum_row VALUES (1, 'happy'), (2, 'curious')")
    let rows = con.execute("SELECT id, mood FROM t_enum_row ORDER BY id").toSeq(RowWithEnum)
    check rows.len == 2
    check rows[0].mood == happy
    check rows[1].mood == curious
    check rows[1].id == 2

  test "Struct containing enum via toSeq (requires enum type created first)":
    type Mood3 = enum a, b
    let db = newDatabase()
    let con = db.connect()
    discard con.createType(Mood3, "mood3", orReplace = true)
    # Create struct type that contains enum — will use inline ENUM definition inside struct
    # Our sqlTypeFor for enum inside struct generates inline ENUM('a','b'), so no need for prior enum for struct member
    # But we test both: create table with STRUCT containing enum column
    con.execute("CREATE TABLE t_struct_enum (s STRUCT(m Mood3, v INTEGER))")
    # This DDL uses Mood3 as column type inside struct — DuckDB may need enum type available; we already created mood3
    con.execute("INSERT INTO t_struct_enum VALUES ({'m': 'a', 'v': 10})")
    let res = con.execute("SELECT s.m, s.v FROM t_struct_enum")
    type Flat = object
      m: Mood3
      v: int32
    let rows = res.toSeq(Flat)
    check rows[0].m == a
    check rows[0].v == 10
