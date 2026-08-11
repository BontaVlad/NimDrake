# Query Execution

Running SQL queries, streaming results, and handling errors.

----

## Execute a simple query

`execute` runs SQL and returns a `QResult`. Print it for a formatted table:

```nim test
import nimdrake

let con = newDatabase().connect()
let r = con.execute("""
  SELECT i, i * i AS sq
  FROM generate_series(1, 5) AS t(i)
""")
echo r
```

```
┌───────────┬────────────┐
│     i     │     sq     │
├───────────┼────────────┤
│     1     │     1      │
│     2     │     4      │
│     3     │     9      │
│     4     │     16     │
│     5     │     25     │
└───────────┴────────────┘
```

## Stream results chunk by chunk

For large result sets, iterate chunks to avoid loading everything into memory:

```nim test
import nimdrake

let con = newDatabase().connect()
let stmt = con.newStatement(
  "SELECT i FROM generate_series(1, 1_000_000) AS t(i)"
)
var count = 0
for chunk in con.execute(stmt):
  let v = chunk.vector(0).bindAs DuckType.BigInt
  count += v.len
echo "Total rows: ", count
```

```
Total rows: 1000000
```

## Use prepared statements for repeated queries

Prepare once, execute many times with different parameters:

```nim test
import nimdrake

let con = newDatabase().connect()
con.execute("CREATE TABLE items (id INTEGER, name VARCHAR)")

let stmt = con.newStatement("INSERT INTO items VALUES (?, ?)")
con.executeMaterialized(stmt, (1, "apple"))
con.executeMaterialized(stmt, (2, "banana"))
con.executeMaterialized(stmt, (3, "cherry"))

let r = con.execute("SELECT * FROM items ORDER BY id")
echo r
```

```
┌────────────┬────────────────┐
│     id     │     name       │
├────────────┼────────────────┤
│     1      │     apple      │
│     2      │     banana     │
│     3      │     cherry     │
└────────────┴────────────────┘
```

## Query CSV and Parquet files directly

DuckDB can query files without importing them:

```nim test
import nimdrake
import std/[os, strutils]

let con = newDatabase().connect()

# Create a sample CSV
let csvPath = getTempDir() / "sample.csv"
writeFile(csvPath, "id,name\n1,alice\n2,bob\n")

let r = con.execute("SELECT * FROM read_csv_auto('" & csvPath & "')")
echo r
```

```
┌────────────┬───────────────┐
│     id     │     name      │
├────────────┼───────────────┤
│     1      │     alice     │
│     2      │     bob       │
└────────────┴───────────────┘
```

## Handle errors gracefully

Invalid SQL raises `OperationError`:

```nim test
import nimdrake

let con = newDatabase().connect()
try:
  con.execute("THIS IS NOT VALID SQL")
except OperationError as e:
  echo "Caught error: ", e.msg
```
