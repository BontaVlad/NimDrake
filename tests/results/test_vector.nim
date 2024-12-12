import std/[unittest, times]
import ../../src/[types, vector, value]

suite "Tests Vector":
  test "Test newDuckType from typedesc":
    let kind = newDuckType(int)
    assert kind == DuckType.Integer

  test "Test newVector from seq":
    let myVector = newVector(@[10, 20, 30])
    assert $myVector == "@[10, 20, 30]"

  test "Test newDuckType basic types":
    assert newDuckType(bool) == DuckType.Boolean
    assert newDuckType(int8) == DuckType.TinyInt
    assert newDuckType(int16) == DuckType.SmallInt
    assert newDuckType(int32) == DuckType.Integer
    assert newDuckType(int64) == DuckType.BigInt
    assert newDuckType(uint8) == DuckType.UTinyInt
    assert newDuckType(uint16) == DuckType.USmallInt
    assert newDuckType(uint32) == DuckType.UInteger
    assert newDuckType(uint64) == DuckType.UBigInt
    assert newDuckType(float32) == DuckType.Float
    assert newDuckType(float64) == DuckType.Double
    assert newDuckType(string) == DuckType.Varchar

  test "Test newDuckType complex types":
    assert newDuckType(seq[byte]) == DuckType.Blob
    assert newDuckType(Time) == DuckType.Time
    assert newDuckType(DateTime) == DuckType.Timestamp
    assert newDuckType(tuple) == DuckType.Struct
    assert newDuckType(seq[int]) == DuckType.List
    assert newDuckType(void) == DuckType.SqlNull

  test "Test newDuckType invalid type":
    type InvalidType = object
    assert newDuckType(InvalidType) == DuckType.Invalid

  # Tests for newVector
  test "Test newVector from integer sequence":
    let myVector = newVector(@[10, 20, 30])
    assert $myVector == "@[10, 20, 30]"

  test "Test newVector from float sequence":
    let myVector = newVector(@[3.14, 2.718, 1.618])
    assert $myVector == "@[3.14, 2.718, 1.618]"

  test "Test newVector from string sequence":
    let myVector = newVector(@["hello", "world"])
    assert $myVector == """@["hello", "world"]"""

  test "Test newVector from empty sequence":
    let myVector = newVector(newSeq[int]())
    assert $myVector == "@[]"
