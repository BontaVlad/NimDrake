import unittest2
import std/[options, tables]
import ../src/nimdrake

type
  User = object
    homeAddress: string
    age: int64

  UserOpt = object
    homeAddress: string
    age: Option[int64]
    nickname: Option[string]

suite "Test struct_mapping — seq[Object] via ToSeq":

  test "Simple Users via ToSeq from materialized result":
    let db = newDatabase()
    let con = db.connect()
    con.execute("CREATE TABLE users (homeAddress VARCHAR, age BIGINT)")
    con.appendRows("users", @[
      User(homeAddress: "NYC", age: 30),
      User(homeAddress: "LA", age: 25),
    ])
    let res = con.execute("SELECT homeAddress, age FROM users ORDER BY age")
    let users = res.toSeq(User)
    check users.len == 2
    check users[0].homeAddress == "LA"
    check users[0].age == 25
    check users[1].homeAddress == "NYC"
    check users[1].age == 30
    # Ensure typed access is int64
    check users[0].age is int64

  test "CreateType creates persistent duckdb type":
    let db = newDatabase()
    let con = db.connect()
    let lt = con.createType(User, "users_t", orReplace = true)
    check lt != nil
    # Check duckdb_types contains it
    let dt = con.execute("SELECT 1 FROM duckdb_types() WHERE type_name = 'users_t'")
    var found = false
    for ch in dt:
      if ch.len > 0: found = true
    check found

  test "ToSeq handles nullable Option fields":
    let db = newDatabase()
    let con = db.connect()
    con.execute("CREATE TABLE users_opt (homeAddress VARCHAR, age BIGINT, nickname VARCHAR)")
    # Insert via SQL for NULL handling
    con.execute("INSERT INTO users_opt VALUES ('NYC', 30, NULL)")
    con.execute("INSERT INTO users_opt VALUES ('LA', NULL, 'lala')")
    let res = con.execute("SELECT homeAddress, age, nickname FROM users_opt ORDER BY homeAddress")
    let rows = res.toSeq(UserOpt)
    check rows.len == 2
    # Ordered by homeAddress: LA, NYC
    check rows[0].homeAddress == "LA"
    check rows[0].age.isNone  # actually age NULL for LA? Wait LA has NULL age? Let's see inserts: first NYC 30 NULL, second LA NULL lala
    # Correction: row 0 = LA with NULL age, some nickname
    check rows[0].nickname == some("lala")
    check rows[1].homeAddress == "NYC"
    check rows[1].age == some(30'i64)
    check rows[1].nickname.isNone

  test "ToSeq case-insensitive column matching":
    let db = newDatabase()
    let con = db.connect()
    con.execute("CREATE TABLE users2 (HOMEADDRESS VARCHAR, AGE BIGINT)")
    con.execute("INSERT INTO users2 VALUES ('Boston', 40)")
    let res = con.execute("SELECT HOMEADDRESS, AGE FROM users2")
    let users = res.toSeq(User)
    check users.len == 1
    check users[0].homeAddress == "Boston"
    check users[0].age == 40

  test "ToSeq ignores extra columns":
    let db = newDatabase()
    let con = db.connect()
    con.execute("CREATE TABLE users3 (homeAddress VARCHAR, age BIGINT, extra VARCHAR)")
    con.execute("INSERT INTO users3 VALUES ('X', 1, 'ignored')")
    let res = con.execute("SELECT homeAddress, age, extra FROM users3")
    let users = res.toSeq(User)
    check users.len == 1
    check users[0].homeAddress == "X"

  test "ToSeq raises on missing non-optional column":
    let db = newDatabase()
    let con = db.connect()
    con.execute("CREATE TABLE users4 (homeAddress VARCHAR)")
    con.execute("INSERT INTO users4 VALUES ('onlyAddress')")
    let res = con.execute("SELECT homeAddress FROM users4")
    var raised = false
    try:
      discard res.toSeq(User)
    except ValueError:
      raised = true
    check raised

  test "ToSeq missing Option field becomes none":
    let db = newDatabase()
    let con = db.connect()
    con.execute("CREATE TABLE users5 (homeAddress VARCHAR)")
    con.execute("INSERT INTO users5 VALUES ('addrOnly')")
    let res = con.execute("SELECT homeAddress FROM users5")
    let rows = res.toSeq(UserOpt)
    check rows.len == 1
    check rows[0].homeAddress == "addrOnly"
    check rows[0].age.isNone
    check rows[0].nickname.isNone

  test "Chunk-level ToSeq":
    let db = newDatabase()
    let con = db.connect()
    con.execute("CREATE TABLE users6 (homeAddress VARCHAR, age BIGINT)")
    con.execute("INSERT INTO users6 VALUES ('a', 1), ('b', 2)")
    let res = con.execute("SELECT homeAddress, age FROM users6 ORDER BY age")
    var all: seq[User] = @[]
    for chunk in res:
      let part = chunk.toSeq(User)
      all.add(part)
    check all.len == 2
    check all[0].age == 1

  test "Streaming ToSeq":
    let db = newDatabase()
    let con = db.connect()
    con.execute("CREATE TABLE users7 (homeAddress VARCHAR, age BIGINT)")
    con.execute("INSERT INTO users7 VALUES ('s1', 10), ('s2', 20)")
    var stmt = con.newStatement("SELECT homeAddress, age FROM users7 ORDER BY age")
    let users = con.executeStreaming(stmt).toSeq(User)
    check users.len == 2
    check users[1].age == 20

  test "createTableFromObject + appendRows round-trip":
    let db = newDatabase()
    let con = db.connect()
    con.createTableFromObject("users8", User)
    con.appendRows("users8", @[User(homeAddress: "p1", age: 99)])
    let res = con.execute("SELECT homeAddress, age FROM users8")
    let users = res.toSeq(User)
    check users.len == 1
    check users[0].homeAddress == "p1"
