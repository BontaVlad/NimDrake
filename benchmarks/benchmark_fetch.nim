import criterion
import ../src/nimdrake

var cfg = newDefaultConfig()
cfg.warmupBudget = 0.5
cfg.budget = 0.1
cfg.minSamples = 10
cfg.verbose = true

benchmark cfg:

  proc benchmarkFetchAll() {.measure.} =
    let conn = newDatabase().connect()

    let outcome = conn.execute("SELECT * from range(1000000)").fetchAll()
