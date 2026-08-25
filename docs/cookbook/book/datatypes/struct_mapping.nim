import nimib, nimibook
import ../cookbook_theme
import nimdrake
import std/options
import std/strutils

nbInit(theme = useCookbook)

proc stripBlockCode(code: string): string =
  let lines = code.splitLines()
  if lines.len == 0 or lines[0].strip != "block:":
    return code
  var outLines: seq[string]
  for i in 1 ..< lines.len:
    var line = lines[i]
    if line.startsWith("  "):
      line = line[2 .. ^1]
    outLines.add line
  outLines.join("\n")

nbText: """
## Struct Mapping

Map DuckDB rows and `STRUCT` values to Nim objects. The target object defines
the fields that the query must return.

```nim
import nimdrake
```
"""

nbText: """
## Decode rows into an object

Call `toSeq(T)` on a materialized or streaming result. Field names match
column names without regard to letter case. Extra columns do not affect the
mapping.
"""

nbCode:
  block:
    type User = object
      name: string
      age: int64

    let con = newDatabase().connect()
    let users = con.execute("""
      SELECT * FROM (VALUES ('Ada', 36::BIGINT), ('Linus', 55::BIGINT))
        AS t(name, age)
    """).toSeq(User)

    for user in users:
      echo user.name, " is ", user.age

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Map optional fields

Use `Option[T]` for a nullable column or for a field that the query can omit.
Required fields raise `ValueError` when the query does not provide them.
"""

nbCode:
  block:
    type User = object
      name: string
      age: Option[int64]
      nickname: Option[string]

    let con = newDatabase().connect()
    let users = con.execute("""
      SELECT 'Ada' AS name, NULL::BIGINT AS age
    """).toSeq(User)

    echo users[0].name, " has age: ", users[0].age.isSome
    echo "nickname present: ", users[0].nickname.isSome

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Decode nested `STRUCT` values

Nested Nim objects map to nested DuckDB `STRUCT` values. Match the nested
field names in the same way as top-level fields.
"""

nbCode:
  block:
    type Address = object
      city: string
      zip: int32
    type Customer = object
      name: string
      address: Address

    let con = newDatabase().connect()
    let customers = con.execute("""
      SELECT 'Ada' AS name,
        {'city': 'London', 'zip': 1000} AS address
    """).toSeq(Customer)

    echo customers[0].name, " lives in ", customers[0].address.city

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Iterate without materializing a sequence

Use `rows(T)` when the result can be large. The iterator decodes one row at a
time and plans each DuckDB chunk once.
"""

nbCode:
  block:
    type User = object
      name: string
      age: int64

    let con = newDatabase().connect()
    var total = 0'i64
    for user in con.execute("""
      SELECT * FROM (VALUES ('Ada', 36::BIGINT), ('Linus', 55::BIGINT))
        AS t(name, age)
    """).rows(User):
      total += user.age
    echo "total age: ", total

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Reuse a destination sequence

Call `toSeqInto` when a destination sequence already exists. The procedure
replaces its contents and avoids a separate result sequence allocation.
"""

nbCode:
  block:
    type User = object
      name: string
      age: int64

    let con = newDatabase().connect()
    var users = @[User(name: "old", age: 0)]
    let result = con.execute("SELECT 'Ada' AS name, 36::BIGINT AS age")
    result.toSeqInto(users)
    echo users[0].name, " is ", users[0].age

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbSave
