import std/[strutils, tables]
import unittest2
import ../src/[ffi, database, query, qresult, types, exceptions]

type
  MyBaseNumber = ref object
    number: int

proc destroyBaseNumber(data: pointer) {.cdecl.} =
  if data != nil:
    let num = cast[MyBaseNumber](data)

proc numberScanner(info: duckdb_replacement_scan_info; tableName: cstring; data: pointer) {.cdecl.} =
  let tableNameStr = $tableName
  var number: int64

  try:
    number = parseInt(tableNameStr).int64
  except ValueError:
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
      db.rawHandle,
      numberScanner,
      cast[pointer](baseNumber),
      destroyBaseNumber
    )

    # Test with base number = 3, table name "2" -> range(5) -> 0,1,2,3,4
    let result1 = conn.execute("SELECT * FROM \"2\"")
    for chunk in result1:
      let vals = chunk.bindAs(0, DuckType.BigInt).toSeq
      check vals.len == 5
      check vals == @[0'i64, 1'i64, 2'i64, 3'i64, 4'i64]

    baseNumber.number = 1

    # Test with base number = 1, table name "2" -> range(3) -> 0,1,2
    let result2 = conn.execute("SELECT * FROM \"2\"")
    for chunk in result2:
      let vals = chunk.bindAs(0, DuckType.BigInt).toSeq
      check vals.len == 3
      check vals == @[0'i64, 1'i64, 2'i64]

    expect(OperationError):
      discard conn.execute("SELECT * FROM nonexistant")

  test "Test error replacement scan":
    let
      db = newDatabase()
      conn = db.connect()

    duckdb_add_replacement_scan(
      db.rawHandle,
      errorReplacementScan,
      nil,
      nil
    )

    expect(OperationError):
      discard conn.execute("SELECT * FROM nonexistant")
