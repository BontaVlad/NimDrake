## Object ↔ DuckDB STRUCT mapping and `QResult → seq[Object]` binding.
##
## High-level API:
##
##   type User = object
##     homeAddress: string
##     age: int64
##
##   conn.createType(User)                          # DDL + LogicalType
##   let users: seq[User] = conn.execute("SELECT …").toSeq(User)
##   # or chunk.toSeq(User), chunk.bindAs(User)
##
## Column matching by name case-insensitive; extra columns ignored, missing
## non-optional columns raise `ValueError`. Works for Materialized & Streaming.

import std/[options, tables, strutils, times]
import nint128
import uuid4

import ./ffi
import ./types
import ./qresult
import ./codec
import ./database
import ./query
import ./exceptions

proc quoteIdent*(s: string): string =
  result = "\""
  for c in s:
    if c == '"': result.add "\"\""
    else: result.add c
  result.add "\""

# ---------------------------------------------------------------------------
# LogicalType for a Nim type
# ---------------------------------------------------------------------------

proc logicalTypeForImpl[T](_: typedesc[T]): LogicalType

proc logicalTypeFor*[T](_: typedesc[T]): LogicalType =
  logicalTypeForImpl(T)

proc logicalTypeForImpl[T](_: typedesc[T]): LogicalType =
  when T is string:
    newLogicalType(DuckType.Varchar)
  elif T is bool:
    newLogicalType(DuckType.Boolean)
  elif T is int8:
    newLogicalType(DuckType.TinyInt)
  elif T is int16:
    newLogicalType(DuckType.SmallInt)
  elif T is int32:
    newLogicalType(DuckType.Integer)
  elif T is int64 or T is int:
    newLogicalType(DuckType.BigInt)
  elif T is uint8:
    newLogicalType(DuckType.UTinyInt)
  elif T is uint16:
    newLogicalType(DuckType.USmallInt)
  elif T is uint32:
    newLogicalType(DuckType.UInteger)
  elif T is uint64 or T is uint:
    newLogicalType(DuckType.UBigInt)
  elif T is float32:
    newLogicalType(DuckType.Float)
  elif T is float64:
    newLogicalType(DuckType.Double)
  elif T is Int128:
    newLogicalType(DuckType.HugeInt)
  elif T is UInt128:
    newLogicalType(DuckType.UHugeInt)
  elif T is Uuid:
    newLogicalType(DuckType.UUID)
  elif T is DateTime:
    newLogicalType(DuckType.Timestamp)
  elif T is Timestamp:
    newLogicalType(DuckType.Timestamp)
  elif T is Time:
    newLogicalType(DuckType.Time)
  elif T is TimeInterval:
    newLogicalType(DuckType.Interval)
  elif T is seq[byte]:
    newLogicalType(DuckType.Blob)
  elif T is seq:
    when compiles(default(T)[0]):
      type Inner = typeof(default(T)[0])
      let inner = logicalTypeFor(Inner)
      let raw = duckdb_create_list_type(inner.handle)
      newLogicalType(raw)
    else:
      {.error: "logicalTypeFor: unsupported seq element type for " & $T.}
  elif T is Option:
    when compiles(default(T).get()):
      type InnerOpt = typeof(default(T).get())
      logicalTypeFor(InnerOpt)
    else:
      {.error: "logicalTypeFor: cannot unwrap Option type " & $T.}
  elif T is enum:
    # Build ENUM logical type from Nim enum labels
    var labels: seq[string] = @[]
    for v in low(T)..high(T):
      labels.add($v)
    var cstrs = newSeq[cstring](labels.len)
    for i, s in labels: cstrs[i] = s.cstring
    let raw = duckdb_create_enum_type(addr cstrs[0], labels.len.idx_t)
    newLogicalType(raw)
  elif T is object or T is tuple:
    structLogicalType(T)
  else:
    {.error: "logicalTypeFor: unsupported field type " & $T.}

proc structLogicalType*[T: object](_: typedesc[T]): LogicalType =
  var childTypes: seq[duckdb_logical_type] = @[]
  var childNames: seq[cstring] = @[]
  var keep: seq[LogicalType] = @[]
  var dummy: T
  for fname, fval in fieldPairs(dummy):
    let lt = logicalTypeFor(typeof(fval))
    keep.add(lt)
    childTypes.add(lt.handle)
    childNames.add(fname.cstring)
  if childTypes.len == 0:
    raise newException(ValueError, "structLogicalType: object has no fields: " & $T)
  var namePtrs = newSeq[cstring](childNames.len)
  for i, n in childNames: namePtrs[i] = n
  let raw = duckdb_create_struct_type(
    addr childTypes[0], addr namePtrs[0], childTypes.len.idx_t
  )
  result = newLogicalType(raw)
  discard keep

proc structLogicalTypeTuple*[T: tuple](_: typedesc[T]): LogicalType =
  var dummy: T
  var childTypes: seq[duckdb_logical_type] = @[]
  var childNames: seq[cstring] = @[]
  var keep: seq[LogicalType] = @[]
  var idx = 0
  for fname, fval in fieldPairs(dummy):
    let lt = logicalTypeFor(typeof(fval))
    keep.add(lt)
    childTypes.add(lt.handle)
    let n = if fname.len > 0: fname else: "field" & $idx
    childNames.add(n.cstring)
    inc idx
  var namePtrs = newSeq[cstring](childNames.len)
  for i, n in childNames: namePtrs[i] = n
  let raw = duckdb_create_struct_type(
    addr childTypes[0], addr namePtrs[0], childTypes.len.idx_t
  )
  result = newLogicalType(raw)
  discard keep

# ---------------------------------------------------------------------------
# DDL generation
# ---------------------------------------------------------------------------

proc sqlTypeForImpl[T](_: typedesc[T]): string

proc sqlTypeFor*[T](_: typedesc[T]): string =
  sqlTypeForImpl(T)

proc sqlTypeForImpl[T](_: typedesc[T]): string =
  when T is string: "VARCHAR"
  elif T is bool: "BOOLEAN"
  elif T is int8: "TINYINT"
  elif T is int16: "SMALLINT"
  elif T is int32: "INTEGER"
  elif T is int64 or T is int: "BIGINT"
  elif T is uint8: "UTINYINT"
  elif T is uint16: "USMALLINT"
  elif T is uint32: "UINTEGER"
  elif T is uint64 or T is uint: "UBIGINT"
  elif T is float32: "FLOAT"
  elif T is float64: "DOUBLE"
  elif T is Int128: "HUGEINT"
  elif T is UInt128: "UHUGEINT"
  elif T is Uuid: "UUID"
  elif T is DateTime: "TIMESTAMP"
  elif T is Timestamp: "TIMESTAMP"
  elif T is Time: "TIME"
  elif T is TimeInterval: "INTERVAL"
  elif T is seq[byte]: "BLOB"
  elif T is seq:
    when compiles(default(T)[0]):
      type Inner = typeof(default(T)[0])
      sqlTypeFor(Inner) & "[]"
    else:
      {.error: "sqlTypeFor: unsupported seq element " & $T.}
  elif T is Option:
    when compiles(default(T).get()):
      type InnerOpt = typeof(default(T).get())
      sqlTypeFor(InnerOpt)
    else:
      {.error: "sqlTypeFor Option unwrap failed " & $T.}
  elif T is enum:
    var labels: seq[string] = @[]
    for v in low(T)..high(T):
      labels.add("'" & ($v).replace("'", "''") & "'")
    "ENUM (" & labels.join(", ") & ")"
  elif T is object or T is tuple:
    var dummy: T
    var parts: seq[string] = @[]
    for fname, fval in fieldPairs(dummy):
      parts.add(quoteIdent(fname) & " " & sqlTypeFor(typeof(fval)))
    "STRUCT(" & parts.join(", ") & ")"
  else:
    {.error: "sqlTypeFor: unsupported " & $T.}

proc ddlForStruct*[T: object](_: typedesc[T], typeName: string): string =
  var dummy: T
  var parts: seq[string] = @[]
  for fname, fval in fieldPairs(dummy):
    parts.add(quoteIdent(fname) & " " & sqlTypeFor(typeof(fval)))
  "CREATE TYPE " & quoteIdent(typeName) & " AS STRUCT(" & parts.join(", ") & ")"

# ---------------------------------------------------------------------------
# Decode helpers
# ---------------------------------------------------------------------------

proc decodeField*(dst: var string, cv: ColumnView, row: int) =
  if not cv.valid(row):
    raise newException(ValueError, "NULL in non-optional STRING field")
  dst = cv.bindAs(DuckType.Varchar)[row]

proc decodeField*(dst: var bool, cv: ColumnView, row: int) =
  if not cv.valid(row):
    raise newException(ValueError, "NULL in non-optional BOOL field")
  dst = cv.bindAs(DuckType.Boolean)[row]

proc decodeField*(dst: var int8, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional int8 field")
  dst = cv.bindAs(DuckType.TinyInt)[row]

proc decodeField*(dst: var int16, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional int16 field")
  dst = cv.bindAs(DuckType.SmallInt)[row]

proc decodeField*(dst: var int32, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional int32 field")
  dst = cv.bindAs(DuckType.Integer)[row]

proc decodeField*(dst: var int64, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional int64 field")
  dst = cv.bindAs(DuckType.BigInt)[row]

proc decodeField*(dst: var int, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional int field")
  dst = int(cv.bindAs(DuckType.BigInt)[row])

proc decodeField*(dst: var uint8, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional uint8 field")
  dst = cv.bindAs(DuckType.UTinyInt)[row]

proc decodeField*(dst: var uint16, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional uint16 field")
  dst = cv.bindAs(DuckType.USmallInt)[row]

proc decodeField*(dst: var uint32, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional uint32 field")
  dst = cv.bindAs(DuckType.UInteger)[row]

proc decodeField*(dst: var uint64, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional uint64 field")
  dst = cv.bindAs(DuckType.UBigInt)[row]

proc decodeField*(dst: var uint, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional uint field")
  dst = uint(cv.bindAs(DuckType.UBigInt)[row])

proc decodeField*(dst: var float32, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional float32 field")
  dst = cv.bindAs(DuckType.Float)[row]

proc decodeField*(dst: var float64, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional float64 field")
  dst = cv.bindAs(DuckType.Double)[row]

proc decodeField*(dst: var Int128, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional Int128 field")
  dst = cv.bindAs(DuckType.HugeInt)[row]

proc decodeField*(dst: var UInt128, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional UInt128 field")
  dst = cv.bindAs(DuckType.UHugeInt)[row]

proc decodeField*(dst: var Uuid, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional UUID field")
  dst = cv.bindAs(DuckType.UUID)[row]

proc decodeField*(dst: var DateTime, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional DateTime field")
  case cv.kind
  of DuckType.Timestamp:
    dst = DateTime(cv.bindAs(DuckType.Timestamp)[row])
  of DuckType.Date:
    dst = cv.bindAs(DuckType.Date)[row]
  of DuckType.TimestampS:
    dst = cv.bindAs(DuckType.TimestampS)[row]
  of DuckType.TimestampMs:
    dst = cv.bindAs(DuckType.TimestampMs)[row]
  of DuckType.TimestampNs:
    dst = cv.bindAs(DuckType.TimestampNs)[row]
  else:
    raise newException(ValueError, "cannot decode DateTime from " & $cv.kind)

proc decodeField*(dst: var Timestamp, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional Timestamp field")
  dst = cv.bindAs(DuckType.Timestamp)[row]

proc decodeField*(dst: var Time, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional Time field")
  dst = cv.bindAs(DuckType.Time)[row]

proc decodeField*(dst: var TimeInterval, cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional Interval field")
  dst = cv.bindAs(DuckType.Interval)[row]

proc decodeField*[T: enum](dst: var T, cv: ColumnView, row: int) =
  if not cv.valid(row):
    raise newException(ValueError, "NULL in non-optional ENUM field")
  if cv.kind != DuckType.Enum:
    raise newException(ValueError, "expected ENUM for enum field, got " & $cv.kind)
  let v = cv.bindAs(DuckType.Enum)
  let idx = v[row].int
  if idx < ord(low(T)) or idx > ord(high(T)):
    raise newException(ValueError, "enum index out of range: " & $idx & " for " & $T)
  dst = T(idx)

proc decodeField*(dst: var seq[byte], cv: ColumnView, row: int) =
  if not cv.valid(row): raise newException(ValueError, "NULL in non-optional BLOB field")
  dst = cv.bindAs(DuckType.Blob)[row]

proc decodeField*[T](dst: var seq[T], cv: ColumnView, row: int) =
  when T is byte:
    {.error: "seq[byte] handled separately".}
  else:
    if not cv.valid(row):
      raise newException(ValueError, "NULL in non-optional seq field")
    if cv.kind != DuckType.List:
      raise newException(ValueError, "expected LIST for seq field, got " & $cv.kind)
    let lv = cv.bindAs(seq[T])
    dst = lv[row]

proc decodeField*[T](dst: var Option[T], cv: ColumnView, row: int) =
  if not cv.valid(row):
    dst = none(T)
  else:
    var tmp: T
    decodeField(tmp, cv, row)
    dst = some(tmp)

proc decodeField*[T: object](dst: var T, cv: ColumnView, row: int) =
  if not cv.valid(row):
    raise newException(ValueError, "NULL in non-optional STRUCT/object field")
  if cv.kind != DuckType.Struct:
    raise newException(ValueError, "expected STRUCT for object field, got " & $cv.kind)
  let sv = cv.bindAs(DuckType.Struct)
  for fname, fval in fieldPairs(dst):
    var childIdx = -1
    for j in 0..<sv.structChildCount:
      if sv.structChildName(j).toLowerAscii == fname.toLowerAscii:
        childIdx = j
        break
    if childIdx < 0:
      raise newException(ValueError, "STRUCT missing field " & fname & " for object " & $T)
    let childView = sv.structChild(childIdx)
    decodeField(fval, childView, row)

proc decodeField*[T: tuple](dst: var T, cv: ColumnView, row: int) =
  if not cv.valid(row):
    raise newException(ValueError, "NULL in non-optional STRUCT/tuple field")
  if cv.kind != DuckType.Struct:
    raise newException(ValueError, "expected STRUCT for tuple field, got " & $cv.kind)
  let sv = cv.bindAs(DuckType.Struct)
  var idx = 0
  for fname, fval in fieldPairs(dst):
    let childView = sv.structChild(idx)
    decodeField(fval, childView, row)
    inc idx

# ---------------------------------------------------------------------------
# ToSeq for QResult / DataChunk
# ---------------------------------------------------------------------------

proc toSeq*[T: object](r: QResult[Materialized], _: typedesc[T]): seq[T] =
  result = newSeq[T](r.rlen)
  var idx = 0
  let meta = r.meta
  var colMapLower = initTable[string,int]()
  for i, col in meta.columns:
    colMapLower[col.name.toLowerAscii] = i
  var fieldToCol = initTable[string,int]()
  var dummy: T
  for fname, _ in fieldPairs(dummy):
    fieldToCol[fname] = colMapLower.getOrDefault(fname.toLowerAscii, -1)
  # Fallback: single STRUCT column containing all fields (e.g., SELECT data FROM t WHERE data is STRUCT)
  var useSingleStruct = false
  if meta.columns.len == 1 and meta.columns[0].kind == DuckType.Struct:
    var allMissing = true
    for v in fieldToCol.values:
      if v != -1: allMissing = false
    if allMissing:
      let ltype = meta.columns[0].ltype
      if ltype.childNames != nil:
        var childMap = initTable[string,int]()
        for i, n in ltype.childNames[]:
          childMap[n.toLowerAscii] = i
        var canDecode = true
        for fname, _ in fieldPairs(dummy):
          if not childMap.hasKey(fname.toLowerAscii):
            canDecode = false
        if canDecode:
          useSingleStruct = true
  if useSingleStruct:
    for chunk in r:
      for row in 0..<chunk.len:
        var obj: T
        let cv = chunk.vector(0)
        decodeField(obj, cv, row)
        result[idx] = obj
        inc idx
    if idx != result.len:
      result.setLen(idx)
    return
  for chunk in r:
    for row in 0..<chunk.len:
      var obj: T
      for fname, fval in fieldPairs(obj):
        let colIdx = fieldToCol[fname]
        if colIdx < 0:
          when fval is Option:
            fval = none(typeof(fval.get()))
          else:
            raise newException(ValueError,
              "Missing column for non-optional field '" & fname & "' in ToSeq[" & $T & "]")
        else:
          let cv = chunk.vector(colIdx)
          decodeField(fval, cv, row)
      result[idx] = obj
      inc idx
  if idx != result.len:
    result.setLen(idx)

proc toSeq*[T: object](r: sink QResult[Streaming], _: typedesc[T]): seq[T] =
  var mat = r.materialize()
  result = mat.toSeq(T)

proc toSeq*[T: object](chunk: DataChunk, _: typedesc[T]): seq[T] =
  result = newSeq[T](chunk.len)
  let meta = chunk.meta
  var colMapLower = initTable[string,int]()
  for i, col in meta.columns:
    colMapLower[col.name.toLowerAscii] = i
  var fieldToCol = initTable[string,int]()
  var dummy: T
  for fname, _ in fieldPairs(dummy):
    fieldToCol[fname] = colMapLower.getOrDefault(fname.toLowerAscii, -1)
  # Single-STRUCT fallback (same logic as QResult version)
  if meta.columns.len == 1 and meta.columns[0].kind == DuckType.Struct:
    var allMissing = true
    for v in fieldToCol.values:
      if v != -1: allMissing = false
    if allMissing and meta.columns[0].ltype.childNames != nil:
      var childMap = initTable[string,int]()
      for i, n in meta.columns[0].ltype.childNames[]:
        childMap[n.toLowerAscii] = i
      var canDecode = true
      for fname, _ in fieldPairs(dummy):
        if not childMap.hasKey(fname.toLowerAscii):
          canDecode = false
      if canDecode:
        var idx2 = 0
        for row in 0..<chunk.len:
          var obj: T
          let cv = chunk.vector(0)
          decodeField(obj, cv, row)
          result[idx2] = obj
          inc idx2
        return
  var idx = 0
  for row in 0..<chunk.len:
    var obj: T
    for fname, fval in fieldPairs(obj):
      let colIdx = fieldToCol[fname]
      if colIdx < 0:
        when fval is Option:
          fval = none(typeof(fval.get()))
        else:
          raise newException(ValueError,
            "Missing column for field '" & fname & "' in ToSeq[" & $T & "]")
      else:
        let cv = chunk.vector(colIdx)
        decodeField(fval, cv, row)
    result[idx] = obj
    inc idx

proc bindAs*[T: object](r: QResult[Materialized], _: typedesc[T]): seq[T] {.inline.} =
  r.toSeq(T)
proc bindAs*[T: object](r: sink QResult[Streaming], _: typedesc[T]): seq[T] {.inline.} =
  r.toSeq(T)
proc bindAs*[T: object](c: DataChunk, _: typedesc[T]): seq[T] {.inline.} =
  c.toSeq(T)

proc rows*[T: object](r: QResult[Materialized], _: typedesc[T]): seq[T] {.inline.} =
  r.toSeq(T)
proc rows*[T: object](r: sink QResult[Streaming], _: typedesc[T]): seq[T] {.inline.} =
  r.toSeq(T)

# ---------------------------------------------------------------------------
# Write helpers (Appender / create table)
# ---------------------------------------------------------------------------

proc createTableFromObject*[T: object](con: Connection, tableName: string, _: typedesc[T],
                                       orReplace = false) =
  var dummy: T
  var parts: seq[string] = @[]
  for fname, fval in fieldPairs(dummy):
    parts.add(quoteIdent(fname) & " " & sqlTypeFor(typeof(fval)))
  let ddl = (if orReplace: "CREATE OR REPLACE TABLE " else: "CREATE TABLE ") &
            quoteIdent(tableName) & " (" & parts.join(", ") & ")"
  # Need query.execute; import it lazily via `query` module to avoid cycle
  # We'll use ffi duckdb_query directly via Connection.rawHandle and check
  # But simplest: rely on `con` having `execute` from query module if imported there.
  # To avoid import cycle, we delegate to a helper that uses `query` if available.
  # For now, try to call `query.execute` if compiled with query import, else ffi.
  # We will import query dynamically via `when compiles(con.execute(""))`
  when compiles(con.execute("")):
    discard con.execute(ddl)
  else:
    var raw: duckdb_result
    let st = duckdb_query(con.rawHandle, ddl.cstring, raw.addr)
    if st != DuckDBSuccess:
      let msg = $duckdb_result_error(raw.addr)
      duckdb_destroy_result(raw.addr)
      raise newException(OperationError, msg)
    duckdb_destroy_result(raw.addr)

proc createType*[T: object](con: Connection, _: typedesc[T],
                            typeName: string = $T, orReplace = false): LogicalType =
  ## Registers `T` as DuckDB custom STRUCT type.
  ## - Builds transient LogicalType (always)
  ## - Executes `CREATE TYPE` DDL (visible in `duckdb_types()`)
  ## Returns the LogicalType for direct use.
  result = structLogicalType(T)
  let ddl = ddlForStruct(T, typeName)
  let finalDdl = if orReplace: ddl.replace("CREATE TYPE", "CREATE OR REPLACE TYPE") else: ddl
  if not orReplace:
    let exists = con.execute(
      "SELECT 1 FROM duckdb_types() WHERE lower(type_name) = lower('" & typeName.replace("'", "''") & "') LIMIT 1"
    )
    var has = false
    for ch in exists:
      if ch.len > 0: has = true
    if has:
      raise newException(OperationError, "Type already exists: " & typeName & " (use orReplace=true)")
  discard con.execute(finalDdl)

proc createType*[T: tuple](con: Connection, _: typedesc[T],
                           typeName: string, orReplace = false): LogicalType =
  result = structLogicalTypeTuple(T)
  var dummy: T
  var parts: seq[string] = @[]
  var idx = 0
  for fname, fval in fieldPairs(dummy):
    let n = if fname.len > 0: fname else: "field" & $idx
    parts.add(quoteIdent(n) & " " & sqlTypeFor(typeof(fval)))
    inc idx
  let ddl = "CREATE TYPE " & quoteIdent(typeName) & " AS STRUCT(" & parts.join(", ") & ")"
  let finalDdl = if orReplace: ddl.replace("CREATE TYPE", "CREATE OR REPLACE TYPE") else: ddl
  discard con.execute(finalDdl)

proc registerType*[T: object](con: Connection, _: typedesc[T],
                               typeName: string = $T, orReplace = false): LogicalType {.inline.} =
  ## Alias for `createType`.
  con.createType(T, typeName, orReplace)

proc createEnumType*[T: enum](con: Connection, _: typedesc[T],
                               typeName: string = $T, orReplace = false): LogicalType =
  ## Creates an ENUM type from a Nim enum's labels.
  ## Example: `type Mood = enum happy, sad, curious` → `CREATE TYPE mood AS ENUM ('happy','sad','curious')`
  var labels: seq[string] = @[]
  for v in low(T)..high(T):
    labels.add("'" & ($v).replace("'", "''") & "'")
  let ddl = "CREATE TYPE " & quoteIdent(typeName) & " AS ENUM (" & labels.join(", ") & ")"
  let finalDdl = if orReplace: ddl.replace("CREATE TYPE", "CREATE OR REPLACE TYPE") else: ddl
  if not orReplace:
    let exists = con.execute(
      "SELECT 1 FROM duckdb_types() WHERE lower(type_name) = lower('" & typeName.replace("'", "''") & "') LIMIT 1"
    )
    var has = false
    for ch in exists:
      if ch.len > 0: has = true
    if has:
      raise newException(OperationError, "Type already exists: " & typeName & " (use orReplace=true)")
  discard con.execute(finalDdl)
  # Build logical type for return (dictionary)
  var cstrs: seq[string] = @[]
  for v in low(T)..high(T): cstrs.add($v)
  var cptrs = newSeq[cstring](cstrs.len)
  for i, s in cstrs: cptrs[i] = s.cstring
  let raw = duckdb_create_enum_type(addr cptrs[0], cstrs.len.idx_t)
  result = newLogicalType(raw)

proc createAliasType*(con: Connection, aliasName: string, baseType: string,
                      orReplace = false): LogicalType =
  ## Creates a type alias: `CREATE TYPE alias AS baseType`
  ## Example: `createAliasType(con, "x_index", "INTEGER")`
  let ddl = "CREATE TYPE " & quoteIdent(aliasName) & " AS " & baseType
  let finalDdl = if orReplace: ddl.replace("CREATE TYPE", "CREATE OR REPLACE TYPE") else: ddl
  if not orReplace:
    let exists = con.execute(
      "SELECT 1 FROM duckdb_types() WHERE lower(type_name) = lower('" & aliasName.replace("'", "''") & "') LIMIT 1"
    )
    var has = false
    for ch in exists:
      if ch.len > 0: has = true
    if has:
      raise newException(OperationError, "Type already exists: " & aliasName & " (use orReplace=true)")
  discard con.execute(finalDdl)
  # Alias logical type: we return logical type of base if known, else invalid
  # Try to interpret baseType as simple DuckType
  let upper = baseType.strip().toUpperAscii()
  case upper
  of "INTEGER", "INT", "INT4": result = newLogicalType(DuckType.Integer)
  of "BIGINT", "INT8": result = newLogicalType(DuckType.BigInt)
  of "VARCHAR", "TEXT", "STRING": result = newLogicalType(DuckType.Varchar)
  of "BOOLEAN", "BOOL": result = newLogicalType(DuckType.Boolean)
  of "DOUBLE", "FLOAT8": result = newLogicalType(DuckType.Double)
  of "FLOAT", "FLOAT4": result = newLogicalType(DuckType.Float)
  else: result = newLogicalType(DuckType.Varchar) # fallback

proc createUnionType*(con: Connection, typeName: string, membersDDL: string,
                      orReplace = false): LogicalType =
  ## Creates a UNION type: `CREATE TYPE name AS UNION(memberDDL)`
  ## Example: `createUnionType(con, "one_thing", "number INTEGER, string VARCHAR")`
  let ddl = "CREATE TYPE " & quoteIdent(typeName) & " AS UNION(" & membersDDL & ")"
  let finalDdl = if orReplace: ddl.replace("CREATE TYPE", "CREATE OR REPLACE TYPE") else: ddl
  if not orReplace:
    let exists = con.execute(
      "SELECT 1 FROM duckdb_types() WHERE lower(type_name) = lower('" & typeName.replace("'", "''") & "') LIMIT 1"
    )
    var has = false
    for ch in exists:
      if ch.len > 0: has = true
    if has:
      raise newException(OperationError, "Type already exists: " & typeName & " (use orReplace=true)")
  discard con.execute(finalDdl)
  # For return, we build a generic union logical type placeholder (actual members via DDL)
  # We try to infer at least 2 members if ddl contains ',' else 1
  # Simpler: return Invalid placeholder and let caller ignore; but to keep non-nil, create via ffi if possible
  # Build from membersDDL counting commas: we need actual member types to create union logical type
  # Fallback: create simple union of INTEGER,VARCHAR if ddl contains those strings
  var memberTypes: seq[duckdb_logical_type] = @[]
  var memberNames: seq[cstring] = @[]
  # naive parse: split by ',' then by space
  for part in membersDDL.split(','):
    let trimmed = part.strip()
    if trimmed.len == 0: continue
    let pieces = trimmed.splitWhitespace()
    if pieces.len >= 2:
      let mName = pieces[0]
      let mTypeStr = pieces[1].toUpperAscii()
      var lt: LogicalType
      case mTypeStr
      of "INTEGER", "INT", "INT4": lt = newLogicalType(DuckType.Integer)
      of "BIGINT": lt = newLogicalType(DuckType.BigInt)
      of "VARCHAR", "TEXT": lt = newLogicalType(DuckType.Varchar)
      of "BOOLEAN", "BOOL": lt = newLogicalType(DuckType.Boolean)
      of "DOUBLE": lt = newLogicalType(DuckType.Double)
      else: lt = newLogicalType(DuckType.Varchar)
      memberTypes.add(lt.handle)
      memberNames.add(mName.cstring)
  if memberTypes.len > 0:
    var namePtrs = newSeq[cstring](memberNames.len)
    for i, n in memberNames: namePtrs[i] = n
    let raw = duckdb_create_union_type(addr memberTypes[0], addr namePtrs[0], memberTypes.len.idx_t)
    result = newLogicalType(raw)
  else:
    result = newLogicalType(DuckType.Union)

proc encodeFieldAppInner(app: Appender, val: string) = discard duckdb_append_varchar(app, val.cstring)
proc encodeFieldAppInner(app: Appender, val: bool) = discard duckdb_append_bool(app, val)
proc encodeFieldAppInner(app: Appender, val: int32) = discard duckdb_append_int32(app, val)
proc encodeFieldAppInner(app: Appender, val: int64) = discard duckdb_append_int64(app, val)
proc encodeFieldAppInner(app: Appender, val: float64) = discard duckdb_append_double(app, val)

proc appendRows*[T: object](con: Connection, tableName: string, rows: openArray[T]) =
  if rows.len == 0: return
  # We need to import query for newAppender; use generic approach with ffi?
  # Instead we try to use `newAppender` from query if available
  when compiles(newAppender(con, tableName)):
    var app = newAppender(con, tableName)
    for r in rows:
      var dummy = r
      for fname, fval in fieldPairs(dummy):
        when fval is Option:
          if fval.isNone:
            discard duckdb_append_null(app)
          else:
            let inner = fval.get()
            when inner is string: discard duckdb_append_varchar(app, inner.cstring)
            elif inner is bool: discard duckdb_append_bool(app, inner)
            elif inner is int8: discard duckdb_append_int8(app, inner)
            elif inner is int16: discard duckdb_append_int16(app, inner)
            elif inner is int32: discard duckdb_append_int32(app, inner)
            elif inner is int64 or inner is int: discard duckdb_append_int64(app, int64(inner))
            elif inner is uint8: discard duckdb_append_uint8(app, inner)
            elif inner is uint16: discard duckdb_append_uint16(app, inner)
            elif inner is uint32: discard duckdb_append_uint32(app, inner)
            elif inner is uint64 or inner is uint: discard duckdb_append_uint64(app, uint64(inner))
            elif inner is float32: discard duckdb_append_float(app, inner)
            elif inner is float64: discard duckdb_append_double(app, inner)
            elif inner is Int128: discard duckdb_append_hugeint(app, inner.toHugeInt)
            elif inner is UInt128: discard duckdb_append_uhugeint(app, inner.toUHugeInt)
            elif inner is Uuid: discard duckdb_append_varchar(app, ($inner).cstring)
            elif inner is DateTime: discard duckdb_append_timestamp(app, Timestamp(inner).toTimestamp)
            elif inner is Timestamp: discard duckdb_append_timestamp(app, inner.toTimestamp)
            elif inner is Time: discard duckdb_append_time(app, inner.toTime)
            elif inner is TimeInterval: discard duckdb_append_interval(app, inner.toInterval)
            elif inner is seq[byte]: 
              if inner.len == 0: discard duckdb_append_blob(app, nil, 0)
              else: discard duckdb_append_blob(app, unsafeAddr inner[0], inner.len.idx_t)
            else: {.error: "appendRows Option inner type not supported: " & $typeof(inner).}
        elif fval is seq[byte]:
          if fval.len == 0: discard duckdb_append_blob(app, nil, 0)
          else: discard duckdb_append_blob(app, unsafeAddr fval[0], fval.len.idx_t)
        elif fval is seq:
          {.error: "appendRows object with seq[T] (LIST) not yet supported via row Appender; use LIST handling v2".}
        elif fval is object or fval is tuple:
          {.error: "nested object append not yet supported via Appender v1".}
        elif fval is string:
          discard duckdb_append_varchar(app, fval.cstring)
        elif fval is bool:
          discard duckdb_append_bool(app, fval)
        elif fval is int8:
          discard duckdb_append_int8(app, fval)
        elif fval is int16:
          discard duckdb_append_int16(app, fval)
        elif fval is int32:
          discard duckdb_append_int32(app, fval)
        elif fval is int64 or fval is int:
          discard duckdb_append_int64(app, int64(fval))
        elif fval is uint8:
          discard duckdb_append_uint8(app, fval)
        elif fval is uint16:
          discard duckdb_append_uint16(app, fval)
        elif fval is uint32:
          discard duckdb_append_uint32(app, fval)
        elif fval is uint64 or fval is uint:
          discard duckdb_append_uint64(app, uint64(fval))
        elif fval is float32:
          discard duckdb_append_float(app, fval)
        elif fval is float64:
          discard duckdb_append_double(app, fval)
        elif fval is Int128:
          discard duckdb_append_hugeint(app, fval.toHugeInt)
        elif fval is UInt128:
          discard duckdb_append_uhugeint(app, fval.toUHugeInt)
        elif fval is Uuid:
          discard duckdb_append_varchar(app, ($fval).cstring)
        elif fval is DateTime:
          discard duckdb_append_timestamp(app, Timestamp(fval).toTimestamp)
        elif fval is Timestamp:
          discard duckdb_append_timestamp(app, fval.toTimestamp)
        elif fval is Time:
          discard duckdb_append_time(app, fval.toTime)
        elif fval is TimeInterval:
          discard duckdb_append_interval(app, fval.toInterval)
        else:
          {.error: "appendRows field type not supported: " & $typeof(fval).}
      discard duckdb_appender_end_row(app)
    discard duckdb_appender_flush(app)
    discard duckdb_appender_close(app)
  else:
    {.error: "appendRows requires query.newAppender; import query".}

