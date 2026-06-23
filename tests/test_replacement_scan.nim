import std/[strutils, tables]
import unittest2
import ../src/[ffi, database, query, query_result, exceptions]

type
  MyBaseNumber = ref object
    number: int

proc destroyBaseNumber(data: pointer) {.cdecl.} =
  if data != nil:
    let num = cast[MyBaseNumber](data)
    # In Nim with ref objects, GC handles cleanup automatically

# Scanner callback that converts table names to numbers and uses range function
proc numberScanner(info: duckdb_replacement_scan_info; tableName: cstring; data: pointer) {.cdecl.} =
  # Check if the table name is a number
  let tableNameStr = $tableName
  var number: int64

  try:
    number = parseInt(tableNameStr).int64
  except ValueError:
    # Not a number, return without setting replacement
    return

  let numData = cast[MyBaseNumber](data)

  duckdb_replacement_scan_set_function_name(info, "range")

  let val = duckdb_create_int64(number + numData.number.int64)
  duckdb_replacement_scan_add_parameter(info, val)
  duckdb_destroy_value(val.addr)

proc errorReplacementScan(info: duckdb_replacement_scan_info; tableName: cstring; data: pointer) {.cdecl.} =
  duckdb_replacement_scan_set_error(nil, nil)
  duckdb_replacement_scan_set_error(info, nil)
  duckdb_replacement_scan_set_error(info, "my custom error in replacement scan")

suite "Test replacement scans":

  test "Test replacement scans in C API":
    let
      db = newDatabase()
      conn = db.connect()

    let baseNumber = MyBaseNumber(number: 3)

    duckdb_add_replacement_scan(
      db.handle,
      numberScanner,
      cast[pointer](baseNumber),
      destroyBaseNumber
    )

    # Test with base number = 3, table name "2" -> range(5) -> 0,1,2,3,4
    let result1 = conn.execute("SELECT * FROM \"2\"").fetchall()
    check result1[0].valueBigInt.len == 5
    check result1[0].valueBigInt == @[0'i64, 1'i64, 2'i64, 3'i64, 4'i64]

    baseNumber.number = 1

    # Test with base number = 1, table name "2" -> range(3) -> 0,1,2
    let result2 = conn.execute("SELECT * FROM \"2\"").fetchall()
    check result2[0].valueBigInt.len == 3
    check result2[0].valueBigInt == @[0'i64, 1'i64, 2'i64]

    expect(OperationError):
      discard conn.execute("SELECT * FROM nonexistant")

  test "Test error replacement scan":
    let
      db = newDatabase()
      conn = db.connect()

    # Add error replacement scan callback
    duckdb_add_replacement_scan(
      db.handle,
      errorReplacementScan,
      nil,
      nil
    )

    expect(OperationError):
      discard conn.execute("SELECT * FROM nonexistant")


# TODO: add add higher level implemetation, add tests for higher level
