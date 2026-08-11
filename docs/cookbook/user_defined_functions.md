# User-Defined Functions

Register Nim procs as DuckDB scalar, aggregate, and table functions.

----

## Scalar functions

Write a normal Nim proc and register it:

```nim test
import nimdrake

proc multiply(a, b: int64): int64 = a * b

let con = newDatabase().connect()
con.registerScalar(multiply)

let r = con.execute("SELECT multiply(3::BIGINT, 7::BIGINT)")
echo r
```

```
┌──────────────────────────────────┐
│     multiply(CAST(3 AS BI...     │
├──────────────────────────────────┤
│     21                           │
└──────────────────────────────────┘
```


## Scalar function with string processing

```nim test
import nimdrake
import std/strutils

proc shout(s: string): string = s.toUpperAscii() & "!"

let con = newDatabase().connect()
con.registerScalar(shout)

let r = con.execute("SELECT shout('hello world'::VARCHAR)")
echo r
```

```
┌──────────────────────────────────┐
│     shout(CAST('hello wor...     │
├──────────────────────────────────┤
│     HELLO WORLD!                 │
└──────────────────────────────────┘
```


## NULL propagation

NULL inputs automatically produce NULL output — no extra code needed:

```nim test
import nimdrake

proc add(a, b: int64): int64 = a + b

let con = newDatabase().connect()
con.registerScalar(add)

let r = con.execute("SELECT add(NULL::BIGINT, 42::BIGINT)")
for chunk in r:
  let v = chunk.vector(0).bindAs DuckType.BigInt
  echo "Is NULL? ", not v.valid(0)
```

```
Is NULL? true
```


## Table functions

Register a `{.closure.}` iterator as a table function:

```nim test
import nimdrake

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
```

```
┌───────────┬─────────────┐
│     i     │     fib     │
├───────────┼─────────────┤
│     0     │     0       │
│     1     │     1       │
│     2     │     1       │
│     3     │     2       │
│     4     │     3       │
│     5     │     5       │
│     6     │     8       │
│     7     │     13      │
└───────────┴─────────────┘
```


## Table function with multiple parameters

```nim test
import nimdrake

iterator rangeStep(start, stop, step: int): int {.closure.} =
  var i = start
  while i < stop:
    yield i
    i += step

let con = newDatabase().connect()
con.registerTableFunction(rangeStep)

let r = con.execute("SELECT * FROM rangeStep(0, 20, 5)")
echo r
```

```
┌───────────────────┐
│     rangeStep     │
├───────────────────┤
│     0             │
│     5             │
│     10            │
│     15            │
└───────────────────┘
```


## Aggregate functions

Register init/update/combine/finalize procs:

```nim test
import nimdrake
import std/options

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
```

```
┌───────────────────┐
│     my_sum(i)     │
├───────────────────┤
│     5050          │
└───────────────────┘
```


## Aggregate with GROUP BY

```nim test
import nimdrake
import std/options

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
```

```
┌──────────────────┬───────────────┐
│     group_id     │     total     │
├──────────────────┼───────────────┤
│     0            │     9         │
│     1            │     12        │
│     2            │     15        │
└──────────────────┴───────────────┘
```


