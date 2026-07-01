when defined(i386) or defined(amd64):
  import decimal
  export decimal
else:
  {.warning: "Decimal support requires x86/amd64; DecimalType operations will raise on this architecture.".}
  type DecimalType* = object

  proc newDecimal*(input: string): DecimalType =
    raise ValueError.newException "Decimal only supported on x86/amd64 arch"
