import api

type
  BaseError* = object of CatchableError
  OperationError* = object of BaseError
  Error* = enumDuckDbState

converter toBool*(e: Error): bool =
  e != enumDuckDbState.Duckdbsuccess

template check*(error: Error, message: string): untyped =
  if error:
    raise newException(OperationError, message)

template check*(error: Error, message: string, finalizer: untyped): untyped =
  if error:
    finalizer
    raise newException(OperationError, message)
