import std/assertions
when defined(samply):
  import std/[os, sequtils, strutils]
import ../src/samplyprofiler

when defined(samply):
  block enabled_nested_markers:
    var profiler = initSamplyProfiler(PerThread, 32)
    doAssert profiler.enabled
    doAssert profiler.path.endsWith(".txt")

    var bodyRuns = 0
    profile(profiler, "outer scope"):
      inc bodyRuns
      profile(profiler, "inner scope with spaces"):
        inc bodyRuns
    doAssert bodyRuns == 2

    try:
      profile(profiler, "exception scope"):
        raise newException(ValueError, "expected test exception")
    except ValueError:
      discard

    let start = profiler.begin("manual marker")
    profiler.finish(start, "manual marker with spaces")
    profiler.close()

    let lines = readFile(profiler.path).splitLines.filterIt(it.len > 0)
    doAssert lines.len == 4
    var seenOuter = false
    var seenInner = false
    var seenException = false
    var seenManual = false
    for line in lines:
      let fields = line.split(' ', maxsplit = 2)
      doAssert fields.len == 3
      let markerStart = parseUInt(fields[0])
      let markerEnd = parseUInt(fields[1])
      doAssert markerStart <= markerEnd
      case fields[2]
      of "outer scope": seenOuter = true
      of "inner scope with spaces": seenInner = true
      of "exception scope": seenException = true
      of "manual marker with spaces": seenManual = true
      else: doAssert false, "unexpected marker name"
    doAssert seenOuter and seenInner and seenException and seenManual
    removeFile(profiler.path)

  block marker_file_grows:
    var profiler = initSamplyProfiler(PerProcess, 16)
    doAssert profiler.enabled
    for i in 0 ..< 100:
      let start = profiler.begin("growth marker " & $i)
      profiler.finish(start, "growth marker " & $i)
    let path = profiler.path
    profiler.close()
    doAssert readFile(path).splitLines.filterIt(it.len > 0).len == 100
    removeFile(path)
else:
  block disabled_build:
    var profiler = initSamplyProfiler()
    doAssert not profiler.enabled
    var bodyRuns = 0
    profile(profiler, "not emitted"):
      inc bodyRuns
    doAssert bodyRuns == 1
    profiler.close()
