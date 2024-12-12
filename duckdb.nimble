import std/[os, strformat, sequtils]

# Package

version       = "0.1.0"
author        = "Sergiu Vlad Bonta"
description   = "Duckdb nim wrapper"
license       = "MIT"
srcDir        = "src"
bin           = @["duckdb"]

# Dependencies

requires "nim >= 2.0.0"
requires "futhark"
requires "nint128"
requires "decimal >= 0.0.2"
requires "pretty >= 0.1.0"
requires "terminaltables >= 0.1.1"
requires "uuid4 >= 0.9.3"

# Function to execute shell command and return output as a sequence of strings
proc execAndGetLines(cmd: string): seq[string] =
  let output = staticExec(cmd)
  result = output.splitLines().filterIt(it.len > 0)

task test, "run testament":
  echo staticExec("testament p \"./tests/**/test_*.nim\"")
  discard staticExec("find tests/ -type f ! -name \"*.*\" -delete 2> /dev/null")

task coverage, "generate tests coverage":
  let fileinfo = "lcov.info"
  let lcov_args = "--rc branch_coverage=1 --ignore-errors inconsistent --ignore-errors range --ignore-errors unused"
  let generated_not_to_break_here = "generated_not_to_break_here"
  let nimcache_dir = "nimcache"

  # Find test files
  let files = execAndGetLines("find ./tests -name 'test_*.nim'")

  # Compile and run tests
  for file in files[0..1]:
    echo "Processing file: ", file
    let filename = file.split("/")[^1]
    exec fmt"""nim c --nimcache:{nimcache_dir} --hints:off --debugger:native --passC:--coverage --passL:--coverage -o:{nimcache_dir}/tests/{filename[0..^5]} {file}"""

    exec fmt"{nimcache_dir}/tests/{filename[0..^5]}"

  exec fmt"touch {generated_not_to_break_here}"
  # Generate coverage
  exec fmt"""lcov {lcov_args} --capture --directory {nimcache_dir} --output-file {fileinfo}"""
  rmFile generated_not_to_break_here

  # Cleanup coverage data
  let currentFolder = absolutePath("")
  exec fmt"""lcov {lcov_args} --extract {fileinfo} "{currentFolder}/src/*" -o {fileinfo}"""
  exec fmt"""lcov {lcov_args} --remove {fileinfo} "{currentFolder}/tests/*" -o {fileinfo}"""

  # Generate HTML report
  exec fmt"""genhtml --branch-coverage --ignore-errors range --legend --output-directory coverage/ {fileinfo}"""

task debug, "Compile and record program execution with rr":
    let nimFile = "tests/results/test_result_type.nim"

    # Step 1: Compile and run the Nim file with specific flags
    exec "nim c -r -d:debug -d:nimDebugDlOpen --opt:none --debugger:native --stacktrace:on -d:useMalloc --mm:orc --passC:-O0 --threads:off " & nimFile
    # Step 2: Record using rr
    exec "rr record -M " & nimFile.replace(".nim", "")

    # Step 3: Replay using rr
    exec "rr -M replay -e"
