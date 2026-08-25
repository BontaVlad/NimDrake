import nimib, nimibook
import ../cookbook_theme
import nimdrake
import std/strutils

nbInit(theme = useCookbook)

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
## User-Defined Functions

Register Nim procs as DuckDB scalar, aggregate, and table functions.

```nim
import nimdrake
```
"""

nbText: """
## Scalar functions

Write a normal Nim proc and register it:
"""

nbCode:
  block:
    proc multiply(a, b: int64): int64 = a * b

    let con = newDatabase().connect()
    con.registerScalar(multiply)

    let r = con.execute("SELECT multiply(3::BIGINT, 7::BIGINT)")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Scalar function with string processing
"""

nbCode:
  block:
    proc shout(s: string): string = s.toUpperAscii() & "!"

    let con = newDatabase().connect()
    con.registerScalar(shout)

    let r = con.execute("SELECT shout('hello world'::VARCHAR)")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## NULL propagation

NULL inputs automatically produce NULL output — no extra code needed:
"""

nbCode:
  block:
    proc add(a, b: int64): int64 = a + b

    let con = newDatabase().connect()
    con.registerScalar(add)

    let r = con.execute("SELECT add(NULL::BIGINT, 42::BIGINT)")
    for chunk in r:
      let v = chunk.vector(0).bindAs DuckType.BigInt
      echo "Is NULL? ", not v.valid(0)

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Table functions

Register a `{.closure.}` iterator as a table function:
"""

nbCode:
  block:
    iterator fibonacci(n: int): tuple[i: int, fib: int] {.closure.} =
      var a = 0
      var b = 1
      for idx in 0 ..< n:
        yield (idx, a)
        let next = a + b
        a = b
        b = next

    let con = newDatabase().connect()
    con.registerTableFunction(fibonacci)

    let r = con.execute("SELECT * FROM fibonacci(8)")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Table function with multiple parameters
"""

nbCode:
  block:
    iterator rangeStep(start, stop, step: int): int {.closure.} =
      var i = start
      while i < stop:
        yield i
        i += step

    let con = newDatabase().connect()
    con.registerTableFunction(rangeStep)

    let r = con.execute("SELECT * FROM rangeStep(0, 20, 5)")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Aggregate functions

Register init/update/combine/finalize procs:
"""

nbCode:
  block:
    type SumState = object
      total: int64

    proc sumInit(s: var SumState) = s.total = 0
    proc sumUpdate(s: var SumState, val: int64) = s.total += val
    proc sumCombine(dest: var SumState, src: SumState) = dest.total += src.total
    proc sumFinalize(s: SumState): int64 = s.total

    let con = newDatabase().connect()
    con.registerAggregate("my_sum", sumInit, sumUpdate, sumCombine, sumFinalize)

    let r = con.execute("SELECT my_sum(i) FROM generate_series(1, 100) AS t(i)")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Aggregate with GROUP BY
"""

nbCode:
  block:
    type SumState = object
      total: int64

    proc sumInit(s: var SumState) = s.total = 0
    proc sumUpdate(s: var SumState, val: int64) = s.total += val
    proc sumCombine(dest: var SumState, src: SumState) = dest.total += src.total
    proc sumFinalize(s: SumState): int64 = s.total

    let con = newDatabase().connect()
    con.registerAggregate("my_sum", sumInit, sumUpdate, sumCombine, sumFinalize)

    let r = con.execute("""
      SELECT (i % 3)::INTEGER AS group_id, my_sum(i)::BIGINT AS total
      FROM generate_series(0, 8) AS t(i)
      GROUP BY group_id
      ORDER BY group_id
    """)
    echo r
nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Mixed parameter types

Parameters and return values can mix — the macro maps Nim types to DuckDB
types from the proc signature:
"""

nbCode:
  block:
    proc repeatStr(s: string, n: int64): string =
      s.repeat(n.int)

    let con = newDatabase().connect()
    con.registerScalar(repeatStr)

    let r = con.execute("SELECT repeatStr('ab'::VARCHAR, 3::BIGINT)")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Aggregate with a multi-field state

State can hold anything — here an average needs both a running total and a
count:
"""

nbCode:
  block:
    type AvgState = object
      total: int64
      count: int64

    proc avgInit(s: var AvgState) =
      s.total = 0
      s.count = 0

    proc avgUpdate(s: var AvgState, val: int64) =
      s.total += val
      s.count += 1

    proc avgCombine(dest: var AvgState, src: AvgState) =
      dest.total += src.total
      dest.count += src.count

    proc avgFinalize(s: AvgState): float64 =
      if s.count == 0: 0.0 else: s.total.float64 / s.count.float64

    let con = newDatabase().connect()
    con.registerAggregate("my_avg", avgInit, avgUpdate, avgCombine, avgFinalize)

    let r = con.execute("SELECT my_avg(i) FROM generate_series(1, 10) AS t(i)")
    echo r

nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbText: """
## Table function with string parameters

String parameters work too — useful for generators over text sources:
"""

nbCode:
  block:
    iterator suffix(count: int, tag: string): string {.closure.} =
      for i in 0 ..< count:
        yield tag & "_" & $i

    let con = newDatabase().connect()
    con.registerTableFunction(suffix)

    let r = con.execute("SELECT * FROM suffix(3, 'evt')")
    echo r
nb.blk.NbCode.code = stripBlockCode(nb.blk.NbCode.code)
nbSave