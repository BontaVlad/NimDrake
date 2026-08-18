when not defined(features.nimdrake.arrow):
  {.error: "bench_arrow.nim requires -d:features.nimdrake.arrow".}

when defined(features.nimdrake.arrow):
  import criterion
  import narrow
  import ../src/[database, query, qresult, types, narrow_table_scan]
  import ./[config, tools]

  const Rows = 5_000

  let schema = newSchema([newField[int64]("value")])
  let values = newSeq[int64](Rows)
  for i in 0 ..< Rows:
    values[i] = i.int64
  let batch = newRecordBatch(schema, newArray[int64](values))
  let arrowDatabase = newDatabase()
  let arrowConnection = arrowDatabase.connect()

  proc convertWindowedBatch() =
    let resultSet = newMaterialized(batch, arrowConnection)
    var count = 0
    var total = 0'i64
    for chunk in resultSet:
      let column = chunk.bindAs(0, DuckType.BigInt)
      count += column.len
      if column.len > 0:
        total += column[0]
    doAssert count == Rows and total == 0

  proc runProfile(options: ProfileOptions) =
    case options.caseName
    of "record_batch": repeatProfile(options, convertWindowedBatch)
    else: raise newException(ValueError, "unknown Arrow profile case: " & options.caseName)

  let options = profileOptions()
  if profilingRequested(options):
    runProfile(options)
  else:
    let cfg = benchmarkConfig()
    benchmark cfg:
      proc benchmarkRecordBatchWindows() {.measure.} = convertWindowedBatch()
