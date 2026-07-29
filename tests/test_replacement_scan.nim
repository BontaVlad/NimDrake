import std/strutils
import unittest2
import ../src/[ffi, database, query, qresult, types, exceptions, replacement_scans]

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
    let res2 = conn.execute("SELECT * FROM \"2\"")
    for chunk in res2:
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

# ---------------------------------------------------------------------------
# Nim-API tests
# ---------------------------------------------------------------------------

suite "Test replacement scans (Nim API)":

  test "Basic Nim scan — numeric table name → range":
    let
      db = newDatabase()
      conn = db.connect()

    let scan = newReplacementScan(
      proc(info: ReplacementScanInfo, tableName: string, data: pointer) {.cdecl.} =
        try:
          let n = parseInt(tableName).int64
          info.setFunctionName("range")
          info.addParameter(n)
        except ValueError:
          discard
    )
    db.register(scan)

    let res = conn.execute(""" SELECT * FROM "3" """)
    for chunk in res:
      let vals = chunk.bindAs(0, DuckType.BigInt).toSeq
      check vals.len == 3
      check vals == @[0'i64, 1'i64, 2'i64]

    expect(OperationError):
      discard conn.execute("SELECT * FROM nonexistant")

  test "registerReplacementScan macro — same as basic scan":
    let
      db = newDatabase()
      conn = db.connect()

    proc macroScan(info: ReplacementScanInfo, tableName: string, data: pointer) =
      try:
        let n = parseInt(tableName).int64
        info.setFunctionName("range")
        info.addParameter(n)
      except ValueError:
        discard

    registerReplacementScan(db, macroScan)

    let res = conn.execute(""" SELECT * FROM "4" """)
    for chunk in res:
      let vals = chunk.bindAs(0, DuckType.BigInt).toSeq
      check vals.len == 4
      check vals == @[0'i64, 1'i64, 2'i64, 3'i64]

  test "Typed addParameter — int64 + string via repeat function":
    let
      db = newDatabase()
      conn = db.connect()

    let scan = newReplacementScan(
      proc(info: ReplacementScanInfo, tableName: string, data: pointer) {.cdecl.} =
        if tableName == "repeater":
          info.setFunctionName("repeat")
          info.addParameter("hello")
          info.addParameter(3'i64)
    )
    db.register(scan)

    let res = conn.execute(""" SELECT * FROM repeater """)
    for chunk in res:
      let vals = chunk.bindAs(0, DuckType.Varchar).toSeq
      check vals.len == 3
      check vals == @["hello", "hello", "hello"]

  test "Typed addParameter — float64 + int32 via range":
    let
      db = newDatabase()
      conn = db.connect()

    let scan = newReplacementScan(
      proc(info: ReplacementScanInfo, tableName: string, data: pointer) {.cdecl.} =
        try:
          let n = parseInt(tableName)
          info.setFunctionName("range")
          info.addParameter(n.int32)
        except ValueError:
          discard
    )
    db.register(scan)

    let res = conn.execute(""" SELECT * FROM "2" """)
    for chunk in res:
      let vals = chunk.bindAs(0, DuckType.BigInt).toSeq
      check vals.len == 2

  test "Nim exception in callback → OperationError":
    let
      db = newDatabase()
      conn = db.connect()

    let scan = newReplacementScan(
      proc(info: ReplacementScanInfo, tableName: string, data: pointer) {.cdecl.} =
        raise newException(ValueError, "boom in scan")
    )
    db.register(scan)

    expect(OperationError):
      discard conn.execute("SELECT * FROM anything")

  test "setError helper surfaces in OperationError":
    let
      db = newDatabase()
      conn = db.connect()

    let scan = newReplacementScan(
      proc(info: ReplacementScanInfo, tableName: string, data: pointer) {.cdecl.} =
        info.setError("custom replacement scan failure")
    )
    db.register(scan)

    try:
      discard conn.execute("SELECT * FROM anything")
      check false
    except OperationError as e:
      check "custom replacement scan failure" in e.msg

  test "extraData carry-through with GC safety":
    type
      MyScanData = ref object of RootObj
        offset: int

    let
      db = newDatabase()
      conn = db.connect()

    let scan = newReplacementScan(
      proc(info: ReplacementScanInfo, tableName: string, data: pointer) {.cdecl.} =
        let sd = cast[MyScanData](data)
        try:
          let n = parseInt(tableName).int64
          info.setFunctionName("range")
          info.addParameter(n + sd.offset.int64)
        except ValueError:
          discard
      , extraData = MyScanData(offset: 10)
    )
    db.register(scan)

    # Query with table name "2" → range(12) → 12 rows [0..11]
    let res = conn.execute(""" SELECT * FROM "2" """)
    for chunk in res:
      let vals = chunk.bindAs(0, DuckType.BigInt).toSeq
      check vals.len == 12
      check vals == @[0'i64, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

    GC_fullCollect()
    # Should still work after full GC — validates GC_ref pin
    let res2 = conn.execute(""" SELECT * FROM "2" """)
    for chunk in res2:
      let vals = chunk.bindAs(0, DuckType.BigInt).toSeq
      check vals.len == 12

  test "Fall-through — scan that never calls setFunctionName":
    let
      db = newDatabase()
      conn = db.connect()

    # Register a pass-through scan first
    let scan = newReplacementScan(
      proc(info: ReplacementScanInfo, tableName: string, data: pointer) {.cdecl.} =
        discard  # never calls setFunctionName → fall through
    )
    db.register(scan)

    # Then register the actual handling scan
    let scan2 = newReplacementScan(
      proc(info: ReplacementScanInfo, tableName: string, data: pointer) {.cdecl.} =
        try:
          let n = parseInt(tableName).int64
          info.setFunctionName("range")
          info.addParameter(n)
        except ValueError:
          discard
    )
    db.register(scan2)

    # Query should reach the second scan
    let res = conn.execute(""" SELECT * FROM "3" """)
    for chunk in res:
      let vals = chunk.bindAs(0, DuckType.BigInt).toSeq
      check vals.len == 3
      check vals == @[0'i64, 1'i64, 2'i64]

    # A non-matching name should fail (both scans return without setFunctionName)
    expect(OperationError):
      discard conn.execute("SELECT * FROM no_such_table_xyz")

  test "Multiple databases — scans are per-database":
    let
      db1 = newDatabase()
      conn1 = db1.connect()
      db2 = newDatabase()
      conn2 = db2.connect()

    let scan = newReplacementScan(
      proc(info: ReplacementScanInfo, tableName: string, data: pointer) {.cdecl.} =
        try:
          let n = parseInt(tableName).int64
          info.setFunctionName("range")
          info.addParameter(n + 100)
        except ValueError:
          discard
    )
    db1.register(scan)

    for chunk in conn1.execute(""" SELECT * FROM "1" """):
      check chunk.bindAs(0, DuckType.BigInt).toSeq.len == 101

    expect(OperationError):
      discard conn2.execute(""" SELECT * FROM "1" """)
