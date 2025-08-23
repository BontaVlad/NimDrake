import std/[options, sequtils]
import ./[api, exceptions]

type
  ArrayBuilder*[T] = object
    handle: ptr GArrowArrayBuilder

  Array*[T] = object
    handle: ptr GArrowArray

# Core builder creation procedures for all types
proc newArrayBuilder*[T](): ArrayBuilder[T] =
  when T is bool:
    let handle = cast[ptr GArrowArrayBuilder](garrow_boolean_array_builder_new())
  elif T is int8:
    let handle = cast[ptr GArrowArrayBuilder](garrow_int8_array_builder_new())
  elif T is uint8:
    let handle = cast[ptr GArrowArrayBuilder](garrow_uint8_array_builder_new())
  elif T is int16:
    let handle = cast[ptr GArrowArrayBuilder](garrow_int16_array_builder_new())
  elif T is uint16:
    let handle = cast[ptr GArrowArrayBuilder](garrow_uint16_array_builder_new())
  elif T is int32:
    let handle = cast[ptr GArrowArrayBuilder](garrow_int32_array_builder_new())
  elif T is uint32:
    let handle = cast[ptr GArrowArrayBuilder](garrow_uint32_array_builder_new())
  elif T is int64:
    let handle = cast[ptr GArrowArrayBuilder](garrow_int64_array_builder_new())
  elif T is uint64:
    let handle = cast[ptr GArrowArrayBuilder](garrow_uint64_array_builder_new())
  elif T is float32:
    let handle = cast[ptr GArrowArrayBuilder](garrow_float_array_builder_new())
  elif T is float64:
    let handle = cast[ptr GArrowArrayBuilder](garrow_double_array_builder_new())
  elif T is string:
    let handle = cast[ptr GArrowArrayBuilder](garrow_string_array_builder_new())

  if isNil(handle):
    raise newException(OperationError, "Error creating the builder")

  result = ArrayBuilder[T](handle: handle)

proc append*[T](builder: var ArrayBuilder, val: sink T) =
  when T is bool:
    check(garrow_boolean_array_builder_append_value(
      cast[ptr GArrowBooleanArrayBuilder](builder.handle),
      if val: 1.gboolean else: 0.gboolean))
  elif T is int8:
    check(garrow_int8_array_builder_append_value(
      cast[ptr GArrowInt8ArrayBuilder](builder.handle), val
    ))
  elif T is uint8:
    check(garrow_uint8_array_builder_append_value(
      cast[ptr GArrowUInt8ArrayBuilder](builder.handle), val
    ))
  elif T is int16:
    check(garrow_int16_array_builder_append_value(
      cast[ptr GArrowInt16ArrayBuilder](builder.handle), val
    ))
  elif T is uint16:
    check(garrow_uint16_array_builder_append_value(
      cast[ptr GArrowUInt16ArrayBuilder](builder.handle), val
    ))
  elif T is int32:
    check(garrow_int32_array_builder_append_value(
      cast[ptr GArrowInt32ArrayBuilder](builder.handle), val
    ))
  elif T is uint32:
    check(garrow_uint32_array_builder_append_value(
      cast[ptr GArrowUInt32ArrayBuilder](builder.handle), val
    ))
  elif T is int64:
    check(garrow_int64_array_builder_append_value(
      cast[ptr GArrowInt64ArrayBuilder](builder.handle), val
    ))
  elif T is uint64:
    check(garrow_uint64_array_builder_append_value(
      cast[ptr GArrowUInt64ArrayBuilder](builder.handle), val
    ))
  elif T is float32:
    check(garrow_float_array_builder_append_value(
      cast[ptr GArrowFloatArrayBuilder](builder.handle), val
    ))
  elif T is float64:
    check garrow_double_array_builder_append_value(
      cast[ptr GArrowDoubleArrayBuilder](builder.handle), val
    )
  elif T is string:
    check garrow_string_array_builder_append_value(
      cast[ptr GArrowStringArrayBuilder](builder.handle), val.cstring
    )

proc appendNull*[T](builder: var ArrayBuilder) =
  when T is bool:
    check garrow_boolean_array_builder_append_null(cast[ptr GArrowBooleanArrayBuilder](builder.handle)
  elif T is int8:
    check garrow_int8_array_builder_append_null(
      cast[ptr GArrowInt8ArrayBuilder](builder.handle)
    )
  elif T is uint8:
    check garrow_uint8_array_builder_append_null(
      cast[ptr GArrowUInt8ArrayBuilder](builder.handle)
    )
  elif T is int16:
    check garrow_int16_array_builder_append_null(
      cast[ptr GArrowInt16ArrayBuilder](builder.handle)
    )
  elif T is uint16:
    check garrow_uint16_array_builder_append_null(
      cast[ptr GArrowUInt16ArrayBuilder](builder.handle)
    )
  elif T is int32:
    check garrow_int32_array_builder_append_null(
      cast[ptr GArrowInt32ArrayBuilder](builder.handle)
    )
  elif T is uint32:
    check garrow_uint32_array_builder_append_null(
      cast[ptr GArrowUInt32ArrayBuilder](builder.handle)
    )
  elif T is int64:
    check garrow_int64_array_builder_append_null(
      cast[ptr GArrowInt64ArrayBuilder](builder.handle)
    )
  elif T is uint64:
    check garrow_uint64_array_builder_append_null(
      cast[ptr GArrowUInt64ArrayBuilder](builder.handle)
    )
  elif T is float32:
    check garrow_float_array_builder_append_null(
      cast[ptr GArrowFloatArrayBuilder](builder.handle)
    )
  elif T is float64:
    check garrow_double_array_builder_append_null(
      cast[ptr GArrowDoubleArrayBuilder](builder.handle)
    )
  else:
    check garrow_array_builder_append_null(builder.handle)

proc append*[T](builder: var ArrayBuilder, val: sink Option[T]) =
  if val.isSome():
    builder.append(val.get())
  else:
    builder.appendNull()

# Batch append procedures for better performance
proc appendValues*[T](builder: var ArrayBuilder, values: sink seq[T]) =
  var errorBuffer: ptr Gerror
  when T is int32:
    let errorNo = garrow_int32_array_builder_append_values(
      cast[ptr GArrowInt32ArrayBuilder](builder.handle),
      cast[ptr gint32](values[0].addr),
      values.len.gint64,
      nil,
      0,
      errorBuffer.addr,
    )
    echo errorNo
  elif T is int64:
    discard garrow_int64_array_builder_append_values(
      cast[ptr GArrowInt64ArrayBuilder](builder.handle),
      cast[ptr gint64](values[0].addr),
      values.len.gint64,
      nil,
      0,
      errorBuffer.addr,
    )
  elif T is float32:
    discard garrow_float_array_builder_append_values(
      cast[ptr GArrowFloatArrayBuilder](builder.handle),
      cast[ptr gfloat](values[0].addr),
      values.len.gint64,
      nil,
      0,
      errorBuffer.addr,
    )
  elif T is float64:
    discard garrow_double_array_builder_append_values(
      cast[ptr GArrowDoubleArrayBuilder](builder.handle),
      cast[ptr gdouble](values[0].addr),
      values.len.gint64,
      nil,
      0,
      errorBuffer.addr,
    )
  else:
    # Fallback to individual appends for unsupported batch operations
    for val in values:
      builder.append(val)

# Core functionality remains the same
proc finish*[T](builder: var ArrayBuilder[T]): Array[T] =
  var errorBuffer: ptr Gerror
  result =
    Array[T](handle: garrow_array_builder_finish(builder.handle, errorBuffer.addr))

proc `destroy=`(builder: ArrayBuilder) =
  if not isNil(builder.handle):
    g_object_unref(builder.handle)

proc `destroy=`(ar: Array) =
  if not isNil(ar.handle):
    g_object_unref(ar.handle)

proc newArray*[T](values: sink seq[T]): Array[T] =
  var errorBuffer: ptr Gerror
  var builder = newArrayBuilder[T]()
  builder.appendValues(values)
  result = builder.finish()

proc len*(ar: Array): int =
  return garrow_array_get_length(ar.handle)

proc `[]`*[T](arr: Array[T], i: int): T =
  when T is bool:
    let val =
      garrow_boolean_array_get_value(cast[ptr GArrowBooleanArray](arr.handle), i)
    return val != 0
  elif T is int8:
    return garrow_int8_array_get_value(cast[ptr GArrowInt8Array](arr.handle), i)
  elif T is uint8:
    return garrow_uint8_array_get_value(cast[ptr GArrowUInt8Array](arr.handle), i)
  elif T is int16:
    return garrow_int16_array_get_value(cast[ptr GArrowInt16Array](arr.handle), i)
  elif T is uint16:
    return garrow_uint16_array_get_value(cast[ptr GArrowUInt16Array](arr.handle), i)
  elif T is int32:
    return garrow_int32_array_get_value(cast[ptr GArrowInt32Array](arr.handle), i)
  elif T is uint32:
    return garrow_uint32_array_get_value(cast[ptr GArrowUInt32Array](arr.handle), i)
  elif T is int64:
    return garrow_int64_array_get_value(cast[ptr GArrowInt64Array](arr.handle), i)
  elif T is uint64:
    return garrow_uint64_array_get_value(cast[ptr GArrowUInt64Array](arr.handle), i)
  elif T is float32:
    return garrow_float_array_get_value(cast[ptr GArrowFloatArray](arr.handle), i)
  elif T is float64:
    return garrow_double_array_get_value(cast[ptr GArrowDoubleArray](arr.handle), i)
  elif T is string:
    let cstr =
      garrow_string_array_get_string(cast[ptr GArrowStringArray](arr.handle), i)
    return $cstr
  else:
    {.error: "Unsupported array type for indexing".}

proc isNull*[T](arr: Array[T], i: int): bool =
  return garrow_array_is_null(arr.handle, i) != 0

proc isValid*[T](arr: Array[T], i: int): bool =
  return garrow_array_is_valid(arr.handle, i) != 0

# Safe getter with Option-like semantics
proc tryGet*[T](arr: Array[T], i: int): Option[T] =
  if i < 0 or i >= arr.len:
    return none(T)
  if arr.isNull(i):
    return none(T)
  return some(arr[i])

# Slice getter for ranges
proc `[]`*[T](arr: Array[T], slice: HSlice[int, int]): Array[T] =
  var errorBuffer: ptr Gerror
  let start = slice.a
  let length = slice.b - slice.a + 1
  result.handle =
    garrow_array_slice(arr.handle, start.gint64, length.gint64, errorBuffer.addr)

iterator items*[T](arr: Array[T]): lent T =
  for i in 0 ..< arr.len:
    yield arr[i]

proc `@`*[T](arr: Array[T]): seq[T] =
  arr.toSeq

proc `$`*[T](arr: Array[T]): string =
  var err: ptr Gerror
  let arrString = garrow_array_to_string(arr.handle, err.addr)
  if err != nil:
    result = $err.message
    gErrorFree(err)
  else:
    result = $arrString
    gfree(arrString)

# Testing the extended functionality
when isMainModule:
  var buffer = newArray(@[29'i32, 2929'i32, 2929292'i32])
  echo "Int32 Array: ", buffer

  var stringBuffer = newArray(@["hello", "world", "arrow"])
  echo "String Array: ", stringBuffer

  var floatBuffer = newArray(@[3.14'f32, 2.71'f32, 1.41'f32])
  echo "Float32 Array: ", floatBuffer

  let intArray = newArray(@[1'i32, 2'i32, 3'i32, 4'i32])
  echo "intArray[1] = ", intArray[1]

  # Test null checking
  echo "Is null at index 1: ", intArray.isNull(1)
  echo "Is valid at index 1: ", intArray.isValid(1)

  echo "string"
  var builder = newArrayBuilder[string]()
  for i in 0 .. 10:
    builder.append($i)
  let arr = builder.finish()
  echo arr
