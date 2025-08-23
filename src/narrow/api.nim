import std/strformat

when defined(useFuthark):
  import os, futhark
  # Tell futhark where to find the C libraries you will compile with, and what
  # header files you wish to import.
  importc:
    outputPath currentSourcePath.parentDir / "generated.nim"
    sysPath "/usr/lib/clang/10/include"
    path "/usr/lib/gcc/x86_64-pc-linux-gnu/15.1.1/include"
    path "/usr/include/arrow-glib"
    path "/usr/lib/x86_64-linux-gnu/glib-2.0/include"
    path "/usr/include/glib-2.0"
    path "/usr/lib/glib-2.0/include"
    define UTF8PROC_EXPORTS
    "arrow-glib.h" # imports nothing by itself
    "arrow-glib/basic-array.h"
    "gobject/gobject.h"

  {.passL: "-lduckdb".}
else:
  include "generated.nim"

# # when defined(useFuthark):
# #   const
# #     arrowCflags = gorge("pkg-config --cflags arrow-glib glib-2.0").strip()
# #     arrowLibs = gorge("pkg-config --libs arrow-glib glib-2.0").strip()

# #   echo "Using cflags: ", arrowCflags
# #   echo "Using libs: ", arrowLibs

# #   importc:
# #     outputPath currentSourcePath.parentDir / "generated.nim"

# #     sysPath "/usr/include"
# #     path "/usr/lib/gcc/x86_64-pc-linux-gnu/15.1.1/include"

# #     # Parse pkg-config output and add paths
# #     # This is a simplified version - you might need to parse arrowCflags properly
# #     path "/usr/include/glib-2.0"
# #     path "/usr/lib/glib-2.0/include"
# #     path "/usr/include/arrow-glib"

# #     "arrow-glib.h"

# #   {.passL: arrowLibs.}
# # else:
# #   include "generated.nim"
