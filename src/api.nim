import std/strformat

when defined(useFuthark):
  import os, futhark
  # Tell futhark where to find the C libraries you will compile with, and what
  # header files you wish to import.
  importc:
    outputPath currentSourcePath.parentDir / "generated.nim"
    path "src/include"
    "duckdb.h"

  {.passL: "-lduckdb".}
else:
  include "generated.nim"

# 2048 is duckdb_vector_size(), but we can't do this at compile time
const
  VECTOR_SIZE* = 2048
  ROW_GROUP_SIZE* = VECTOR_SIZE * 100

let runtimeVectorSize = duckdbVectorSize().int
if runtimeVectorSize != VECTOR_SIZE:
  raise newException(ValueError, fmt"Duckdb was compiled for a size of {VECTOR_SIZE}, this configuration of DUCKDB was set at {runtimeVectorSize}")
