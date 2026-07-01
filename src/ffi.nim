# duckdb_vector_size() is a runtime API call, so VECTOR_SIZE cannot be a const.
# It is initialized once at module load from the linked DuckDB library.
# ROW_GROUP_SIZE follows from VECTOR_SIZE.

when defined(useFuthark):
  const
    VECTOR_SIZE* = 2048
    ROW_GROUP_SIZE* = VECTOR_SIZE * 100

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

  let VECTOR_SIZE* = duckdbVectorSize().int
  let ROW_GROUP_SIZE* = VECTOR_SIZE * 100
