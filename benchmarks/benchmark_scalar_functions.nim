import criterion
import ../src/nimdrake

var cfg = newDefaultConfig()
cfg.warmupBudget = 0.5
cfg.budget = 0.1
cfg.minSamples = 3
cfg.verbose = true

benchmark cfg:

  proc benchmarkScalar() {.measure.} =
    let conn = newDatabase().connect()

    template doubleValue(val, bar: int64): int64 {.scalar.} =
      return val * bar

    conn.register(doubleValue)

    conn.execute("CREATE TABLE test_table AS SELECT i FROM range(10) t(i);")
    let outcome =
      conn.execute("SELECT i, doubleValue(i, i) as doubled FROM test_table").fetchAll()
