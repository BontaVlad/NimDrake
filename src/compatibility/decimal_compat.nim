## Architecture shim exposing the `decimal` package (`DecimalType` and
## `Decimal128`) under one name. On non-x86 builds a stub raises instead.
when defined(i386) or defined(amd64):
  import decimal
  export decimal
else:
  {.warning: "Decimal support requires x86/amd64; DecimalType operations will raise on this architecture.".}
  type DecimalType* = object

  proc newDecimal*(input: string): DecimalType =
    raise ValueError.newException "Decimal only supported on x86/amd64 arch"
