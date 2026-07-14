## Benchmark: zero-copy QResult traversal vs legacy fetchAll.
##
## Run with: `just benchmark qresult`
##
## Goal: prove the new QResult/Vector[kt] API reads a 100M-row integer column
## with zero per-row allocations, vs the legacy materialized Vector's
## full-seq-copy path.

import criterion

import ../src/nimdrake

var cfg = newDefaultConfig()
cfg.warmupBudget = 0.5
cfg.budget = 0.1
cfg.minSamples = 20
cfg.verbose = true

let conn = newDatabase().connect()

benchmark cfg:

  proc benchmarkQResultIntScan() {.measure.} =
    ## Zero-copy: walk chunks, read every int64 directly off the buffer.
    let r = conn.execute("SELECT * FROM range(100000000)")
    var sum: int64 = 0
    for c in r.chunks:
      let v = r.vector(c, 0).bindAs DuckType.BigInt
      for i in 0 ..< v.len:
        sum += v[i]
    doAssert sum == 4999999950000000'i64

  proc benchmarkQResultCopyViaToSeq() {.measure.} =
    ## Bulk-copy variant of the same scan — allocates one seq[int64] per chunk
    ## then sums. For comparison with the zero-copy path above.
    let r = conn.execute("SELECT * FROM range(100000000)")
    var sum: int64 = 0
    for c in r.chunks:
      let v = r.vector(c, 0).bindAs DuckType.BigInt
      let s = v.toSeq
      for x in s:
        sum += x
    doAssert sum == 4999999950000000'i64