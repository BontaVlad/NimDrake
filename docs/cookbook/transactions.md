# Transactions

ACID transactions with auto-commit and rollback.

----

## Basic transaction

Use the `transaction` template for auto-commit on success:

```nim test
import nimdrake

let con = newDatabase().connect()
con.execute("CREATE TABLE accounts (id INTEGER, balance INTEGER)")
con.execute("INSERT INTO accounts VALUES (1, 1000), (2, 500)")

con.transaction:
  con.execute("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
  con.execute("UPDATE accounts SET balance = balance + 100 WHERE id = 2")

let r = con.execute("SELECT * FROM accounts ORDER BY id")
echo r
```

```
┌────────────┬─────────────────┐
│     id     │     balance     │
├────────────┼─────────────────┤
│     1      │     900         │
│     2      │     600         │
└────────────┴─────────────────┘
```

## Rollback on exception

If an exception occurs, changes are automatically rolled back:

```nim test
import nimdrake

let con = newDatabase().connect()
con.execute("CREATE TABLE items (id INTEGER, name VARCHAR)")
con.execute("INSERT INTO items VALUES (1, 'existing')")

try:
  con.transaction:
    con.execute("INSERT INTO items VALUES (2, 'new')")
    raise newException(ValueError, "something went wrong")
except ValueError:
  discard

let r = con.execute("SELECT count(*)::BIGINT AS n FROM items")
echo r
```

```
┌───────────┐
│     n     │
├───────────┤
│     1     │
└───────────┘
```

## Nested transactions

```nim test
import nimdrake

let con = newDatabase().connect()
con.execute("CREATE TABLE counter (val INTEGER)")
con.execute("INSERT INTO counter VALUES (0)")

con.transaction:
  con.execute("UPDATE counter SET val = val + 1")
  con.transaction:
    con.execute("UPDATE counter SET val = val + 10")

let r = con.execute("SELECT val FROM counter")
echo r
```
