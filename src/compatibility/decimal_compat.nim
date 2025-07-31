when defined(i386) or defined(amd64):
  import decimal
  export decimal
else:
  type DecimalType* = object

  proc newDecimal*(input: string): DecimalType =
    raise ValueError.newException "Decimal only supported on x86 arch"
