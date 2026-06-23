import std/[cmdline, strutils, parseutils, os]

# --- Project paths ---
switch("path", thisDir() / "src")
switch("define", "unittest2Compat=false")

# --- pkg-config flags (safe for LSP) ---
# nimsuggest evaluates config.nims on every keystroke; guard shell calls so
# the language server doesn't hang on `gorge("pkg-config ...")`.
#
# Arrow/GLib linking is handled by the `narrow` package itself when the
# `features.nimdrake.arrow` feature is enabled. Do not duplicate it here.
when not defined(nimsuggest) and not defined(useFuthark):
  # Link against system-installed libduckdb.
  # Skip during futhark binding generation — it only parses headers, no linking.
  switch("passL", "-lduckdb")

  when defined(macosx):
    switch("passL", "-Wl,-rpath,/usr/local/lib")

  when defined(windows):
    # Nim's generated C uses MSVCRT helpers (_isatty, _get_osfhandle, _setmode)
    # without including <io.h>. MSYS2's mingw gcc 14+ treats implicit function
    # declarations as hard errors under C99+ default mode. Downgrade the
    # diagnostic so the code compiles; the linker still resolves the symbols
    # from the UCRT/MSVCRT runtime.
    switch("passC", "-Wno-implicit-function-declaration")

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
