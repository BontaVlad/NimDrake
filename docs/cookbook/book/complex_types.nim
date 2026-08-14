import nimib, nimibook
import nimdrake
import std/tables
import std/strutils
nbInit(theme = useNimibook)

proc stripBlockCode(code: string): string =
  let lines = code.splitLines()
  if lines.len == 0 or lines[0].strip != "block:":
    return code
  var outLines: seq[string]
  for i in 1 ..< lines.len:
    var l = lines[i]
    if l.startsWith("  "):
      l = l[2 .. ^1]
    outLines.add l
  outLines.join("\n")

nbText: """
## Complex Types

Working with lists, structs, maps, and other nested types.

```nim
import nimdrake
```
"""

nbText: """
## Query list (array) values

Access list elements via `listChild` and `listEntry`:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute("SELECT [10, 20, 30] AS nums")

    for chunk in r:
      let listCol = chunk.vector(0).bindAs DuckType.List
      let child = listCol.listChild().bindAs DuckType.Integer
      let (offset, length) = listCol.listEntry(0)
      for j in int(offset) ..< int(offset + length):
        echo child[j]

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Query map values

Access map keys and values:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute("""
      SELECT {'x': 1, 'y': 2}::MAP(VARCHAR, INTEGER) AS mp
    """)

    for chunk in r:
      let mapCol = chunk.vector(0).bindAs DuckType.Map
      echo "Key type: ", $mapCol.mapKeyType()
      echo "Value type: ", $mapCol.mapValueType()

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Query struct values

Access struct fields by name:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute("SELECT {'name': 'Alice', 'age': 30}::STRUCT(name VARCHAR, age INTEGER)")

    for chunk in r:
      let s = chunk.vector(0).bindAs DuckType.Struct
      let nameChild = s.structChild("name").bindAs DuckType.Varchar
      let ageChild = s.structChild("age").bindAs DuckType.Integer
      echo nameChild[0], " is ", ageChild[0], " years old"

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Recursive materialization with NimValue

For ad-hoc queries where schema is unknown at compile time:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute("SELECT [1, 2, 3] AS nums, {'k': 'v'}::MAP(VARCHAR, VARCHAR) AS mp")

    let nv = r.scalar
    echo "NimValue kind: ", nv.kind

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Typed container views — bindAs sequelist, Table, OrderedTable

For hot paths where the column shape is known at compile time, pass the
expected Nim container type to `bindAs` and get a zero-copy typed view.
This builds on the descent procs above but caches the bound child vector(s)
once per column, so callers no longer chain `mapEntriesChild` /
`structChild(0)` / `structChild(1)` per call.
"""

nbText: """
### List → `bindAs seq[T]`
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute("SELECT [10, 20, 30] AS nums")

    for chunk in r:
      let lv = chunk.vector(0).bindAs seq[int32]
      echo lv[0]              # @[10, 20, 30]
      for x in lv.borrowList(0):  # zero-copy SliceView read
        echo x

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
### Map → `bindAs Table[K,V]` / `bindAs OrderedTable[K,V]`
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute("SELECT MAP(['a','b'], [10, 20]) AS mp")

    for chunk in r:
      let mv = chunk.vector(0).bindAs OrderedTable[string, int32]
      echo mv[0]             # {"a": 10, "b": 20}  (allocating OrderedTable)
      let row = mv.borrowMap(0)  # zero-copy MapRowView
      echo row["a"]          # 10
      echo row.getOrDefault("z", -1)   # -1
      for k, v in row.pairs:
        echo k, " -> ", v

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
### Array → `bindAsArray(kt)`
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute("SELECT ARRAY[1, 2, 3]::INT[3] AS arr")

    for chunk in r:
      let av = chunk.vector(0).bindAsArray(DuckType.Integer)
      echo av.arraySize      # 3
      echo av[0]             # @[1, 2, 3]
      for x in av.borrowArray(0): echo x   # zero-copy SliceView

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
### Struct — cached static-kind field overload

Structs have heterogeneous fields, so there's no `bindAs(Tuple[...])`
(see `Vector[DuckType.Struct].[]` below for an alternative). Use the
cached `structChild(name, kt)` overload to bind a single field's child
vector once:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute(
      "SELECT {'name': 'Alice', 'age': 30}::STRUCT(name VARCHAR, age INTEGER) AS s"
    )

    for chunk in r:
      let s = chunk.vector(0).bindAs DuckType.Struct
      let nameChild = s.structChild("name", DuckType.Varchar)
      let ageChild = s.structChild("age", DuckType.Integer)
      echo nameChild[0], " is ", ageChild[0], " years old"

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
### Struct / Union element access via NimValue

For ad-hoc field access, `Vector[DuckType.Struct].[]` returns a
`seq[(string, NimValue)]` and `Vector[DuckType.Union].[]` returns
`(string, NimValue)`:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute("SELECT {'a': 100, 'b': 'hello'} AS s")

    for chunk in r:
      let s = chunk.vector(0).bindAs DuckType.Struct
      for (name, val) in s[0]:
        echo name, " = ", $val
nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
### Union values

A union holds exactly one member — `toUnion` gives the tag name and value:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute("SELECT union_value(num := 99)")

    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.Union
      for (name, val) in toUnion(v):
        echo name, " = ", $val

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Nested structures with toNimValue

`toNimValue(cv, i)` recursively materializes arbitrarily nested values —
lists of structs, structs containing lists, maps of lists:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute("SELECT [{'a': 1, 'b': 2}, {'a': 3, 'b': 4}]")

    for chunk in r:
      let nv = chunk.vector(0).toNimValue(0)
      echo "kind: ", nv.kind
      for (name, child) in nv.listVal[0].fields:
        echo name, " = ", $child

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Convenience materializers: toList and toMap

`toList[kt]` and `toMap[K, V]` materialize whole columns of lists or maps
into Nim `seq`s:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    let r = con.execute("""
      SELECT [seq, seq + 1, seq + 2] FROM generate_series(1, 3) AS t(seq)
    """)

    for chunk in r:
      let lst = toList[DuckType.BigInt](chunk.bindAs(0, DuckType.List))
      echo lst

  block:
    let con = newDatabase().connect()
    let r = con.execute("SELECT MAP(['a', 'b'], [10, 20])")

    for chunk in r:
      let mp = toMap[DuckType.Varchar, DuckType.Integer](chunk.bindAs(0, DuckType.Map))
      echo mp
nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbSave