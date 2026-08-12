# Complex Types

Working with lists, structs, maps, and other nested types.

----

## Query list (array) values

Access list elements via `listChild` and `listEntry`:

```nim test
import nimdrake

let con = newDatabase().connect()
let r = con.execute("SELECT [10, 20, 30] AS nums")

for chunk in r:
  let listCol = chunk.vector(0).bindAs DuckType.List
  let child = listCol.listChild().bindAs DuckType.Integer
  let (offset, length) = listCol.listEntry(0)
  for j in int(offset) ..< int(offset + length):
    echo child[j]
```

```
10
20
30
```



## Query map values

Access map keys and values:

```nim test
import nimdrake

let con = newDatabase().connect()
let r = con.execute("""
  SELECT {'x': 1, 'y': 2}::MAP(VARCHAR, INTEGER) AS mp
""")

for chunk in r:
  let mapCol = chunk.vector(0).bindAs DuckType.Map
  echo "Key type: ", $mapCol.mapKeyType()
  echo "Value type: ", $mapCol.mapValueType()
```

```
Key type: Varchar
Value type: Integer
```



## Query struct values

Access struct fields by name:

```nim test
import nimdrake

let con = newDatabase().connect()
let r = con.execute("SELECT {'name': 'Alice', 'age': 30}::STRUCT(name VARCHAR, age INTEGER)")

for chunk in r:
  let s = chunk.vector(0).bindAs DuckType.Struct
  let nameChild = s.structChild("name").bindAs DuckType.Varchar
  let ageChild = s.structChild("age").bindAs DuckType.Integer
  echo nameChild[0], " is ", ageChild[0], " years old"
```

```
Alice is 30 years old
```



## Recursive materialization with NimValue

For ad-hoc queries where schema is unknown at compile time:

```nim test
import nimdrake

let con = newDatabase().connect()
let r = con.execute("SELECT [1, 2, 3] AS nums, {'k': 'v'}::MAP(VARCHAR, VARCHAR) AS mp")

let nv = r.scalar
echo "NimValue kind: ", nv.kind
```

```
NimValue kind: nvList
```



## Typed container views — bindAs sequelist, Table, OrderedTable

For hot paths where the column shape is known at compile time, pass the
expected Nim container type to `bindAs` and get a zero-copy typed view.
This builds on the descent procs above but caches the bound child vector(s)
once per column, so callers no longer chain `mapEntriesChild` /
`structChild(0)` / `structChild(1)` per call.

### List → `bindAs seq[T]`

```nim test
import nimdrake

let con = newDatabase().connect()
let r = con.execute("SELECT [10, 20, 30] AS nums")

for chunk in r:
  let lv = chunk.vector(0).bindAs seq[int32]
  echo lv[0]              # @[10, 20, 30]
  for x in lv.borrowList(0):  # zero-copy SliceView read
    echo x
```

```
@[10, 20, 30]
10
20
30
```


### Map → `bindAs Table[K,V]` / `bindAs OrderedTable[K,V]`

```nim test
import nimdrake
import std/tables

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
```

```
{"a": 10, "b": 20}
10
-1
a -> 10
b -> 20
```


### Array → `bindAsArray(kt)`

```nim test
import nimdrake

let con = newDatabase().connect()
let r = con.execute("SELECT ARRAY[1, 2, 3]::INT[3] AS arr")

for chunk in r:
  let av = chunk.vector(0).bindAsArray(DuckType.Integer)
  echo av.arraySize      # 3
  echo av[0]             # @[1, 2, 3]
  for x in av.borrowArray(0): echo x   # zero-copy SliceView
```

```
3
@[1, 2, 3]
1
2
3
```


### Struct — cached static-kind field overload

Structs have heterogeneous fields, so there's no `bindAs(Tuple[...])`
(see `Vector[DuckType.Struct].[]` below for an alternative). Use the
cached `structChild(name, kt)` overload to bind a single field's child
vector once:

```nim test
import nimdrake

let con = newDatabase().connect()
let r = con.execute(
  "SELECT {'name': 'Alice', 'age': 30}::STRUCT(name VARCHAR, age INTEGER) AS s"
)

for chunk in r:
  let s = chunk.vector(0).bindAs DuckType.Struct
  let nameChild = s.structChild("name", DuckType.Varchar)
  let ageChild = s.structChild("age", DuckType.Integer)
  echo nameChild[0], " is ", ageChild[0], " years old"
```

```
Alice is 30 years old
```


### Struct / Union element access via NimValue

For ad-hoc field access, `Vector[DuckType.Struct].[]` returns a
`seq[(string, NimValue)]` and `Vector[DuckType.Union].[]` returns
`(string, NimValue)`:

```nim test
import nimdrake

let con = newDatabase().connect()
let r = con.execute("SELECT {'a': 100, 'b': 'hello'} AS s")

for chunk in r:
  let s = chunk.vector(0).bindAs DuckType.Struct
  for (name, val) in s[0]:
    echo name, " = ", $val
```

```
a = 100
b = 'hello'
```



