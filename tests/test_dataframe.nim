import unittest2
import ../src/[database, qresult, query, types]
import utils

suite "Test QResult display":
  setup:
    let duck = newDatabase().connect()
    duck.execute("DROP TABLE IF EXISTS temp")
    duck.execute("CREATE TABLE temp AS SELECT 10 AS foo, 'a' AS bar")
    duck.execute("INSERT INTO temp VALUES (20, 'b')")
    let r = duck.executeMaterialized("SELECT * FROM temp")

  test "Test result columns":
    var names: seq[string]
    for c in r.columns:
      names.add c.name
    check names == @["foo", "bar"]

  test "Test result columns accessed by name":
    check r.column("foo").name == "foo"
    check r.column("foo").kind == DuckType.Integer
    check r.column("bar").name == "bar"
    check r.column("bar").kind == DuckType.Varchar

  test "Test invalid column name":
    ignoreLeak:
      expect KeyError:
        discard r.column("something that does not exist")

  test "Test echo the result":
    let output = $r
    check output ==
      """
┌─────────────┬─────────────┐
│     foo     │     bar     │
├─────────────┼─────────────┤
│     10      │     a       │
│     20      │     b       │
└─────────────┴─────────────┘
"""
