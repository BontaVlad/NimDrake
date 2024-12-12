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
