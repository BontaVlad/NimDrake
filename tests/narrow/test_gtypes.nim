import unittest2
import ../../src/narrow/[gtypes]

suite "Test GArrow types":

  test "Test basic types":
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
