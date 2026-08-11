# Bulk Insert with Appender

High-throughput data loading with the Appender API.

----

## Basic appender usage

The Appender is the fastest way to insert large volumes of data:

```nim test
import nimdrake

let con = newDatabase().connect()
con.execute("CREATE TABLE logs (ts VARCHAR, level VARCHAR, msg VARCHAR)")

var appender = con.newAppender("logs")
for i in 0 ..< 100:
  appender.append("2024-01-01 00:00:00")
  appender.append("INFO")
  appender.append("Event " & $i)
  appender.endRow()
appender.close()

let r = con.execute("SELECT count(*)::BIGINT AS n FROM logs")
echo r
```

```
┌─────────────┐
│     n       │
├─────────────┤
│     100     │
└─────────────┘
```

## Appender with typed columns

Match the column types in your table:

```nim test
import nimdrake

let con = newDatabase().connect()
con.execute("""
  CREATE TABLE metrics (
    id BIGINT,
    value DOUBLE,
    label VARCHAR,
    active BOOLEAN
  )
""")

var appender = con.newAppender("metrics")
for i in 1 .. 5:
  appender.append(int64(i))
  appender.append(i.float64 * 1.5)
  appender.append("metric_" & $i)
  appender.append(i mod 2 == 0)
  appender.endRow()
appender.close()

let r = con.execute("SELECT * FROM metrics ORDER BY id")
echo r
```

```
┌────────────┬───────────────┬──────────────────┬────────────────┐
│     id     │     value     │     label        │     active     │
├────────────┼───────────────┼──────────────────┼────────────────┤
│     1      │     1.5       │     metric_1     │     false      │
│     2      │     3.0       │     metric_2     │     true       │
│     3      │     4.5       │     metric_3     │     false      │
│     4      │     6.0       │     metric_4     │     true       │
│     5      │     7.5       │     metric_5     │     false      │
└────────────┴───────────────┴──────────────────┴────────────────┘
```

## Appender from a sequence of tuples

Bulk insert from existing data:

```nim test
import nimdrake

let con = newDatabase().connect()
con.execute("CREATE TABLE pairs (a INTEGER, b VARCHAR)")

let data = @[
  @["1", "one"],
  @["2", "two"],
  @["3", "three"],
]
con.newAppender("pairs", data)

let r = con.execute("SELECT * FROM pairs ORDER BY a")
echo r
```

```
┌───────────┬───────────────┐
│     a     │     b         │
├───────────┼───────────────┤
│     1     │     one       │
│     2     │     two       │
│     3     │     three     │
└───────────┴───────────────┘
```

