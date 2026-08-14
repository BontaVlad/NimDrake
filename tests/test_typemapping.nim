import std/[times]
import unittest2
import nint128
import uuid4
import ../src/[types, qresult, codec]

static:
  doAssert colDuckTypeOf(bool) == DuckType.Boolean
  doAssert colDuckTypeOf(int8) == DuckType.TinyInt
  doAssert colDuckTypeOf(int16) == DuckType.SmallInt
  doAssert colDuckTypeOf(int32) == DuckType.Integer
  doAssert colDuckTypeOf(int64) == DuckType.BigInt
  doAssert colDuckTypeOf(int) == DuckType.BigInt
  doAssert colDuckTypeOf(uint8) == DuckType.UTinyInt
  doAssert colDuckTypeOf(byte) == DuckType.UTinyInt
  doAssert colDuckTypeOf(uint16) == DuckType.USmallInt
  doAssert colDuckTypeOf(uint32) == DuckType.UInteger
  doAssert colDuckTypeOf(uint64) == DuckType.UBigInt
  doAssert colDuckTypeOf(uint) == DuckType.UBigInt
  doAssert colDuckTypeOf(float32) == DuckType.Float
  doAssert colDuckTypeOf(float64) == DuckType.Double
  doAssert colDuckTypeOf(string) == DuckType.Varchar
  doAssert colDuckTypeOf(seq[byte]) == DuckType.Blob
  doAssert colDuckTypeOf(Timestamp) == DuckType.Timestamp
  doAssert colDuckTypeOf(DateTime) == DuckType.Timestamp
  doAssert colDuckTypeOf(Time) == DuckType.Time
  doAssert colDuckTypeOf(TimeInterval) == DuckType.Interval
  doAssert colDuckTypeOf(Int128) == DuckType.HugeInt
  doAssert colDuckTypeOf(UInt128) == DuckType.UHugeInt
  doAssert colDuckTypeOf(Uuid) == DuckType.UUID

suite "type mapping":
  test "static asserts hold": check true
