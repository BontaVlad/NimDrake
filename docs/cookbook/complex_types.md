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


