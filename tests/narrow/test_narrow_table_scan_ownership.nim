import unittest2

when defined(features.nimdrake.arrow):
  import narrow
  import ../../src/database

  include ../../src/narrow_table_scan

  var releaseCalls = 0
  var originalRelease: proc(array: ptr ArrowArray) {.cdecl.}

  proc countedRelease(array: ptr ArrowArray) {.cdecl.} =
    inc releaseCalls
    originalRelease(array)

  suite "narrow table scan — Arrow ownership":
    test "conversion failure releases an untransferred ArrowArray":
      let schema = newSchema([newField[int64]("x")])
      let batch = newRecordBatch(schema, newArray[int64](@[1'i64, 2]))
      let conn = newDatabase().connect()

      var failed = false
      try:
        discard convertWindow(
          conn.rawHandle,
          batch,
          duckdb_arrow_converted_schema(nil),
        )
      except CatchableError:
        failed = true
      check failed

    test "exported ArrowArray release callback runs once":
      let schema = newSchema([newField[int64]("x")])
      let batch = newRecordBatch(schema, newArray[int64](@[1'i64, 2]))
      let cAbiArray = exportArrayForScan(batch)
      let array = cast[ptr ArrowArray](cAbiArray)
      originalRelease = array.release
      array.release = countedRelease
      array.release(array)
      check releaseCalls == 1
      g_free(cAbiArray)

else:
  echo "Skipping narrow table scan ownership tests: arrow feature not enabled"
