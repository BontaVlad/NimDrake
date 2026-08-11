# Prepared Statements

Type-safe parameter binding for repeated queries.

----

## Basic parameter binding

Use `?` as placeholders and pass a tuple of values:

```nim test
import nimdrake

let con = newDatabase().connect()
con.execute("CREATE TABLE people (id BIGINT, name VARCHAR, active BOOLEAN)")

let stmt = con.newStatement("INSERT INTO people VALUES (?, ?, ?)")
con.executeMaterialized(stmt, (int64(1), "Alice", true))
con.executeMaterialized(stmt, (int64(2), "Bob", false))

let r = con.execute("SELECT * FROM people ORDER BY id")
echo r
```

```
┌────────────┬───────────────┬────────────────┐
│     id     │     name      │     active     │
├────────────┼───────────────┼────────────────┤
│     1      │     Alice     │     true       │
│     2      │     Bob       │     false      │
└────────────┴───────────────┴────────────────┘
```

## Named parameters

Use `$name` syntax for named parameters:

```nim test
import nimdrake

let con = newDatabase().connect()
let stmt = con.newStatement("SELECT CAST($val AS BIGINT) AS result")

let idx = stmt.bindParameter("val")
echo "Parameter index: ", idx
```

```
Parameter index: 1
```

## Inspect parameter types

Query the `parameters` field to see what DuckDB expects:

```nim test
import nimdrake

let con = newDatabase().connect()
con.execute("CREATE TABLE t (a INTEGER, b VARCHAR, c BOOLEAN)")
let stmt = con.newStatement("INSERT INTO t VALUES (?, ?, ?)")

for param in stmt.parameters:
  echo param.name, " -> ", param.tpy
```

```
1 -> Integer
2 -> Varchar
3 -> Boolean
```

## DML statements use executeMaterialized

`INSERT`, `UPDATE`, `DELETE` don't produce streaming results:

```nim test
import nimdrake

let con = newDatabase().connect()
con.execute("CREATE TABLE counters (id INTEGER, val INTEGER)")
con.executeMaterialized("INSERT INTO counters VALUES (1, 100)", ())
con.executeMaterialized("UPDATE counters SET val = 200 WHERE id = 1", ())
con.executeMaterialized("DELETE FROM counters WHERE id = 1", ())

let r = con.execute("SELECT count(*)::BIGINT AS n FROM counters")
echo r
```

```
┌───────────┐
│     n     │
├───────────┤
│     0     │
└───────────┘
```

