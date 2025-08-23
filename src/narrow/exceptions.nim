import macros
import ./[api]

type OperationError* = object of CatchableError

macro check*(callable: untyped): untyped =
  expectKind(callable, nnkCall)
  expectMinLen(callable, 1)

  let funcName = callable[0]
  var args = newSeq[NimNode]()

  # Copy existing arguments
  for i in 1 ..< callable.len:
    args.add(callable[i])

  # Create the error variable identifier
  let errorVar = genSym(nskVar, "error")

  # Add the error parameter to the arguments
  args.add(newDotExpr(errorVar, newIdentNode("addr")))

  # Build the new function call with the error parameter
  let newCall = newCall(funcName, args)

  # Generate the complete code block
  result = quote:
    var `errorVar`: ptr GError
    let isSuccess = `newCall`

    if isSuccess != 1 or not isNil(`errorVar`):
      # `finalizer`
      raise newException(OperationError, $`errorVar`.message)
  echo repr result

when isMainModule:
  let builder = garrow_string_array_builder_new()

  check(garrow_boolean_array_builder_append_value(cast[ptr GArrowBooleanArrayBuilder](builder), 0.gboolean))
