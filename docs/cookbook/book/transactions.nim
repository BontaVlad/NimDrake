import nimib, nimibook
import nimdrake
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
## Transactions

ACID transactions with auto-commit and rollback.

```nim
import nimdrake
```
"""

nbText: """
## Basic transaction

Use the `transaction` template for auto-commit on success:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE accounts (id INTEGER, balance INTEGER)")
    con.execute("INSERT INTO accounts VALUES (1, 1000), (2, 500)")

    con.transaction:
      con.execute("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
      con.execute("UPDATE accounts SET balance = balance + 100 WHERE id = 2")

    let r = con.execute("SELECT * FROM accounts ORDER BY id")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Rollback on exception

If an exception occurs, changes are automatically rolled back:
"""

nbCode:
  block:
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

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Transaction with readback

Changes inside a transaction are visible to subsequent queries on the same
connection before commit:
"""

nbCode:
  block:
    let con = newDatabase().connect()
    con.execute("CREATE TABLE counter (val INTEGER)")
    con.execute("INSERT INTO counter VALUES (0)")

    con.transaction:
      con.execute("UPDATE counter SET val = val + 10")
      let r = con.execute("SELECT val FROM counter")
      echo "inside: ", r.scalar

    let r2 = con.execute("SELECT val FROM counter")
    echo "after commit: ", r2.scalar
nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbSave