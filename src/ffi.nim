import std/strformat

# 2048 is duckdb_vector_size(), but we can't do this at compile time
const
  VECTOR_SIZE* = 2048
  ROW_GROUP_SIZE* = VECTOR_SIZE * 100

when defined(useFuthark):
  import os
  import futhark

  # DuckDB does not ship a pkg-config (.pc) file in most distributions, so we
  # try pkg-config first (works for vcpkg/Conan users) and fall back to the
  # standard system include locations where duckdb.h normally lives.
  importc:
    compilerArg gorge("pkg-config --cflags-only-I duckdb 2>/dev/null || true")
    path "/usr/local/include"
    path "/usr/include"
    "duckdb.h"
    outputPath currentSourcePath.parentDir / "generated.nim"

  {.passC: gorge("pkg-config --cflags duckdb 2>/dev/null || true").}
  {.passL: gorge("pkg-config --libs duckdb 2>/dev/null || echo '-lduckdb'").}
else:
  include "generated.nim"

  let runtimeVectorSize = duckdbVectorSize().int
  if runtimeVectorSize != VECTOR_SIZE:
    raise newException(
      ValueError,
      fmt"Duckdb was compiled for a size of {VECTOR_SIZE}, this configuration of DUCKDB was set at {runtimeVectorSize}",
    )
