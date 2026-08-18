import unittest2
import std/strutils
import ../src/[database, qresult, query, types, display]
import utils

suite "Test QResult display":
  setup:
    let duck = newDatabase().connect()
    duck.execute("DROP TABLE IF EXISTS temp")
    duck.execute("CREATE TABLE temp AS SELECT 10 AS foo, 'a' AS bar")
    duck.execute("INSERT INTO temp VALUES (20, 'b')")
    let r = duck.execute("SELECT * FROM temp")

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

  test "Display of empty result set":
    let duck2 = newDatabase().connect()
    let empty = duck2.execute("SELECT 1 AS x WHERE 1=0")
    let output = $empty
    check output.contains("x")

  test "Display of single-column result":
    let duck2 = newDatabase().connect()
    let sc = duck2.execute("SELECT 42 AS answer")
    let output = $sc
    check output.contains("answer")
    check output.contains("42")

  test "Display renders NULL cells":
    let duck2 = newDatabase().connect()
    let r = duck2.execute("SELECT NULL::BIGINT AS n, 5::BIGINT AS v")
    let output = $r
    check output.contains("NULL")
    check output.contains("5")

  when defined(i386) or defined(amd64):
    test "Display renders Decimal with scale":
      let duck2 = newDatabase().connect()
      let r = duck2.execute("SELECT 12.34::DECIMAL(18,2) AS d")
      let output = $r
      check output.contains("12.34")

  test "Display renders Double NaN and Infinity":
    let duck2 = newDatabase().connect()
    let r = duck2.execute("SELECT 'NaN'::DOUBLE AS a, 'Infinity'::DOUBLE AS b")
    let output = $r
    check output.contains("nan") or output.contains("NaN")
    check output.contains("inf") or output.contains("Inf")

  test "Display of >20 rows is clipped with a footer row":
    let duck2 = newDatabase().connect()
    let r = duck2.execute("SELECT seq AS i FROM generate_series(1, 50) AS t(seq)")
    let output = $r
    check output.contains("1")
    check output.contains("20")
    check not output.contains("21")

  test "Display renders full varchar cell values":
    let duck2 = newDatabase().connect()
    let longStr = repeat('x', 100)
    let r = duck2.executeMaterialized("SELECT ? AS s", (longStr,))
    let output = $r
    check output.contains(longStr)
    # The column header is clipped, but the cell value is not
    check output.contains("s")
