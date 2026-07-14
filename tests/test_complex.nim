import std/[tables, strutils]
import unittest2
import ../src/[types, database, query, qresult, complex]

proc normalize(x: string): string =
  result = x
  result = result.replace(" ", "")
  result = result.replace("\t", "")
  result = result.multiReplace([("\"", "'"), ("NULL", "null"), ("'", "\"")])
  result = result.toLowerAscii()

suite "Complex — toList":
  test "toList[BigInt] over generate_series":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT [seq, seq + 1, seq + 2] FROM generate_series(1, 3) AS t(seq)"
    )
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.List)
      let lst = toList[DuckType.BigInt](v)
      check lst == @[@[1'i64, 2, 3], @[2'i64, 3, 4], @[3'i64, 4, 5]]

  test "toList[Varchar] over string list":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT ['hello', 'world']"
    )
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.List)
      let lst = toList[DuckType.Varchar](v)
      check lst == @[ @["hello", "world"] ]

  test "toList with null element":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT [1, NULL, 3]"
    )
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.List)
      let lst = toList[DuckType.Integer](v)
      check lst == @[ @[1'i32, 0, 3] ]

suite "Complex — toArray":
  test "toArray[Integer]":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT ARRAY[10, 20, 30, 40]::INT[4]"
    )
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.Array)
      check v.arraySize == 4
      let arr = toArray[DuckType.Integer](v)
      check arr == @[ @[10'i32, 20, 30, 40] ]

  test "toArray[Double] multi-row":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT ARRAY[x, x + 0.5, x + 1.0]::DOUBLE[3] FROM generate_series(1, 2) AS t(x)"
    )
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.Array)
      check v.arraySize == 3
      let arr = toArray[DuckType.Double](v)
      check arr == @[ @[1.0, 1.5, 2.0], @[2.0, 2.5, 3.0] ]

suite "Complex — toStructPairs":
  test "toStructPairs over simple struct":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT {'a': 100, 'b': 'hello'} AS s"
    )
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.Struct)
      let pairs = toStructPairs(v)
      check pairs.len == 1
      check pairs[0].len == 2
      var foundA, foundB: bool
      for (name, nv) in pairs[0]:
        if name == "a":
          check nv.kind == nvInt
          check nv.intVal == 100
          foundA = true
        elif name == "b":
          check nv.kind == nvString
          check nv.strVal == "hello"
          foundB = true
      check foundA and foundB

  test "toStructPairs with null struct row":
    let conn = newDatabase().connect()
    discard conn.execute("CREATE TABLE null_struct(i INT, s STRUCT(a INTEGER));")
    discard conn.execute(
      "INSERT INTO null_struct VALUES (1, {'a': 42}), (2, NULL);"
    )
    let r = conn.execute("SELECT * FROM null_struct ORDER BY i")
    var seen = 0
    for chunk in r:
      let v = chunk.bindAs(1, DuckType.Struct)
      let pairs = toStructPairs(v)
      check pairs.len == 2
      check pairs[0].len == 1
      check pairs[0][0][1].intVal == 42
      check pairs[1].len == 0
      seen.inc
    check seen == 1

suite "Complex — toStructChild":
  test "toStructChild by index":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT {'a': 100, 'b': 'hello'} AS s"
    )
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.Struct)
      let aVals = toStructChild[DuckType.Integer](v, 0)
      check aVals == @[100'i32]

  test "toStructChild by name":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT {'a': 100, 'b': 'hello'} AS s"
    )
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.Struct)
      let bVals = toStructChild[DuckType.Varchar](v, "b")
      check bVals == @["hello"]

suite "Complex — toMap":
  test "toMap[Varchar, Integer]":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT MAP(['a', 'b'], [1, 2])"
    )
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.Map)
      let maps = toMap[DuckType.Varchar, DuckType.Integer](v)
      check maps.len == 1
      check maps[0]["a"] == 1
      check maps[0]["b"] == 2
      check maps[0].len == 2

  test "toMap[Integer, Varchar] multi-row":
    let conn = newDatabase().connect()
    discard conn.execute(
      "CREATE TABLE int_maps(m MAP(INTEGER, VARCHAR));"
    )
    discard conn.execute(
      "INSERT INTO int_maps VALUES (MAP([10], ['ten'])), (MAP([20, 30], ['twenty', 'thirty']));"
    )
    let r = conn.execute("SELECT * FROM int_maps ORDER BY m[10]")
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.Map)
      let maps = toMap[DuckType.Integer, DuckType.Varchar](v)
      check maps.len == 2
      check maps[0].len == 1
      check maps[0][10] == "ten"
      check maps[1].len == 2
      check maps[1][20] == "twenty"
      check maps[1][30] == "thirty"

suite "Complex — toUnion":
  test "toUnion single member":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT union_value(num := 99)"
    )
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.Union)
      let un = toUnion(v)
      check un.len == 1
      let (name, nv) = un[0]
      check name == "num"
      check nv.kind == nvInt
      check nv.intVal == 99

  test "unionTag read":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT union_value(num := 42)"
    )
    for chunk in r:
      let v = chunk.bindAs(0, DuckType.Union)
      check v.unionTag(0) == 0

suite "Complex — toNimValue / toNimValues":
  test "toNimValue primitive int":
    let conn = newDatabase().connect()
    let r = conn.execute("SELECT 42")
    for chunk in r:
      let cv = chunk.vector(0)
      let nv = toNimValue(cv, 0)
      check nv.kind == nvInt
      check nv.intVal == 42

  test "toNimValue varchar":
    let conn = newDatabase().connect()
    let r = conn.execute("SELECT 'hello'")
    for chunk in r:
      let cv = chunk.vector(0)
      let nv = toNimValue(cv, 0)
      check nv.kind == nvString
      check nv.strVal == "hello"

  test "toNimValue null":
    let conn = newDatabase().connect()
    let r = conn.execute("SELECT NULL")
    for chunk in r:
      let cv = chunk.vector(0)
      let nv = toNimValue(cv, 0)
      check nv.kind == nvNull

  test "toNimValue bool":
    let conn = newDatabase().connect()
    let r = conn.execute("SELECT true")
    for chunk in r:
      let cv = chunk.vector(0)
      let nv = toNimValue(cv, 0)
      check nv.kind == nvBool
      check nv.boolVal == true

  test "toNimValue float / double":
    let conn = newDatabase().connect()
    let r = conn.execute("SELECT CAST(3.14 AS DOUBLE)")
    for chunk in r:
      let cv = chunk.vector(0)
      let nv = toNimValue(cv, 0)
      check nv.kind == nvFloat
      check nv.floatVal == 3.14

  test "toNimValue List":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT [1, 2, 3]"
    )
    for chunk in r:
      let cv = chunk.vector(0)
      let nv = toNimValue(cv, 0)
      check nv.kind == nvList
      check nv.listVal.len == 3
      check nv.listVal[0].intVal == 1
      check nv.listVal[2].intVal == 3

  test "toNimValue Array":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT ARRAY[10, 20, 30]::INT[3]"
    )
    for chunk in r:
      let cv = chunk.vector(0)
      let nv = toNimValue(cv, 0)
      check nv.kind == nvList
      check nv.listVal.len == 3
      check nv.listVal[0].intVal == 10
      check nv.listVal[1].intVal == 20
      check nv.listVal[2].intVal == 30

  test "toNimValue Struct":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT {'a': 1, 'b': 'x'} AS s"
    )
    for chunk in r:
      let cv = chunk.vector(0)
      let nv = toNimValue(cv, 0)
      check nv.kind == nvStruct
      check nv.fields.len == 2
      var foundA, foundB: bool
      for (name, nv2) in nv.fields:
        if name == "a":
          check nv2.intVal == 1
          foundA = true
        elif name == "b":
          check nv2.strVal == "x"
          foundB = true
      check foundA and foundB

  test "toNimValue Map":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT MAP(['k1'], [99])"
    )
    for chunk in r:
      let cv = chunk.vector(0)
      let nv = toNimValue(cv, 0)
      check nv.kind == nvMap
      check nv.mapVal.len == 1
      check nv.mapVal[0][0].strVal == "k1"
      check nv.mapVal[0][1].intVal == 99

  test "toNimValue Union":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT union_value(num := 10)"
    )
    for chunk in r:
      let cv = chunk.vector(0)
      let nv = toNimValue(cv, 0)
      check nv.kind == nvUnion
      check nv.memberName == "num"
      check nv.memberVal.intVal == 10

  test "toNimValues multi-row":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT seq FROM generate_series(1, 3) AS t(seq)"
    )
    for chunk in r:
      let values = chunk.vector(0).toNimValues
      check values.len == 3
      check values[0].intVal == 1
      check values[1].intVal == 2
      check values[2].intVal == 3

suite "Complex — nested materialize":
  test "List of Struct":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT [{'a': 1, 'b': 2}, {'a': 3, 'b': 4}]"
    )
    for chunk in r:
      let nv = chunk.vector(0).toNimValue(0)
      check nv.kind == nvList
      check nv.listVal.len == 2
      check nv.listVal[0].kind == nvStruct
      check nv.listVal[0].fields.len == 2
      var foundA1, foundB1: bool
      for (name, child) in nv.listVal[0].fields:
        if name == "a": foundA1 = true; check child.intVal == 1
        if name == "b": foundB1 = true; check child.intVal == 2
      check foundA1 and foundB1

  test "Struct containing List":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT {'x': [1, 2, 3]} AS s"
    )
    for chunk in r:
      let nv = chunk.vector(0).toNimValue(0)
      check nv.kind == nvStruct
      check nv.fields.len == 1
      check nv.fields[0][0] == "x"
      check nv.fields[0][1].kind == nvList
      check nv.fields[0][1].listVal.len == 3
      check nv.fields[0][1].listVal[0].intVal == 1
      check nv.fields[0][1].listVal[2].intVal == 3

  test "Map of List":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT MAP(['k1', 'k2'], [[1, 2], [3, 4]])"
    )
    for chunk in r:
      let nv = chunk.vector(0).toNimValue(0)
      check nv.kind == nvMap
      check nv.mapVal.len == 2
      check nv.mapVal[0][0].strVal == "k1"
      check nv.mapVal[0][1].kind == nvList
      check nv.mapVal[0][1].listVal.len == 2
      check nv.mapVal[0][1].listVal[1].intVal == 2

suite "Complex — round-trip (normalized comparison)":
  test "List round-trip":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT [1, 2, 3] AS l, CAST([1, 2, 3] AS VARCHAR) AS l_str"
    )
    for chunk in r:
      let nvStr = normalize($chunk.vector(0).toNimValue(0))
      let dvStr = normalize(chunk.bindAs(1, DuckType.Varchar)[0])
      check nvStr == dvStr

  test "Struct round-trip":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT {'a': 100, 'b': 'hello'} AS s, CAST({'a': 100, 'b': 'hello'} AS VARCHAR) AS s_str"
    )
    for chunk in r:
      let nvStr = normalize($chunk.vector(0).toNimValue(0))
      let dvStr = normalize(chunk.bindAs(1, DuckType.Varchar)[0])
      check nvStr == dvStr

  test "Map round-trip":
    let conn = newDatabase().connect()
    let r = conn.execute(
      "SELECT MAP(['k1'], [42]) AS m, CAST(MAP(['k1'], [42]) AS VARCHAR) AS m_str"
    )
    for chunk in r:
      let nvStr = normalize($chunk.vector(0).toNimValue(0))
      let dvStr = normalize(chunk.bindAs(1, DuckType.Varchar)[0])
      check nvStr == dvStr

  test "Union round-trip":
    let conn = newDatabase().connect()
    let r = conn.execute(
      """SELECT union_value(num := 99) AS u,
                CAST(union_value(num := 99) AS VARCHAR) AS u_str"""
    )
    for chunk in r:
      let nvStr = normalize($chunk.vector(0).toNimValue(0))
      let dvStr = normalize(chunk.bindAs(1, DuckType.Varchar)[0])
      check nvStr == dvStr

  test "List of Struct round-trip":
    let conn = newDatabase().connect()
    let r = conn.execute(
      """SELECT [{'a': 1}, {'a': 2}] AS l,
                CAST([{'a': 1}, {'a': 2}] AS VARCHAR) AS l_str"""
    )
    for chunk in r:
      let nvStr = normalize($chunk.vector(0).toNimValue(0))
      let dvStr = normalize(chunk.bindAs(1, DuckType.Varchar)[0])
      check nvStr == dvStr

  test "Struct of List round-trip":
    let conn = newDatabase().connect()
    let r = conn.execute(
      """SELECT {'xs': [1, 2, 3]} AS s,
                CAST({'xs': [1, 2, 3]} AS VARCHAR) AS s_str"""
    )
    for chunk in r:
      let nvStr = normalize($chunk.vector(0).toNimValue(0))
      let dvStr = normalize(chunk.bindAs(1, DuckType.Varchar)[0])
      check nvStr == dvStr

suite "Complex — NimValue equality":
  test "int equality":
    let a = NimValue(kind: nvInt, intVal: 42)
    let b = NimValue(kind: nvInt, intVal: 42)
    let c = NimValue(kind: nvInt, intVal: 99)
    check a == b
    check a != c

  test "string equality":
    let a = NimValue(kind: nvString, strVal: "x")
    let b = NimValue(kind: nvString, strVal: "x")
    check a == b

  test "list equality":
    let a = NimValue(kind: nvList, listVal: @[
      NimValue(kind: nvInt, intVal: 1),
      NimValue(kind: nvInt, intVal: 2),
    ])
    let b = NimValue(kind: nvList, listVal: @[
      NimValue(kind: nvInt, intVal: 1),
      NimValue(kind: nvInt, intVal: 2),
    ])
    check a == b

suite "Complex — $ formatting":
  test "$ int":
    check $(NimValue(kind: nvInt, intVal: 42)) == "42"

  test "$ null":
    check $(NimValue(kind: nvNull)) == "NULL"

  test "$ string":
    check $(NimValue(kind: nvString, strVal: "hi")) == "'hi'"

  test "$ list of ints":
    let nv = NimValue(kind: nvList, listVal: @[
      NimValue(kind: nvInt, intVal: 1),
      NimValue(kind: nvInt, intVal: 2),
    ])
    check $nv == "[1, 2]"
