import std/os

template ignoreLeak*(body: untyped) =
  proc runWhileIgnoringLeaks() {.codegenDecl: "__attribute__((leak_sanitizer(ignore))) $# $#$#".} =
    body

template withTempDb*(path: string; body: untyped) =
  ## Runs `body` with an on-disk DB at `path`, removing the file and
  ## its WAL on exit.  Use for tests that need persistent storage.
  try:
    body
  finally:
    if path.fileExists:
      removeFile(path)
    let wal = path & ".wal"
    if wal.fileExists:
      removeFile(wal)
