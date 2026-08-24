## Mapping between Nim objects and DuckDB rows and STRUCT values.
##
## Column names are matched case-insensitively. Extra columns are ignored,
## missing optional fields become `none`, and missing required fields raise
## `ValueError`. Decoded values own their storage.

import std/[options, strutils, times]

import nint128
import uuid4

import ./database
import ./ffi
import ./qresult
import ./query
import ./types

proc quoteIdent*(name: string): string =
  result = "\""
  for character in name:
    if character == '"':
      result.add("\"\"")
    else:
      result.add(character)
  result.add('"')

# Logical and SQL types

proc logicalTypeForImpl[T](_: typedesc[T]): LogicalType
proc structLogicalType*[T: object](_: typedesc[T]): LogicalType
proc structLogicalTypeTuple*[T: tuple](_: typedesc[T]): LogicalType

proc logicalTypeFor*[T](_: typedesc[T]): LogicalType =
  logicalTypeForImpl(T)

proc logicalTypeForImpl[T](_: typedesc[T]): LogicalType =
  when T is seq[byte]:
    newLogicalType(DuckType.Blob)
  elif T is seq:
    type Element = typeof(default(T)[0])
    let elementType = logicalTypeFor(Element)
    newLogicalType(duckdb_create_list_type(elementType.handle))
  elif T is Option:
    type Value = typeof(default(T).get())
    logicalTypeFor(Value)
  elif T is enum:
    var labels: seq[string]
    for value in low(T)..high(T):
      labels.add($value)
    var labelPointers = newSeq[cstring](labels.len)
    for index, label in labels:
      labelPointers[index] = label.cstring
    newLogicalType(duckdb_create_enum_type(
      addr labelPointers[0], labels.len.idx_t))
  elif T is object:
    const kind = toDuckType(T)
    when kind == DuckType.Invalid:
      structLogicalType(T)
    else:
      newLogicalType(kind)
  elif T is tuple:
    structLogicalTypeTuple(T)
  else:
    const kind = toDuckType(T)
    when kind == DuckType.Invalid:
      {.error: "logicalTypeFor: unsupported type " & $T.}
    else:
      newLogicalType(kind)

proc structLogicalTypeImpl[T](_: typedesc[T]): LogicalType =
  var value: T
  var childNames: seq[string]
  var childTypes: seq[LogicalType]
  for name, field in fieldPairs(value):
    let index = childNames.len
    childNames.add(if name.len == 0: "field" & $index else: name)
    childTypes.add(logicalTypeFor(typeof(field)))

  if childTypes.len == 0:
    raise newException(ValueError, "cannot create an empty STRUCT for " & $T)

  var handles = newSeq[duckdb_logical_type](childTypes.len)
  var names = newSeq[cstring](childNames.len)
  for index in 0..<childTypes.len:
    handles[index] = childTypes[index].handle
    names[index] = childNames[index].cstring
  result = newLogicalType(duckdb_create_struct_type(
    addr handles[0], addr names[0], handles.len.idx_t))

proc structLogicalType*[T: object](_: typedesc[T]): LogicalType =
  structLogicalTypeImpl(T)

proc structLogicalTypeTuple*[T: tuple](_: typedesc[T]): LogicalType =
  structLogicalTypeImpl(T)

proc sqlTypeForImpl[T](_: typedesc[T]): string

proc sqlTypeName(kind: DuckType): string =
  case kind
  of DuckType.Boolean: "BOOLEAN"
  of DuckType.TinyInt: "TINYINT"
  of DuckType.SmallInt: "SMALLINT"
  of DuckType.Integer: "INTEGER"
  of DuckType.BigInt: "BIGINT"
  of DuckType.UTinyInt: "UTINYINT"
  of DuckType.USmallInt: "USMALLINT"
  of DuckType.UInteger: "UINTEGER"
  of DuckType.UBigInt: "UBIGINT"
  of DuckType.Float: "FLOAT"
  of DuckType.Double: "DOUBLE"
  of DuckType.Varchar: "VARCHAR"
  of DuckType.Blob: "BLOB"
  of DuckType.HugeInt: "HUGEINT"
  of DuckType.UHugeInt: "UHUGEINT"
  of DuckType.UUID: "UUID"
  of DuckType.Timestamp: "TIMESTAMP"
  of DuckType.Time: "TIME"
  of DuckType.Interval: "INTERVAL"
  else:
    raise newException(ValueError, "no SQL name for " & $kind)

proc sqlTypeFor*[T](_: typedesc[T]): string =
  sqlTypeForImpl(T)

proc sqlStructFields[T](_: typedesc[T]): string =
  var value: T
  var fields: seq[string]
  for name, field in fieldPairs(value):
    let index = fields.len
    let fieldName = if name.len == 0: "field" & $index else: name
    fields.add(quoteIdent(fieldName) & " " & sqlTypeFor(typeof(field)))
  fields.join(", ")

proc sqlStructType[T](_: typedesc[T]): string =
  "STRUCT(" & sqlStructFields(T) & ")"

proc sqlTypeForImpl[T](_: typedesc[T]): string =
  when T is seq[byte]:
    "BLOB"
  elif T is seq:
    type Element = typeof(default(T)[0])
    sqlTypeFor(Element) & "[]"
  elif T is Option:
    type Value = typeof(default(T).get())
    sqlTypeFor(Value)
  elif T is enum:
    var labels: seq[string]
    for value in low(T)..high(T):
      labels.add("'" & ($value).replace("'", "''") & "'")
    "ENUM (" & labels.join(", ") & ")"
  elif T is object:
    const kind = toDuckType(T)
    when kind == DuckType.Invalid:
      sqlStructType(T)
    else:
      sqlTypeName(kind)
  elif T is tuple:
    sqlStructType(T)
  else:
    const kind = toDuckType(T)
    when kind == DuckType.Invalid:
      {.error: "sqlTypeFor: unsupported type " & $T.}
    else:
      sqlTypeName(kind)

proc ddlForStruct*[T: object](_: typedesc[T], typeName: string): string =
  "CREATE TYPE " & quoteIdent(typeName) & " AS " & sqlStructType(T)

# Row decoding

proc findField(names: openArray[string], wanted, context: string): int =
  result = -1
  for index, name in names:
    if name == wanted:
      if result >= 0:
        raise newException(ValueError,
          "ambiguous field '" & wanted & "' in " & context)
      result = index
  if result >= 0:
    return

  for index, name in names:
    if cmpIgnoreCase(name, wanted) == 0:
      if result >= 0:
        raise newException(ValueError,
          "ambiguous case-insensitive field '" & wanted & "' in " &
          context)
      result = index

proc requireKind(view: ColumnView, expected: DuckType, valueType: string) =
  if view.kind != expected:
    raise newException(ValueError,
      "cannot decode " & $view.kind & " as " & valueType)

proc decodeScalar[T](destination: var T, view: ColumnView, row: int) =
  const kind = toDuckType(T)
  when kind == DuckType.Invalid:
    {.error: "unsupported struct mapping field type " & $T.}
  else:
    view.requireKind(kind, $T)
    let values = view.bindAs(kind)
    when T is int:
      destination = int(values[row])
    elif T is uint:
      destination = uint(values[row])
    else:
      destination = values[row]

proc decodeField[T](destination: var T, view: ColumnView, row: int)

proc decodeEnum[T: enum](destination: var T, view: ColumnView, row: int) =
  view.requireKind(DuckType.Enum, $T)
  if view.ltype.enumLabels == nil:
    raise newException(ValueError, "ENUM labels are unavailable for " & $T)
  let index = view.bindAs(DuckType.Enum)[row].int
  if index notin 0..<view.ltype.enumLabels[].len:
    raise newException(ValueError, "ENUM index is outside its schema")
  let label = view.ltype.enumLabels[][index]
  for value in low(T)..high(T):
    if $value == label:
      destination = value
      return
  raise newException(ValueError,
    "DuckDB ENUM label '" & label & "' is not present in " & $T)

proc decodeStruct[T](destination: var T, view: ColumnView, row: int) =
  view.requireKind(DuckType.Struct, $T)
  let structView = view.bindAs(DuckType.Struct)
  if view.ltype.childNames == nil:
    raise newException(ValueError, "STRUCT field names are unavailable")
  let names = view.ltype.childNames[]

  for name, field in fieldPairs(destination):
    let index = findField(names, name, "STRUCT " & $T)
    if index >= 0:
      decodeField(field, structView.structChild(index), row)
    else:
      when field is Option:
        type Value = typeof(field.get())
        field = none(Value)
      else:
        raise newException(ValueError,
          "missing non-optional STRUCT field '" & name & "'")

proc decodeTuple[T: tuple](destination: var T, view: ColumnView, row: int) =
  view.requireKind(DuckType.Struct, $T)
  let structView = view.bindAs(DuckType.Struct)
  var expected = 0
  for _, _ in fieldPairs(destination):
    inc expected
  if structView.structChildCount != expected:
    raise newException(ValueError,
      "tuple arity mismatch: expected " & $expected & ", got " &
      $structView.structChildCount)
  var index = 0
  for _, field in fieldPairs(destination):
    decodeField(field, structView.structChild(index), row)
    inc index

proc decodeField[T](destination: var T, view: ColumnView, row: int) =
  when T is Option:
    type Value = typeof(default(T).get())
    if not view.valid(row):
      destination = none(Value)
    else:
      var value: Value
      decodeField(value, view, row)
      destination = some(value)
  else:
    if not view.valid(row):
      raise newException(ValueError,
        "NULL in non-optional field of type " & $T)
    when T is seq[byte]:
      decodeScalar(destination, view, row)
    elif T is seq:
      type Element = typeof(default(T)[0])
      view.requireKind(DuckType.List, $T)
      destination = view.bindAs(seq[Element])[row]
    elif T is enum:
      decodeEnum(destination, view, row)
    elif T is DateTime:
      case view.kind
      of DuckType.Timestamp:
        destination = DateTime(view.bindAs(DuckType.Timestamp)[row])
      of DuckType.Date:
        destination = view.bindAs(DuckType.Date)[row]
      of DuckType.TimestampS:
        destination = view.bindAs(DuckType.TimestampS)[row]
      of DuckType.TimestampMs:
        destination = view.bindAs(DuckType.TimestampMs)[row]
      of DuckType.TimestampNs:
        destination = view.bindAs(DuckType.TimestampNs)[row]
      else:
        raise newException(ValueError,
          "cannot decode " & $view.kind & " as DateTime")
    elif T is tuple:
      decodeTuple(destination, view, row)
    elif T is object:
      const kind = toDuckType(T)
      when kind == DuckType.Invalid:
        decodeStruct(destination, view, row)
      else:
        decodeScalar(destination, view, row)
    else:
      decodeScalar(destination, view, row)

type RowMapping = object
  structColumn: int
  columns: seq[int]

proc rowMapping[T: object](meta: ChunkMeta, _: typedesc[T]): RowMapping =
  result.structColumn = -1
  var names = newSeq[string](meta.columns.len)
  for index, column in meta.columns:
    names[index] = column.name

  var value: T
  for name, _ in fieldPairs(value):
    result.columns.add(findField(names, name, "query result"))

  var anyMatch = false
  for index in result.columns:
    if index >= 0:
      anyMatch = true
  if not anyMatch and meta.columns.len == 1 and
      meta.columns[0].kind == DuckType.Struct:
    result.structColumn = 0
    result.columns.setLen(0)
    return

  var index = 0
  for name, field in fieldPairs(value):
    if result.columns[index] < 0:
      when field isnot Option:
        raise newException(ValueError,
          "missing non-optional column '" & name & "' for " & $T)
    inc index

proc decodeRow[T: object](mapping: RowMapping, chunk: DataChunk,
                          row: int): T =
  if mapping.structColumn >= 0:
    decodeField(result, chunk.vector(mapping.structColumn), row)
    return

  var index = 0
  for _, field in fieldPairs(result):
    let column = mapping.columns[index]
    if column >= 0:
      decodeField(field, chunk.vector(column), row)
    else:
      when field is Option:
        type Value = typeof(field.get())
        field = none(Value)
    inc index

proc decodeChunkInto[T: object](destination: var seq[T], chunk: DataChunk,
                                mapping: RowMapping) =
  for row in 0..<chunk.len:
    destination.add(decodeRow[T](mapping, chunk, row))

proc toSeqInto*[T: object](chunk: DataChunk, destination: var seq[T]) =
  let mapping = rowMapping(chunk.meta, T)
  destination.setLen(0)
  destination.decodeChunkInto(chunk, mapping)

proc toSeqInto*[T: object](resultSet: QResult[Materialized],
                           destination: var seq[T]) =
  let mapping = rowMapping(resultSet.meta, T)
  destination.setLen(0)
  for chunk in resultSet.chunks:
    destination.decodeChunkInto(chunk, mapping)

proc toSeqInto*[T: object](resultSet: sink QResult[Streaming],
                           destination: var seq[T]) =
  let mapping = rowMapping(resultSet.meta, T)
  destination.setLen(0)
  for chunk in qresult.items(resultSet):
    destination.decodeChunkInto(chunk, mapping)

proc toSeq*[T: object](chunk: DataChunk, _: typedesc[T]): seq[T] =
  chunk.toSeqInto(result)

proc toSeq*[T: object](resultSet: QResult[Materialized],
                       _: typedesc[T]): seq[T] =
  resultSet.toSeqInto(result)

proc toSeq*[T: object](resultSet: sink QResult[Streaming],
                       _: typedesc[T]): seq[T] =
  resultSet.toSeqInto(result)

proc toSeqInto*[T: object](chunk: DataChunk, destination: var seq[T],
                           _: typedesc[T]) =
  chunk.toSeqInto(destination)

proc toSeqInto*[T: object](resultSet: QResult[Materialized],
                           destination: var seq[T], _: typedesc[T]) =
  resultSet.toSeqInto(destination)

proc toSeqInto*[T: object](resultSet: sink QResult[Streaming],
                           destination: var seq[T], _: typedesc[T]) =
  resultSet.toSeqInto(destination)

iterator items*[T: object](chunk: DataChunk, _: typedesc[T]): T =
  let mapping = rowMapping(chunk.meta, T)
  for row in 0..<chunk.len:
    yield decodeRow[T](mapping, chunk, row)

iterator items*[T: object](resultSet: QResult[Materialized],
                           _: typedesc[T]): T =
  let mapping = rowMapping(resultSet.meta, T)
  for chunk in resultSet.chunks:
    for row in 0..<chunk.len:
      yield decodeRow[T](mapping, chunk, row)

iterator items*[T: object](resultSet: QResult[Streaming],
                           _: typedesc[T]): T =
  let mapping = rowMapping(resultSet.meta, T)
  for chunk in qresult.items(resultSet):
    for row in 0..<chunk.len:
      yield decodeRow[T](mapping, chunk, row)

proc bindAs*[T: object](resultSet: QResult[Materialized],
                        _: typedesc[T]): seq[T] =
  resultSet.toSeq(T)

proc bindAs*[T: object](resultSet: sink QResult[Streaming],
                        _: typedesc[T]): seq[T] =
  resultSet.toSeq(T)

proc bindAs*[T: object](chunk: DataChunk, _: typedesc[T]): seq[T] =
  chunk.toSeq(T)

proc rows*[T: object](resultSet: QResult[Materialized],
                      _: typedesc[T]): seq[T] =
  resultSet.toSeq(T)

proc rows*[T: object](resultSet: sink QResult[Streaming],
                      _: typedesc[T]): seq[T] =
  resultSet.toSeq(T)

# Table and named-type creation

proc createTable*[T: object](connection: Connection, tableName: string,
                             _: typedesc[T], orReplace = false) =
  let command =
    (if orReplace: "CREATE OR REPLACE TABLE " else: "CREATE TABLE ") &
    quoteIdent(tableName) & " (" & sqlStructFields(T) & ")"
  discard connection.execute(command)

proc createTableFromObject*[T: object](connection: Connection,
                                       tableName: string, _: typedesc[T],
                                       orReplace = false) =
  connection.createTable(tableName, T, orReplace)

proc createType*[T: object](connection: Connection, _: typedesc[T],
                            typeName: string = $T,
                            orReplace = false): LogicalType =
  result = structLogicalType(T)
  let command =
    (if orReplace: "CREATE OR REPLACE TYPE " else: "CREATE TYPE ") &
    quoteIdent(typeName) & " AS " & sqlStructType(T)
  discard connection.execute(command)

proc createType*[T: tuple](connection: Connection, _: typedesc[T],
                           typeName: string,
                           orReplace = false): LogicalType =
  result = structLogicalTypeTuple(T)
  let command =
    (if orReplace: "CREATE OR REPLACE TYPE " else: "CREATE TYPE ") &
    quoteIdent(typeName) & " AS " & sqlStructType(T)
  discard connection.execute(command)

proc registerType*[T: object](connection: Connection, _: typedesc[T],
                              typeName: string = $T,
                              orReplace = false): LogicalType =
  connection.createType(T, typeName, orReplace)

proc createEnumType*[T: enum](connection: Connection, _: typedesc[T],
                              typeName: string = $T,
                              orReplace = false): LogicalType =
  result = logicalTypeFor(T)
  let command =
    (if orReplace: "CREATE OR REPLACE TYPE " else: "CREATE TYPE ") &
    quoteIdent(typeName) & " AS " & sqlTypeFor(T)
  discard connection.execute(command)

proc createdTypeLogicalType(connection: Connection,
                            typeName: string): LogicalType =
  let resultSet = connection.execute(
    "SELECT NULL::" & quoteIdent(typeName) & " AS __nimdrake_type")
  resultSet.column(0).ltype

proc createAliasType*(connection: Connection, aliasName, baseType: string,
                      orReplace = false): LogicalType =
  let command =
    (if orReplace: "CREATE OR REPLACE TYPE " else: "CREATE TYPE ") &
    quoteIdent(aliasName) & " AS " & baseType
  discard connection.execute(command)
  connection.createdTypeLogicalType(aliasName)

proc createUnionType*(connection: Connection, typeName, membersDDL: string,
                      orReplace = false): LogicalType =
  let command =
    (if orReplace: "CREATE OR REPLACE TYPE " else: "CREATE TYPE ") &
    quoteIdent(typeName) & " AS UNION(" & membersDDL & ")"
  discard connection.execute(command)
  connection.createdTypeLogicalType(typeName)
