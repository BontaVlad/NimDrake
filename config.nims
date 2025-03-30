import std/[cmdline, strutils]

# Common flags for all architectures
switch("define", "unittest2Compat=false")

# Detect cross-compilation and get the target
var targetCPU = hostCPU  # Default to host CPU
var isInt128Supported = true  # Default assumption
var isStaticBuild = false
var isx86= false

# Check if specific CPU is targeted for cross-compilation
for param in commandLineParams():
  if param == "--passL:-static":
    isStaticBuild = true

  if param.startsWith("--cpu:"):
    targetCPU = param[6..^1]
    echo "Cross-compiling for CPU: ", targetCPU

    # Update Int128 support based on target CPU
    case targetCPU
    of "amd64", "x86_64":
      isInt128Supported = true
      isx86 = true
    of "powerpc64", "powerpc64el":
      isInt128Supported = true
    of "i386", "arm", "arm64", "aarch64", "riscv64":
      isInt128Supported = false
    else:
      echo "Warning: Unknown target CPU. Assuming no Int128 support."
      isInt128Supported = false

echo "Target CPU: ", targetCPU
echo "Int128 support: ", isInt128Supported

# Apply appropriate flags
if isInt128Supported:
  switch("define", "useCInt128=cunotequal,cnotequal,cuequal,cequal,cugreaterthanorequal,cgreaterthanorequal,cugreaterthan,cgreaterthan,culessthan,clessthan,culessthanorequal,clessthanorequal,cubitand,cbitand,cubitor,cbitor,cubitnot,cbitnot,cubitxor,cbitxor,cushl,cshl,cushr,cshr,cuplus,cplus,cuminus,cminus,cuminusunary,cminusunary,cumul64by64To128,cumul,cmul,cudivmod,cdivmod,cudiv,cdiv,cumod,cmod")
else:
  echo "Int128 features disabled for target CPU: ", targetCPU
  switch("define", "noInt128Support")

if not isx86:
  switch("define", "nox86Support")

# if not isStaticBuild:
#   switch("passL", "-lduckdb")
#   switch("passL", "-L.")
#   switch("passC", "-I.")

# ➜  NimDrake git:(main) ✗ nim c --cpu:arm64 --os:linux --cc:gcc \
#     --gcc.exe="aarch64-linux-gnu-gcc" \
#     --gcc.linkerexe="aarch64-linux-gnu-g++" \
#     --passC:"-mcpu=cortex-a53" \
#     --passL:"-mcpu=cortex-a53" \
#     --passL:"-static" \
#     --passL:"-L$(pwd)" \
#     --passL:"-l:src/include/arm64/libduckdb_bundle.a" \
#     --passL:"-lstdc++" \
#     --passL:"-lm" \
#     --passL:"-ldl" \
#     src/nimdrake
