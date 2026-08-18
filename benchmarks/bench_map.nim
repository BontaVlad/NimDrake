import criterion
import std/tables
import ../src/nimdrake
import ./[config, tools]

const Rows = 5_000
const MapSql = "SELECT MAP {'key_a': 'value_a', 'key_b': 'value_b', 'key_c': 'value_c'} FROM range(" & $Rows & ")"

proc owningLookup() =
  let conn = newDatabase().connect()
  let resultSet = conn.execute(MapSql)
  var found = 0
  for chunk in resultSet:
    let maps = chunk.bindAs(0, OrderedTable[string, string])
    for i in 0 ..< maps.len:
      if maps[i]["key_c"] == "value_c":
        inc found
  doAssert found == Rows

proc borrowedLookup() =
  let conn = newDatabase().connect()
  let resultSet = conn.execute(MapSql)
  var found = 0
  for chunk in resultSet:
    let maps = chunk.bindAs(0, OrderedTable[string, string])
    let first = maps.borrowMap(0)
    var queryKey, queryValue: DuckStringRef
    var position = 0
    for key, value in first.borrowPairs:
      if position == 2:
        queryKey = key
        queryValue = value
      inc position
    for i in 0 ..< maps.len:
      let (value, present) = maps.borrowMap(i).borrowLookup(queryKey)
      if present and value == queryValue:
        inc found
  doAssert found == Rows

proc borrowedIteration() =
  let conn = newDatabase().connect()
  let resultSet = conn.execute(MapSql)
  var total = 0
  for chunk in resultSet:
    let maps = chunk.bindAs(0, OrderedTable[string, string])
    for i in 0 ..< maps.len:
      for key in maps.borrowMap(i).borrowKeys:
        total += key.len
  doAssert total == Rows * (5 + 5 + 5)

proc runProfile(options: ProfileOptions) =
  case options.caseName
  of "owning_lookup": repeatProfile(options, owningLookup)
  of "borrowed_lookup": repeatProfile(options, borrowedLookup)
  of "borrowed_iteration": repeatProfile(options, borrowedIteration)
  else: raise newException(ValueError, "unknown map profile case: " & options.caseName)

let options = profileOptions()
if profilingRequested(options):
  runProfile(options)
else:
  let cfg = benchmarkConfig()
  benchmark cfg:
    proc benchmarkOwningLookup() {.measure.} = owningLookup()
    proc benchmarkBorrowedLookup() {.measure.} = borrowedLookup()
    proc benchmarkBorrowedIteration() {.measure.} = borrowedIteration()
