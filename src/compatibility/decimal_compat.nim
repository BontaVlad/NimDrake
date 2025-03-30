when defined(nox86Support):
  echo "foo"
  type
    DecimalType* = object

  proc newDecimal*(input: string): DecimalType =
    raise ValueError.newException "Decimal only supported on x86 arch"

else:
  import decimal
  echo "decimal should work"

  export decimal
