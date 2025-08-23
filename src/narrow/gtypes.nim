import ./[api]

# Primitive type: A type that has no child types and so consists of a single array, such
# as fixed-bit-width arrays (for example, int32) or variable-size types (for example,
# string arrays).
#
# Nested type: A type that depends on one or more other child types. Nested types
# are only equal if their child types are also equal (for example, List<T> and
# List<U> are equal if T and U are equal).
#
# Logical type: A particular type of interpreting the values in an array that is
# implemented using a specific physical layout. For example, the decimal logical
# type stores values as 16 bytes per value in a fixed-size binary layout. Similarly,
# a timestamp logical type stores values using a 64-bit fixed-size layout.
#
# +-------------------+-----------+----------------+---------+-------------------------------------+
# | Layout Type       | Buffer 0  | Buffer 1       | Buffer 2| Children                            |
# +-------------------+-----------+----------------+---------+-------------------------------------+
# | Primitive         | Bitmap    | Data           |         | No                                  |
# | Variable Binary   | Bitmap    | Offsets        | Data    | No                                  |
# | List              | Bitmap    | Offsets        |         | 1                                   |
# | Fixed-Size List   | Bitmap    |                |         | 1                                   |
# | Struct            | Bitmap    |                |         | 1 per field                         |
# | Sparse Union      | Type IDs  |                |         | 1 per type                          |
# | Dense Union       | Type IDs  | Offsets        |         | 1 per type                          |
# | Null              |           |                |         | No                                  |
# | Dictionary Encoded| Bitmap    | Data (Indices) |         | Dictionary (not considered a child) |
# +-------------------+-----------+----------------+---------+-------------------------------------+

# • Null logical type: Null physical type
# • Boolean: Primitive array with data represented as a bitmap
# • Primitive integer types: Primitive, fixed-size array layout:
#     Int8, Uint8, Int16, Uint16, Int32, Uint32, Int64, and Uint64
# • Floating-point types: Primitive fixed-size array layout:
#     Float16, Float32 (float), and Float64 (double)
# • VarBinary types: Variable length binary physical layout:
#     Binary and String (UTF-8)
#     LargeBinary and LargeString (variable length binary with 64-bit offsets)
# • Decimal128 and Decimal256: 128-bit and 256-bit fixed-size primitive arrays
# with metadata to specify the precision and scale of the values
# • Fixed-size binary: Fixed-size binary physical layout
# • Temporal types: Primitive fixed-size array physical layout
#   Date types: Dates with no time information:
#   Date32: 32-bit integers representing the number of days since the Unix epoch
# (1970-01-01)
#   Date64: 64-bit integers representing milliseconds since the Unix epoch
# (1970-01-01)
#   Time types: Time information with no date attached:
#   Time32: 32-bit integers representing elapsed time since midnight as seconds or
# milliseconds. A unit specified by metadata.
#   Time64: 64-bit integers representing elapsed time since midnight as
# microseconds or nanoseconds. A unit specified by metadata.
#   Timestamp: 64-bit integer representing the time since the Unix epoch, not
# including leap seconds. Metadata defines the unit (seconds, milliseconds,
# microseconds, or nanoseconds) and, optionally, a time zone as a string.
#    Interval types: An absolute length of time in terms of calendar artifacts:
#    YearMonth: Number of elapsed whole months as a 32-bit signed integer.
#    DayTime: Number of elapsed days and milliseconds as two consecutive 4-byte
# signed integers (8-bytes total per value).
#    MonthDayNano: Elapsed months, days, and nanoseconds stored as contiguous
# 16-byte blocks. Months and days as two 32-bit integers and nanoseconds since
# midnight as a 64-bit integer.
#    Duration: An absolute length of time not related to calendars as a 64-bit
# integer and a unit specified by metadata indicating seconds, milliseconds,
# microseconds, or nanoseconds.
# • List and FixedSizeList: Their respective physical layouts:
#    LargeList: A list type with 64-bit offsets
# • Struct, DenseUnion, and SparseUnion types: Their respective physical layouts
# • Map: A logical type that is physically represented as List<entries:
# Struct<key: K, value: V>>, where K and V are the respective types of the
# keys and values in the map:
#   Metadata is included indicating whether or not the keys are sorted.

type
  GADType*[T] = distinct ptr GArrowDataType
  GListWrapper*[T] = object
    list*: ptr GList
    owned: bool  # Whether this wrapper owns the list and should free it

converter toArrowType*(g: GADType): ptr GArrowDataType =
  cast[ptr GArrowDataType](g)

proc `destroy=`(tp: GADType) =
  if not isNil(GADType.addr):
    g_object_unref(GADType.addr)

proc `$`*(tp: GADType): string =
  # let gStr = garrow_data_type_to_string(tp)
  let gStr = garrow_data_type_get_name(cast[ptr GArrowDataType](tp))
  result = $gStr
  gFree(gStr)

proc newGType*(T: typedesc): GADType[T] =
  when T is bool:
    result = GADType[T](cast[ptr GArrowDataType](garrow_boolean_data_type_new()))
  elif T is int8:
    result = GADType[T](cast[ptr GArrowDataType](garrow_int8_data_type_new()))
  elif T is uint8:
    result = GADType[T](cast[ptr GArrowDataType](garrow_uint8_data_type_new()))
  elif T is int16:
    result = GADType[T](cast[ptr GArrowDataType](garrow_int16_data_type_new()))
  elif T is uint16:
    result = GADType[T](cast[ptr GArrowDataType](garrow_uint16_data_type_new()))
  elif T is int32:
    result = GADType[T](cast[ptr GArrowDataType](garrow_int32_data_type_new()))
  elif T is uint32:
    result = GADType[T](cast[ptr GArrowDataType](garrow_uint32_data_type_new()))
  elif T is int64 or T is int:
    result = GADType[T](cast[ptr GArrowDataType](garrow_int64_data_type_new()))
  elif T is uint64:
    result = GADType[T](cast[ptr GArrowDataType](garrow_uint64_data_type_new()))
  elif T is float32:
    result = GADType[T](cast[ptr GArrowDataType](garrow_float_data_type_new()))
  elif T is float64:
    result = GADType[T](cast[ptr GArrowDataType](garrow_double_data_type_new()))
  elif T is string:
    result = GADType[T](cast[ptr GArrowDataType](garrow_string_data_type_new()))
  elif T is seq[byte]:
    result = GADType[T](cast[ptr GArrowDataType](garrow_binary_data_type_new()))
  elif T is cstring:
    result = GADType[T](cast[ptr GArrowDataType](garrow_large_string_data_type_new()))
  # elif T is Date32:
  #   result = GADType[T](cast[ptr GArrowDataType](garrow_date32_data_type_new()))
  # elif T is Date64:
  #   result = GADType[T](cast[ptr GArrowDataType](garrow_date64_data_type_new()))
  # elif T is Timestamp:
  #   result = GADType[T](cast[ptr GArrowDataType](garrow_timestamp_data_type_new()))
  # elif T is Time32:
  #   result = GADType[T](cast[ptr GArrowDataType](garrow_time32_data_type_new()))
  # elif T is Time64:
  #   result = GADType[T](cast[ptr GArrowDataType](garrow_time64_data_type_new()))
  # elif T is MonthInterval:
  #   result = GADType[T](cast[ptr GArrowDataType](garrow_month_interval_data_type_new()))
  # elif T is DayTimeInterval:
  #   result = GADType[T](cast[ptr GArrowDataType](garrow_day_time_interval_data_type_new()))
  # elif T is MonthDayNanoInterval:
  #   result = GADType[T](cast[ptr GArrowDataType](garrow_month_day_nano_interval_data_type_new()))
  # elif T is Decimal:
  #   result = GADType[T](cast[ptr GArrowDataType](garrow_decimal_data_type_new()))
  # elif T is Decimal128:
  #   result = GADType[T](cast[ptr GArrowDataType](garrow_decimal128_data_type_new()))
  # elif T is Decimal256:
  #   result = GADType[T](cast[ptr GArrowDataType](garrow_decimal256_data_type_new()))
  # elif T is ExtensionDataType:
  #   static: doAssert false, "newGType: ExtensionDataType must be handled explicitly via registration/lookup."
  else:
    static: doAssert false, "newGType: unsupported type for automatic Arrow GType construction."

proc `=destroy`*[T](wrapper: var GListWrapper[T]) =
  if wrapper.owned and wrapper.list != nil:
    g_list_free(wrapper.list)

proc `=copy`*[T](dest: var GListWrapper[T], source: GListWrapper[T]) =
  dest.list = source.list
  dest.owned = false  # Copies are never owning to avoid double-free

proc `=sink`*[T](dest: var GListWrapper[T], source: GListWrapper[T]) =
  dest.list = source.list
  dest.owned = source.owned

# Constructor from existing GList (non-owning by default)
proc newGList*[T](list: ptr GList, owned: bool = false): GListWrapper[T] =
  GListWrapper[T](list: list, owned: owned)

# Create a new empty list (owning)
proc newGList*[T](): GListWrapper[T] =
  GListWrapper[T](list: nil, owned: true)

proc len*[T](wrapper: GListWrapper[T]): int =
  if wrapper.list == nil:
    0
  else:
    int(g_list_length(wrapper.list))

proc append*[T](wrapper: var GListWrapper[T], data: T) =
  wrapper.list = g_list_append(wrapper.list, cast[gpointer](data))

proc prepend*[T](wrapper: var GListWrapper[T], data: T) =
  wrapper.list = g_list_prepend(wrapper.list, cast[gpointer](data))

proc `[]`*[T](wrapper: GListWrapper[T], index: int): T =
  let node = g_list_nth(wrapper.list, cuint(index))
  if node == nil:
    raise newException(IndexDefect, "Index out of bounds")
  cast[T](node.data)

iterator items*[T](wrapper: GListWrapper[T]): T =
  var current = wrapper.list
  while current != nil:
    yield cast[T](current.data)
    current = current.next

proc newGList*[T](items: openArray[T]): GListWrapper[T] =
  var lst = newGList[T]()
  for i in items:
    lst.append(i)
  result = lst

when isMainModule:
  let gBoolType = newGType(bool)
  echo $gBoolType

  let gInt8Type = newGType(int8)
  echo $gInt8Type

  let gUint8Type = newGType(uint8)
  echo $gUint8Type

  let gInt16Type = newGType(int16)
  echo $gInt16Type

  let gUint16Type = newGType(uint16)
  echo $gUint16Type

  let gInt32Type = newGType(int32)
  echo $gInt32Type

  let gUint32Type = newGType(uint32)
  echo $gUint32Type

  let gInt64Type = newGType(int64)
  echo $gInt64Type

  let gIntType = newGType(int)
  echo $gIntType

  let gUint64Type = newGType(uint64)
  echo $gUint64Type

  let gFloat32Type = newGType(float32)
  echo $gFloat32Type

  let gFloat64Type = newGType(float64)
  echo $gFloat64Type

  let gStringType = newGType(string)
  echo $gStringType

  let gBytesType = newGType(seq[byte])
  echo $gBytesType

  let gCstringType = newGType(cstring)
  echo $gCstringType

  var myList = newGList[uint8]()
  # myList.prepend(1)
  myList.append(2)
  myList.append(3)
  myList.append(4)
  myList.append(5)
  echo myList[0]

  for e in myList:
    echo e

  # let gDate32Type = newGType(Date32)
  # echo $gDate32Type

  # let gDate64Type = newGType(Date64)
  # echo $gDate64Type

  # let gTimestampType = newGType(Timestamp)
  # echo $gTimestampType

  # let gTime32Type = newGType(Time32)
  # echo $gTime32Type

  # let gTime64Type = newGType(Time64)
  # echo $gTime64Type

  # let gMonthIntervalType = newGType(MonthInterval)
  # echo $gMonthIntervalType

  # let gDayTimeIntervalType = newGType(DayTimeInterval)
  # echo $gDayTimeIntervalType

  # let gMonthDayNanoIntervalType = newGType(MonthDayNanoInterval)
  # echo $gMonthDayNanoIntervalType

  # let gDecimalType = newGType(Decimal)
  # echo $gDecimalType

  # let gDecimal128Type = newGType(Decimal128)
  # echo $gDecimal128Type

  # let gDecimal256Type = newGType(Decimal256)
  # echo $gDecimal256Type
