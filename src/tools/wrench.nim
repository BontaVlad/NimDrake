import std/macros

proc duckTypeDotExpr*(elemType: NimNode): NimNode =
  ## Maps a Nim type node to the matching `DuckType.X` dot-expression.
  ## Single source of truth shared by `newChunk` and `registerScalar` macros.
  let n = repr(elemType)
  let dt = ident"DuckType"
  if n == "bool": newDotExpr(dt, ident"Boolean")
  elif n == "int8": newDotExpr(dt, ident"TinyInt")
  elif n == "int16": newDotExpr(dt, ident"SmallInt")
  elif n == "int32": newDotExpr(dt, ident"Integer")
  elif n == "int64" or n == "int": newDotExpr(dt, ident"BigInt")
  elif n == "uint8" or n == "byte": newDotExpr(dt, ident"UTinyInt")
  elif n == "uint16": newDotExpr(dt, ident"USmallInt")
  elif n == "uint32": newDotExpr(dt, ident"UInteger")
  elif n == "uint64" or n == "uint": newDotExpr(dt, ident"UBigInt")
  elif n == "float32": newDotExpr(dt, ident"Float")
  elif n == "float64" or n == "float": newDotExpr(dt, ident"Double")
  elif n == "string": newDotExpr(dt, ident"Varchar")
  elif n == "seq[byte]": newDotExpr(dt, ident"Blob")
  elif n == "Timestamp" or n == "DateTime": newDotExpr(dt, ident"Timestamp")
  elif n == "Time": newDotExpr(dt, ident"Time")
  elif n == "TimeInterval": newDotExpr(dt, ident"Interval")
  elif n == "Int128": newDotExpr(dt, ident"HugeInt")
  elif n == "UInt128": newDotExpr(dt, ident"UHugeInt")
  elif n == "Uuid": newDotExpr(dt, ident"UUID")
  elif n == "ZonedTime": newDotExpr(dt, ident"TimeTz")
  else: error("unsupported element type: " & n, elemType)
