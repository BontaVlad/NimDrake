import std/[enumerate]
import unittest2
import ../../src/narrow/[garray, gchunkedarray]

suite "Test Chunked Arrays construction":

  test "Test new chunked array":
    # Create some arrays
    let arr1 = newArray(@[1'i32, 2'i32, 3'i32])
    let arr2 = newArray(@[4'i32, 5'i32, 6'i32])
    let arr3 = newArray(@[7'i32, 8'i32, 9'i32])

    # Create chunked array
    let chunkedArr = newChunkedArray(@[arr1, arr2, arr3])

    check chunkedArr.len == 9
    check chunkedArr.getNChunks() == 3 # "Number of chunks"
    check chunkedArr.getNNulls() == 0  # "Number of nulls"

    # Access individual elements
    # echo "Element at index 5: ", chunkedArr[int32](5)

    # Iterate through chunks
    # for i, chunk in enumerate(chunkedArr.chunks[int32]()):
    #     echo "Chunk ", i, ": ", chunk

    # # Convert to single array
    # let combined = chunkedArr.combine[int32]()
    # echo "Combined array: ", combined

    # # Slice the chunked array
    # let sliced = chunkedArr.slice(2'u64, 4'u64)
    # echo "Sliced array: ", sliced
