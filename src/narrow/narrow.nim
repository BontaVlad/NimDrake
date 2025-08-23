import strutils

import ./[api, garray]

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
