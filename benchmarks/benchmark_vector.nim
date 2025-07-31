import criterion
import ../src/nimdrake

var cfg = newDefaultConfig()
cfg.warmupBudget = 0.5
cfg.budget = 0.1
cfg.minSamples = 20
cfg.verbose = true


let conn = newDatabase().connect()

let outcome = conn.execute("SELECT * from range(100000000)").fetchAll()
let myArray = outcome[0].valueBigInt

benchmark cfg:

  proc benchmarkVector() {.measure.} =

    let myVector = newVector(myArray)
    assert myVector.valueBigint[0] == 0
