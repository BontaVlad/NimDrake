import std/[os, strformat, sequtils]

# Package

version       = "0.1.0"
author        = "Sergiu Vlad Bonta"
description   = "Duckdb nim wrapper"
license       = "MIT"
srcDir        = "src"
bin           = @["nimdrake"]

# Dependencies

requires "nim >= 2.0.0"
requires "futhark"
requires "nint128"
requires "decimal >= 0.0.2"
requires "terminaltables >= 0.1.1"
requires "uuid4 >= 0.9.3"
requires "criterion >= 0.3.1"
requires "fusion >= 1.2"

task test, "run testament":
  echo staticExec("testament p \"./tests/**/test_*.nim\"")
  discard staticExec("find tests/ -type f ! -name \"*.*\" -delete 2> /dev/null")

task docs, "Generate documentation":
  exec "nimble doc --useSystemNim --verbose --docCmd:\"--passL:\"-lduckdb\"\" --project --out:docs src/nimdrake.nim"

requires "taskpools >= 0.0.4"