import std/[times, tables]
import unittest2
import uuid4
import nint128
import ../src/[api, types, value]

suite "Tests value creations":
  test "Create Boolean Value":
    let valTrue = newValue(true)
    check valTrue.valueBoolean == true
    let valFalse = newValue(false)
    check valFalse.valueBoolean == false

  test "Create int8 value":
    let val = newValue(10'i8)
    check val.kind == DuckType.TinyInt
    check val.valueTinyint == 10

  test "Create int16 value":
    let val = newValue(300'i16)
    check val.kind == DuckType.SmallInt
    check val.valueSmallint == 300

  test "Create int32 value":
    let val = newValue(100000'i32)
    check val.kind == DuckType.Integer
    check val.valueInteger == 100000

  test "Create int64 value":
    let val = newValue(10000000000'i64)
    check val.kind == DuckType.BigInt
    check val.valueBigint == 10000000000

  test "Create Int128 value":
    let hugeIntVal = i128("-18446744073709551616")
    let val = newValue(hugeIntVal)
    check val.kind == DuckType.HugeInt
    check val.valueHugeInt == hugeIntVal

  test "Create uint8 value":
    let val = newValue(255'u8)
    check val.kind == DuckType.UTinyInt
    check val.valueUTinyint == 255

  test "Create uint16 value":
    let val = newValue(65535'u16)
    check val.kind == DuckType.USmallInt
    check val.valueUSmallint == 65535

  test "Create uint32 value":
    let val = newValue(4294967295'u32)
    check val.kind == DuckType.UInteger
    check val.valueUInteger == 4294967295'u32

  test "Create uint64 value":
    let val = newValue(18446744073709551'u64)
    check val.kind == DuckType.UBigInt
    check val.valueUBigint == 18446744073709551'u64

  test "Create float32 value":
    let val = newValue(3.14'f32)
    check val.kind == DuckType.Float
    check val.valueFloat == 3.14'f32

  test "Create float64 value":
    let val = newValue(2.718281828459045'f64)
    check val.kind == DuckType.Double
    check val.valueDouble == 2.718281828459045

  test "Create DateTime value as Timestamp":
    let inThisMoment = Timestamp(now())
    let val = newValue(inThisMoment, DuckType.Timestamp)
    check val.kind == DuckType.Timestamp

  test "Create Time value":
    let val = newValue(initTime(1734548229, 0))
    check val.kind == DuckType.Time
    check $val.valueTime.utc == "2024-12-18T18:57:09Z"

  # test "Create ZonedTime value":
  #   let zt = initZonedTime(DateTime.now(), "UTC")
  #   let val = newValue(zt)
  #   check val.kind == DuckType.TimeTz
  #   check val.valueTimeTz.zoneName == "UTC"

  test "Create TimeInterval value":
    let val = newValue(initTimeInterval(days = 1, hours = 2))
    check val.kind == DuckType.Interval
    check val.valueInterval.days == 1

  test "Create Varchar value":
    let val = newValue("Hello")
    check val.kind == DuckType.Varchar
    check val.valueVarchar == "Hello"

  test "Create Bit value":
    let val = newValue("10101", DuckType.Bit)
    check val.kind == DuckType.Bit
    check val.valueBit == "10101"

  test "Create Blob value":
    let val = newValue(@[byte(0x00), byte(0xFF)])
    check val.kind == DuckType.Blob
    check val.valueBlob == @[byte(0x00), byte(0xFF)]

  # TODO: decimal package leaks memory
  # test "Create Decimal value":
  #   let val = newValue(newDecimal("3.14"))
  #   check val.kind == DuckType.Decimal
  #   check $val.valueDecimal == "3.14"

  test "Create Enum value":
    let val = newValue(uint(42), DuckType.Enum)
    check val.kind == DuckType.Enum
    check val.valueEnum == 42

  test "Create List value":
    let val = newValue(@[newValue(true), newValue(123'i16)])
    check val.kind == DuckType.List
    check val.valueList.len == 2

  test "Create Struct value":
    let val = newValue({"key": newValue("value")}.toTable, DuckType.Struct)
    check val.kind == DuckType.Struct
    check val.valueStruct["key"].valueVarchar == "value"

  test "Create Map value":
    let val = newValue({"key": newValue(123'i16)}.toTable, DuckType.Map)
    check val.kind == DuckType.Map
    check val.valueMap["key"].valueSmallint == 123

  test "Create UUID value":
    let uuid = initUuid("550e8400-e29b-41d4-a716-446655440000")
    let val = newValue(uuid)
    check val.kind == DuckType.UUID
    check val.valueUuid == uuid

  test "Test DuckValue varchar":
    let
      dVal = newDuckValue(duckdb_create_varchar("My duck value".cstring))
      val = newValue(dVal)
    check $val == "My duck value"

  test "cstring to DuckString":
    let
      rawString = duckdb_create_varchar("hello from duckdb".cstring)
      myString = newDuckString(duckdb_get_varchar(rawString))
    duckdb_destroy_value(rawString.addr)
    check $myString == "hello from duckdb"

suite "Test conversions":
  test "Test numeric DuckType conversion":
    let
      intDuckValue = duckdb_create_int32(42)
      dVal = newDuckValue(intDuckValue)
      val = newValue(dVal)
    check val.valueInteger == 42

  test "Test boolean DuckType conversion":
    let
      trueDuckValue = duckdb_create_bool(true)
      falseDuckValue = duckdb_create_bool(false)
      trueValue = newValue(newDuckValue(trueDuckValue))
      falseValue = newValue(newDuckValue(falseDuckValue))
    check trueValue.valueBoolean == true
    check falseValue.valueBoolean == false

  test "Test float DuckType conversion":
    let
      floatDuckValue = duckdb_create_float(3.14'f32)
      val = newValue(newDuckValue(floatDuckValue))
    check val.valueFloat == 3.14'f32

  test "Test double DuckType conversion":
    let
      doubleDuckValue = duckdb_create_double(2.71828'f64)
      val = newValue(newDuckValue(doubleDuckValue))
    check val.valueDouble == 2.71828'f64

  test "Test number DuckType conversions":
    let
      tinyIntDuckValue = duckdb_create_uint8(255'u8)
      smallIntDuckValue = duckdb_create_uint16(65535'u16)
      integerDuckValue = duckdb_create_uint32(4294967295'u32)
      bigIntDuckValue = duckdb_create_uint64(18446744073709551615'u64)
    check newValue(newDuckValue(tinyIntDuckValue)).valueUTinyint == 255'u8
    check newValue(newDuckValue(smallIntDuckValue)).valueUSmallint == 65535'u16
    check newValue(newDuckValue(integerDuckValue)).valueUInteger == 4294967295'u32
    check newValue(newDuckValue(bigIntDuckValue)).valueUBigint ==
      18446744073709551615'u64

  test "Test timestamp DuckType conversions":
    let micros = convert(Seconds, Microseconds, 1734685178)
    let dkTimestamp = duckdb_create_timestamp(duckdb_timestamp(micros: micros))
    check $newValue(newDuckValue(dkTimestamp)).valueTimestamp == "2024-12-20T08:59:38Z"

  test "Test date DuckType conversions":
    let dkDate = duckdb_create_date(duckdb_date(days: 20077))
    check $newValue(newDuckValue(dkDate)).valueDate == "2024-12-20T00:00:00Z"

  test "Test interval DuckType conversions":
    let
      startDate = parse("01-01-2000", "dd-MM-yyyy")
      endDate = parse("03-02-2001", "dd-MM-yyyy")
      interval = between(startDate, endDate)
      dkInt = duckdb_interval(
        months: (interval.months + interval.years div 12).int32,
        days: interval.days.int32,
        micros: interval.microseconds.int64,
      )
      dkInterval = duckdb_create_interval(dkInt)

    check $newValue(newDuckValue(dkInterval)).valueInterval == "1 month and 2 days"

  test "Test varchar DuckType conversions":
    let dkString = duckdb_create_varchar("Hello world".cstring)
    check newValue(newDuckValue(dkString)).valueVarchar == "Hello world"
