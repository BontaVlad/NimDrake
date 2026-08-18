import std/os
import criterion/config

proc benchmarkConfig*(): Config =
  result = newDefaultConfig()
  result.warmupBudget = 1.0
  result.budget = 2.0
  result.minSamples = 30
  result.resamples = 1000
  result.verbose = true
  let output = getEnv("NIMDRAKE_BENCH_OUTPUT", "")
  if output.len > 0:
    result.outputPath = output

proc smokeConfig*(): Config =
  result = benchmarkConfig()
  result.warmupBudget = 0.05
  result.budget = 0.1
  result.minSamples = 3
  result.resamples = 100
