# Package

version       = "0.1.0"
author        = "Sergiu Vlad Bonta"
description   = "Duckdb nim wrapper"
license       = "MIT"
srcDir        = "src"
bin           = @["nimdrake"]

# Dependencies - normal/prod
# Required by code under src/ at build/runtime.

requires "nim >= 2.0.0", "nint128", "decimal >= 0.0.2",
         "terminaltables >= 0.1.1", "uuid4 >= 0.9.3", "fusion >= 1.2",
         "threading >= 0.2.1"

# Optional features
# Activate with: nimble install --parser:declarative --features:arrow
# Code gates on `when defined(features.nimdrake.arrow)`.
# narrow wraps the Apache Arrow GLib C API; it requires the system libraries
# (arrow-glib, parquet-glib, arrow-dataset-glib) to be installed and linked
# via pkg-config. See https://github.com/BontaVlad/narrow for details.

feature "arrow":
  requires "narrow >= 0.0.1"

feature "tensor":
  requires "arraymancer"

# Dependencies - dev
# Only used by tests, benchmarks, or wrapper regeneration (-d:useFuthark).
# Activate with: nimble install --parser:declarative --features:dev
# Code can gate on `when defined(features.nimdrake.dev)`.

dev:
  requires "criterion >= 0.3.1", "unittest2 >= 0.2.3"

# Tasks

task test, "run testament":
  exec "testament p \"./tests/**/test_*.nim\""
  exec "find tests/ -type f ! -name \"*.*\" -delete 2> /dev/null"

task docs, "Generate documentation":
  exec "nimble doc --useSystemNim --verbose --docCmd:--passL:-lduckdb --project --out:docs src/nimdrake.nim"

task generate, "Generate bindings":
  # Futhark is required only for binding generation, not for normal use
  exec "nimble install -y futhark"
  exec "nim c --maxLoopIterationsVM=10000000000 -d:useFuthark -d:nodeclguards:true -d:exportall:true -r src/nimdrake.nim"
