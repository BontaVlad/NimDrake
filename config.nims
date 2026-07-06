import std/[cmdline, strutils, parseutils, os]

# --- Project paths ---
switch("path", thisDir() / "src")
switch("define", "unittest2Compat=false")

# --- DuckDB link resolution (safe for LSP) ---
# nimsuggest evaluates config.nims on every keystroke; guard shell calls so
# the language server doesn't hang on `gorge("pkg-config ...")`.
#
# Arrow/GLib linking is handled by the `narrow` package itself when the
# `features.nimdrake.arrow` feature is enabled. Do not duplicate it here.
#
# Lookup order (skipped entirely during futhark binding generation — it only
# parses headers, no linking):
#   1. Local:  src/include/libduckdb.{so|dylib|dll}  (vendored via `just fetch-lib`)
#   2. System: pkg-config --exists duckdb, else ldconfig -p grep
#   3. Error:  fail fast with a clear message
when not defined(nimsuggest) and not defined(useFuthark):
  const duckdbIncDir = thisDir() / "src" / "include"

  proc duckdbLocalLib(): string =
    when defined(macosx):  result = duckdbIncDir / "libduckdb.dylib"
    elif defined(windows): result = duckdbIncDir / "duckdb.dll"
    else:                  result = duckdbIncDir / "libduckdb.so"

  if fileExists(duckdbLocalLib()):
    # Tier 1: vendored lib under src/include/.
    # -L finds it at link time; -Wl,-rpath,<abs dir> lets the runtime loader
    # find it without LD_LIBRARY_PATH or /etc/ld.so.conf.d edits.
    switch("passL", "-L" & duckdbIncDir)
    switch("passL", "-lduckdb")
    switch("passL", "-Wl,-rpath," & duckdbIncDir)
    when defined(macosx):
      # Keep the system path as a secondary rpath so a missing vendored dylib
      # doesn't shadow a system install users may have for other tools.
      switch("passL", "-Wl,-rpath,/usr/local/lib")
    when defined(windows):
      switch("passC", "-Wno-implicit-function-declaration")
  else:
    # Tier 2: probe for a system-installed libduckdb.
    # pkg-config is the preferred signal (vcpkg/Conan/Homebrew ship .pc files).
    # The fallback is platform-specific:
    #   Linux:  ldconfig -p (covers distro installs without a .pc file)
    #   macOS:  check standard dylib paths (ldconfig doesn't exist on macOS)
    #   Windows: check MSYS2/mingw default lib dir for the import library
    let pcOk = gorge("pkg-config --exists duckdb && echo yes || echo no").strip == "yes"
    var sysOk = false
    when defined(macosx):
      sysOk = fileExists("/usr/local/lib/libduckdb.dylib") or
              fileExists("/opt/homebrew/lib/libduckdb.dylib")
    elif defined(linux):
      sysOk = gorge("ldconfig -p 2>/dev/null | grep -qi libduckdb && echo yes || echo no").strip == "yes"
    elif defined(windows):
      sysOk = fileExists("C:/msys64/mingw64/lib/libduckdb.lib") or
              fileExists("C:/msys64/mingw64/lib/duckdb.lib")
    if pcOk or sysOk:
      when defined(windows):
        switch("passL", "-LC:/msys64/mingw64/lib")
      switch("passL", "-lduckdb")
      when defined(macosx):
        switch("passL", "-Wl,-rpath,/usr/local/lib")
      when defined(windows):
        switch("passC", "-Wno-implicit-function-declaration")
    else:
      # Tier 3: nothing found. Fail the build with an actionable message.
      echo "Fatal: libduckdb not found. Either:"
      echo "  (1) run `just fetch-lib` to vendor libduckdb.so + duckdb.h under src/include/, or"
      echo "  (2) install libduckdb system-wide (and ensure a pkg-config .pc file or a standard library path entry)."
      quit(1)

# --- Sanitizers (opt-in via -d:useSanitizers) ---
when defined(useSanitizers):
  switch("passL", "-fsanitize=address")
  switch("passC", "-fsanitize=address")
  switch("passL", "-lasan")
  switch("define", "useMalloc")
  switch("stacktrace", "on")
  switch("excessiveStackTrace", "on")
  switch("debuginfo", "on")

# --- Cross-compilation / Int128 support ---
var targetCPU = hostCPU
var isInt128Supported = true
var isStaticBuild = false

for param in commandLineParams():
  if param == "--passL:-static":
    isStaticBuild = true

  if param.startsWith("--cpu:"):
    targetCPU = param[6..^1]
    echo "Cross-compiling for CPU: ", targetCPU
    case targetCPU
    of "amd64", "x86_64", "powerpc64", "powerpc64el":
      isInt128Supported = true
    of "i386", "arm", "arm64", "aarch64", "riscv64":
      isInt128Supported = false
    else:
      echo "Warning: Unknown target CPU. Assuming no Int128 support."
      isInt128Supported = false

# echo "Target CPU: ", targetCPU
# echo "Int128 support: ", isInt128Supported

if isInt128Supported:
  switch(
    "define",
    "useCInt128=cunotequal,cnotequal,cuequal,cequal,cugreaterthanorequal,cgreaterthanorequal,cugreaterthan,cgreaterthan,culessthan,clessthan,culessthanorequal,clessthanorequal,cubitand,cbitand,cubitor,cbitor,cubitnot,cbitnot,cubitxor,cbitxor,cushl,cshl,cushr,cshr,cuplus,cplus,cuminus,cminus,cuminusunary,cminusunary,cumul64by64To128,cumul,cmul,cudivmod,cdivmod,cudiv,cdiv,cumod,cmod",
  )
else:
  echo "Int128 features disabled for target CPU: ", targetCPU
  switch("define", "noInt128Support")

if isStaticBuild:
  echo "Static build detected: skipping rpath/sanitizers"

# --- Nimble integration ---
# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config

# Cross-compilation example:
#   nim c --cpu:arm64 --os:linux --cc:gcc \
#       --gcc.exe="aarch64-linux-gnu-gcc" \
#       --gcc.linkerexe="aarch64-linux-gnu-g++" \
#       --passC:"-mcpu=cortex-a53" \
#       --passL:"-mcpu=cortex-a53" \
#       --passL:"-static" \
#       --passL:"-L$(pwd)" \
#       --passL:"-l:src/include/arm64/libduckdb_bundle.a" \
#       --passL:"-lstdc++" \
#       --passL:"-lm" \
#       --passL:"-ldl" \
#       src/nimdrake
