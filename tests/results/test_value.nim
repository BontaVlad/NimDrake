import unittest
import ../../src/[api, types, value]

suite "Tests Value":
  test "Test Value Big Int":
    let val = newValue(DuckType.BigInt, true, 10'i64)
    assert $val == "10"

  test "Test DuckValue varchar":
    let
      dVal = newDuckValue(duckdb_create_varchar("My duck value".cstring))
      val = newValue(dVal)
    assert $val == "My duck value"

  test "Test numeric DuckType conversion":
    let
      intDuckValue = duckdb_create_int32(42)
      dVal = newDuckValue(intDuckValue)
      val = newValue(dVal)
    assert val.valueInteger == 42

  test "Test boolean DuckType conversion":
    let
      trueDuckValue = duckdb_create_bool(true)
      falseDuckValue = duckdb_create_bool(false)
      trueValue = newValue(newDuckValue(trueDuckValue))
      falseValue = newValue(newDuckValue(falseDuckValue))
    assert trueValue.valueBoolean == true
    assert falseValue.valueBoolean == false

  test "Test float DuckType conversion":
    let
      floatDuckValue = duckdb_create_float(3.14'f32)
      val = newValue(newDuckValue(floatDuckValue))
    assert val.valueFloat == 3.14'f32

  test "Test double DuckType conversion":
    let
      doubleDuckValue = duckdb_create_double(2.71828'f64)
      val = newValue(newDuckValue(doubleDuckValue))
    assert val.valueDouble == 2.71828'f64

  test "Test unsigned integer DuckType conversions":
    let
      tinyIntDuckValue = duckdb_create_uint8(255'u8)
      smallIntDuckValue = duckdb_create_uint16(65535'u16)
      integerDuckValue = duckdb_create_uint32(4294967295'u32)
      bigIntDuckValue = duckdb_create_uint64(18446744073709551615'u64)
    assert newValue(newDuckValue(tinyIntDuckValue)).valueUTinyint == 255'u8
    assert newValue(newDuckValue(smallIntDuckValue)).valueUSmallint == 65535'u16
    assert newValue(newDuckValue(integerDuckValue)).valueUInteger == 4294967295'u32
    assert newValue(newDuckValue(bigIntDuckValue)).valueUBigint ==
      18446744073709551615'u64
