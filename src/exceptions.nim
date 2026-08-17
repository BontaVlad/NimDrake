## The error model shared by every module: a `DuckState` result + the
## `check` guards that raise `OperationError` on failure.
##
## DuckDB's C API reports errors via `duckdb_state` return codes; the `check`
## templates convert those into exceptions so execution stops at the first
## failure instead of threading error values through every call. Code that
## must inspect the result before raising uses `DuckState` and `toBool`
## directly.
import ffi

type
  BaseError* = object of CatchableError ## Root of all NimDrake errors.
  OperationError* = object of BaseError ## A DuckDB operation failed; the
                                        ## message carries DuckDB's text.
  DuckState* = enumDuckDbState ## The DuckDB C result state;
                               ## `Duckdbsuccess` means no error.

converter toBool*(e: DuckState): bool =
  ## `true` iff `e` is an error state (not `Duckdbsuccess`).
  e != enumDuckDbState.Duckdbsuccess

template check*(state: DuckState, message: string): untyped =
  ## Raises `OperationError(message)` if `state` indicates failure.
  if state:
    raise newException(OperationError, message)

template check*(state: DuckState, message: string, finalizer: untyped): untyped =
  ## Like `check`, but runs `finalizer` (e.g. resource cleanup) before raising.
  if state:
    finalizer
    raise newException(OperationError, message)
