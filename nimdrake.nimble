# Package

import std/[os, strutils]

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
  requires "criterion >= 0.3.1", "unittest2 >= 0.2.3",
           "nimibook >= 0.4.0"

# Tasks

const duckdbVersion = "v1.5.4"

proc fetchLib() =
  let includeDir = "src" / "include"
  mkDir(includeDir)

  var asset = ""
  var libraryName = ""
  var expectedSha256 = ""

  when defined(linux):
    libraryName = "libduckdb.so"
    if hostCPU == "amd64":
      asset = "libduckdb-linux-amd64.zip"
      expectedSha256 =
        "838d98a85e697bab9935010c88a8c67d3312ccedcab4cb4a0ba01da65113bb70"
    elif hostCPU == "arm64":
      asset = "libduckdb-linux-arm64.zip"
      expectedSha256 =
        "7e154fd14d5b7afd7c9f36071000bf4badd3fa57a125cf7dc596f2c5ad82c1b2"
    else:
      echo "DuckDB automatic download does not support Linux CPU: ", hostCPU
      quit(1)
  elif defined(macosx):
    asset = "libduckdb-osx-universal.zip"
    libraryName = "libduckdb.dylib"
    expectedSha256 =
      "3f3c52970ad1407ec5037062e1a5e575b24bd5b993c889f89fe5876eff47782c"
  elif defined(windows):
    libraryName = "duckdb.dll"
    if hostCPU == "amd64":
      asset = "libduckdb-windows-amd64.zip"
      expectedSha256 =
        "74e73afd3b010c6f310e14a961fff679f876952bc196f82584b0e2e76d11a91f"
    elif hostCPU == "arm64":
      asset = "libduckdb-windows-arm64.zip"
      expectedSha256 =
        "8056a9fc58a7c0ced9ebd5eb804e1bd2caf0e1ffb6711c8bd0c3ac0558a7da7f"
    else:
      echo "DuckDB automatic download does not support Windows CPU: ", hostCPU
      quit(1)
  else:
    echo "DuckDB automatic download does not support OS: ", hostOS
    quit(1)

  let libraryPath = includeDir / libraryName
  let headerPath = includeDir / "duckdb.h"
  let importPath = includeDir / "libduckdb.lib"
  if fileExists(libraryPath) and fileExists(headerPath) and
      (not defined(windows) or fileExists(importPath)):
    return

  let tempDir = getTempDir() / "nimdrake-duckdb"
  let archivePath = tempDir / asset
  let extractDir = tempDir / "extract"
  let url = "https://github.com/duckdb/duckdb/releases/download/" &
    duckdbVersion & "/" & asset

  try:
    rmDir(tempDir)
    mkDir(extractDir)
    exec "curl -fL --retry 3 --retry-all-errors --retry-delay 2 -o " &
      quoteShell(archivePath) & " " & quoteShell(url)

    when defined(windows):
      let psScript = "Expand-Archive -LiteralPath '" &
        archivePath.replace("'", "''") & "' -DestinationPath '" &
        extractDir.replace("'", "''") & "' -Force"
      exec "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass " &
        "-Command " & quoteShell(psScript)
    else:
      try:
        exec "unzip -q -o " & quoteShell(archivePath) & " -d " &
          quoteShell(extractDir)
      except OSError:
        exec "bsdtar -xf " & quoteShell(archivePath) & " -C " &
          quoteShell(extractDir)

    let digestCommand =
      when defined(windows):
        let psScript = "(Get-FileHash -Algorithm SHA256 -LiteralPath '" &
          archivePath.replace("'", "''") & "').Hash"
        "powershell -NoProfile -NonInteractive -Command " &
          quoteShell(psScript)
      else:
        "sha256sum " & quoteShell(archivePath) &
          " 2>/dev/null || shasum -a 256 " & quoteShell(archivePath)
    let (digestOutput, digestCode) = gorgeEx(digestCommand)
    if digestCode != 0 or digestOutput.splitWhitespace().len == 0 or
        digestOutput.splitWhitespace()[0].toLowerAscii != expectedSha256:
      echo "DuckDB archive checksum verification failed for ", asset
      quit(1)

    when defined(windows):
      exec "copy /Y " & quoteShell(extractDir / libraryName) & " " &
        quoteShell(libraryPath)
      exec "copy /Y " & quoteShell(extractDir / "duckdb.h") & " " &
        quoteShell(headerPath)
      exec "copy /Y " & quoteShell(extractDir / "duckdb.lib") & " " &
        quoteShell(importPath)
    else:
      exec "cp " & quoteShell(extractDir / libraryName) & " " &
        quoteShell(libraryPath)
      exec "cp " & quoteShell(extractDir / "duckdb.h") & " " &
        quoteShell(headerPath)
  finally:
    rmDir(tempDir)

task fetchLib, "Download the DuckDB native library for this platform":
  fetchLib()

before install:
  fetchLib()

when defined(windows):
  after install:
    # Nimble's global install puts the generated binary beside this file.
    # Keep the DLL beside it so Windows can resolve the runtime dependency.
    let installedDll =
      if fileExists("include/duckdb.dll"): "include/duckdb.dll"
      elif fileExists("src/include/duckdb.dll"): "src/include/duckdb.dll"
      else: ""
    if installedDll.len > 0:
      exec "copy /Y " & quoteShell(installedDll) & " " &
        quoteShell("duckdb.dll")

task test, "run testament":
  exec "testament p \"./tests/**/test_*.nim\""
  exec "find tests/ -type f ! -name \"*.*\" -delete 2> /dev/null"

task docs, "Generate documentation":
  exec "nimble doc --useSystemNim --verbose --docCmd:--passL:-lduckdb --project --outdir:docs --git.url:https://github.com/BontaVlad/NimDrake --git.commit:main src/nimdrake.nim"

task generate, "Generate bindings":
  # Futhark is required only for binding generation, not for normal use
  exec "nimble install -y futhark"
  exec "nim c --maxLoopIterationsVM=10000000000 -d:useFuthark -d:nodeclguards:true -d:exportall:true -r src/nimdrake.nim"
