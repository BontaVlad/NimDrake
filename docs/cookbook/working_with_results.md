# Working with Results

Accessing query results with zero-copy typed vectors.

----

## Access columns by index

`chunk.vector(i)` returns a zero-copy view. Use `bindAs` to type it:

```nim test
import nimdrake

let con = newDatabase().connect()
let r = con.execute("SELECT 42::BIGINT AS num, 'hello'::VARCHAR AS msg")

for chunk in r:
  let nums = chunk.vector(0).bindAs DuckType.BigInt
  let msgs = chunk.vector(1).bindAs DuckType.Varchar
  echo nums[0], " ", msgs[0]
```

```
42 hello
```

## Access columns by name

Use `chunk["name"]` for named access:

```nim test
import nimdrake

let con = newDatabase().connect()
let r = con.execute("SELECT 1::INTEGER AS x, 2::INTEGER AS y")

for chunk in r:
  let x = chunk["x"].bindAs DuckType.Integer
  let y = chunk["y"].bindAs DuckType.Integer
  echo x[0] + y[0]
```

```
3
```

## Collect all values into a seq

`toSeq` materializes a column into a Nim sequence:

```nim test
import nimdrake
import std/sequtils

let con = newDatabase().connect()
let r = con.execute("SELECT i FROM generate_series(1, 5) AS t(i)")

for chunk in r:
  let vals = chunk.vector(0).bindAs(DuckType.BigInt).toSeq
  echo vals
```

```
@[1, 2, 3, 4, 5]
```

## Check for NULL values

Use `valid(i)` to check if a value is NULL:

```nim test
import nimdrake

let con = newDatabase().connect()
let r = con.execute("SELECT NULL::BIGINT AS val, 42::BIGINT AS val2")

for chunk in r:
  let v = chunk.vector(0).bindAs DuckType.BigInt
  echo "NULL? ", not v.valid(0)  # true
  echo "NULL? ", not v.valid(1)  # false
```

```
NULL? true
NULL? false
```

## Cross-chunk random access with Table API

For random access across all chunks, use the `Table` API:

```nim test
import nimdrake

let con = newDatabase().connect()
let r = con.execute("SELECT i FROM generate_series(1, 5000) AS t(i)")
let tbl = initTable(r)

let col = tbl.bindAs(0, DuckType.BigInt)
echo col[0]     # first row
echo col[4999]  # last row
```

```
1
5000
```

