when not defined(features.nimdrake.arrow):
  {.error: "bench_arrow.nim requires -d:features.nimdrake.arrow".}

when defined(features.nimdrake.arrow):
  import criterion
  import narrow
  import ../src/[database, qresult, types, narrow_table_scan]
  import ./[config, tools]

  const
    OneWindowRows = 2_048
    MultiWindowRows = 8_193

  proc makeBatch(rows: int): RecordBatch =
    let schema = newSchema([newField[int64]("value")])
    var values = newSeq[int64](rows)
    for i in 0 ..< rows:
      values[i] = i.int64
    newRecordBatch(schema, newArray[int64](values))

  proc makeWideBatch(rows: int): RecordBatch =
    let schema = newSchema([
      newField[int64]("a"),
      newField[int64]("b"),
      newField[float64]("c"),
      newField[bool]("d"),
    ])
    var a = newSeq[int64](rows)
    var b = newSeq[int64](rows)
    var c = newSeq[float64](rows)
    var d = newSeq[bool](rows)
    for i in 0 ..< rows:
      a[i] = i.int64
      b[i] = (i * 2).int64
      c[i] = i.float64 * 0.5
      d[i] = (i and 1) == 0
    newRecordBatch(
      schema,
      newArray[int64](a),
      newArray[int64](b),
      newArray[float64](c),
      newArray[bool](d),
    )

  let
    oneWindowBatch = makeBatch(OneWindowRows)
    multiWindowBatch = makeBatch(MultiWindowRows)
    wideBatch = makeWideBatch(MultiWindowRows)
  let arrowDatabase = newDatabase()
  let arrowConnection = arrowDatabase.connect()

  proc checkIntegerResult(resultSet: QResult[Materialized], rows: int) =
    var count = 0
    var first = -1'i64
    var last = -1'i64
    var total = 0'i64
    for chunk in resultSet:
      let column = chunk.bindAs(0, DuckType.BigInt)
      count += column.len
      if column.len > 0:
        if first < 0:
          first = column[0]
        last = column[column.len - 1]
        for value in column:
          total += value
    doAssert count == rows and first == 0 and last == (rows - 1).int64
    doAssert total == (rows.int64 * (rows.int64 - 1)) div 2

  let prebuiltMultiWindow = newMaterialized(multiWindowBatch, arrowConnection)

  proc convertOneWindow() =
    let resultSet = newMaterialized(oneWindowBatch, arrowConnection)
    checkIntegerResult(resultSet, OneWindowRows)

  proc convertManyWindows() =
    let resultSet = newMaterialized(multiWindowBatch, arrowConnection)
    checkIntegerResult(resultSet, MultiWindowRows)

  proc convertManyWindowsWide() =
    let resultSet = newMaterialized(wideBatch, arrowConnection)
    var count = 0
    var first = -1'i64
    var last = -1'i64
    var sumA = 0'i64
    var sumB = 0'i64
    var sumC = 0.0
    var trueCount = 0
    for chunk in resultSet:
      let a = chunk.bindAs(0, DuckType.BigInt)
      let b = chunk.bindAs(1, DuckType.BigInt)
      let c = chunk.bindAs(2, DuckType.Double)
      let d = chunk.bindAs(3, DuckType.Boolean)
      count += a.len + b.len + c.len + d.len
      if a.len > 0:
        if first < 0:
          first = a[0]
        last = a[a.len - 1]
      for i in 0 ..< a.len:
        sumA += a[i]
        sumB += b[i]
        sumC += c[i]
        if d[i]: inc trueCount
    doAssert count == MultiWindowRows * 4 and first == 0 and last == (MultiWindowRows - 1).int64
    doAssert sumA == (MultiWindowRows.int64 * (MultiWindowRows.int64 - 1)) div 2
    doAssert sumB == sumA * 2
    doAssert sumC == sumA.float64 * 0.5
    doAssert trueCount == (MultiWindowRows + 1) div 2

  proc traversePrebuiltResult() =
    checkIntegerResult(prebuiltMultiWindow, MultiWindowRows)

  proc runProfile(options: ProfileOptions) =
    case options.caseName
    of "one_window": repeatProfile(options, convertOneWindow)
    of "many_windows": repeatProfile(options, convertManyWindows)
    of "many_windows_wide": repeatProfile(options, convertManyWindowsWide)
    of "traverse_prebuilt": repeatProfile(options, traversePrebuiltResult)
    else: raise newException(ValueError, "unknown Arrow profile case: " & options.caseName)

  let options = profileOptions()
  if profilingRequested(options):
    runProfile(options)
  else:
    let cfg = benchmarkConfig()
    benchmark cfg:
      proc benchmarkArrowOneWindow() {.measure.} = convertOneWindow()
      proc benchmarkArrowManyWindows() {.measure.} = convertManyWindows()
      proc benchmarkArrowManyWindowsWide() {.measure.} = convertManyWindowsWide()
      proc benchmarkArrowTraversePrebuilt() {.measure.} = traversePrebuiltResult()
