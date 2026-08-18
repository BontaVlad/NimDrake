import std/[os, strutils]
import ../src/nimdrake

type
  ProfileOptions* = object
    caseName*: string
    iterations*: int

proc profileOptions*(): ProfileOptions =
  result.iterations = 1
  let args = commandLineParams()
  var i = 0
  while i < args.len:
    let arg = args[i]
    if arg == "--profile-case" or arg == "--case" or arg == "-c":
      inc i
      if i >= args.len:
        raise newException(ValueError, "missing profile case")
      result.caseName = args[i]
    elif arg.startsWith("--profile-case="):
      result.caseName = arg[15 .. ^1]
    elif arg.startsWith("--case="):
      result.caseName = arg[7 .. ^1]
    elif arg == "--iterations" or arg == "-n":
      inc i
      if i >= args.len:
        raise newException(ValueError, "missing iteration count")
      result.iterations = parseInt(args[i])
    elif arg.startsWith("--iterations="):
      result.iterations = parseInt(arg[13 .. ^1])
    elif arg.len > 0 and arg[0] == '-':
      raise newException(ValueError, "unknown benchmark option: " & arg)
    inc i

  if result.caseName.len == 0:
    result.caseName = getEnv("NIMDRAKE_PROFILE_CASE", "")
  if result.iterations < 1:
    raise newException(ValueError, "iterations must be positive")

proc profilingRequested*(options: ProfileOptions): bool =
  options.caseName.len > 0

proc repeatProfile*(options: ProfileOptions, body: proc()) =
  for _ in 0 ..< options.iterations:
    body()

proc checkedIntSum*(query: string, expected: int64): int64 =
  let conn = newDatabase().connect()
  let resultSet = conn.execute(query)
  for chunk in resultSet:
    let values = chunk.bindAs(0, DuckType.BigInt)
    for i in 0 ..< values.len:
      result += values[i]
  doAssert result == expected, "unexpected benchmark result"
