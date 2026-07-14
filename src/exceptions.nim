import ffi

type
  BaseError* = object of CatchableError
  OperationError* = object of BaseError
  DuckState* = enumDuckDbState

converter toBool*(e: DuckState): bool =
  e != enumDuckDbState.Duckdbsuccess

template check*(state: DuckState, message: string): untyped =
  if state:
    raise newException(OperationError, message)

template check*(state: DuckState, message: string, finalizer: untyped): untyped =
  if state:
    finalizer
    raise newException(OperationError, message)
