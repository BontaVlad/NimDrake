## SQL DDL generation and named-type creation for Nim models.
##
## `sqlTypeFor` renders a Nim type as DuckDB SQL text, `logicalTypeFor` builds
## the matching DuckDB logical type, and `createTable` / `createType` execute
## the corresponding DDL on a connection. Identifiers are quoted with
## `quoteIdent` and enum labels are escaped automatically.

import std/[options, strutils]

import nint128
import uuid4

import ./database
import ./ffi
import ./qresult
import ./query
import ./types

proc quoteIdent*(name: string): string =
  ## Quotes `name` as a double-quoted SQL identifier, escaping embedded quotes.
  result = "\""
  for character in name:
    if character == '"':
      result.add("\"\"")
    else:
      result.add(character)
  result.add('"')

proc logicalTypeForImpl[T](_: typedesc[T]): LogicalType

proc structLogicalTypeOf[T: object | tuple](_: typedesc[T]): LogicalType

proc logicalTypeFor*[T](_: typedesc[T]): LogicalType =
  ## The DuckDB logical type for Nim type `T`: scalars map via `toDuckType`,
  ## `seq[T]` becomes LIST, `Option[T]` unwraps, enums become ENUM types with
  ## the `$` labels, objects/tuples without a scalar mapping become STRUCT.
  ## Raises at compile time for unsupported types.
  logicalTypeForImpl(T)

proc logicalTypeForImpl[T](_: typedesc[T]): LogicalType =
  when T is seq[byte]:
    newLogicalType(DuckType.Blob)
  elif T is seq:
    type Element = typeof(default(T)[0])
    newLogicalType(duckdb_create_list_type(logicalTypeFor(Element).handle))
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
      structLogicalTypeOf(T)
    else:
      newLogicalType(kind)
  elif T is tuple:
    structLogicalTypeOf(T)
  else:
    const kind = toDuckType(T)
    when kind == DuckType.Invalid:
      {.error: "logicalTypeFor: unsupported type " & $T.}
    else:
      newLogicalType(kind)

proc structLogicalTypeOf[T: object | tuple](_: typedesc[T]): LogicalType =
  ## A STRUCT logical type whose children mirror the fields of `T`.
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

proc sqlTypeForImpl[T](_: typedesc[T]): string

proc sqlTypeFor*[T](_: typedesc[T]): string =
  ## The DuckDB SQL type name for Nim type `T`, mirroring `logicalTypeFor`:
  ## e.g. `sqlTypeFor(seq[int32]) == "INTEGER[]"`. Raises `ValueError` for
  ## scalar kinds without an SQL name and fails at compile time for
  ## unsupported types.
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

# Table and named-type creation

proc createTable*[T: object](connection: Connection, tableName: string,
                             _: typedesc[T], orReplace = false) =
  ## Creates a table whose columns mirror the fields of object `T`.
  discard connection.execute(
    (if orReplace: "CREATE OR REPLACE TABLE " else: "CREATE TABLE ") &
    quoteIdent(tableName) & " (" & sqlStructFields(T) & ")")

proc createdTypeLogicalType(connection: Connection,
                            typeName: string): LogicalType =
  ## The logical type of an existing named type, fetched by round-tripping
  ## `SELECT NULL::<name>` through the connection.
  let resultSet = connection.execute(
    "SELECT NULL::" & quoteIdent(typeName) & " AS __nimdrake_type")
  resultSet.column(0).ltype

proc createType*[T](connection: Connection, _: typedesc[T],
                    typeName: string = $T,
                    orReplace = false): LogicalType =
  ## Creates a persistent named alias for the mapped type of `T`: a STRUCT
  ## for objects and tuples, an ENUM for Nim enums. Returns the logical type
  ## of the created name (see `createdTypeLogicalType`).
  result = logicalTypeFor(T)
  discard connection.execute(
    (if orReplace: "CREATE OR REPLACE TYPE " else: "CREATE TYPE ") &
    quoteIdent(typeName) & " AS " & sqlTypeFor(T))

proc createAliasType*(connection: Connection, aliasName, baseType: string,
                      orReplace = false): LogicalType =
  ## Creates a named alias for the raw SQL type `baseType` and returns its
  ## logical type. `baseType` is spliced into the statement verbatim.
  discard connection.execute(
    (if orReplace: "CREATE OR REPLACE TYPE " else: "CREATE TYPE ") &
    quoteIdent(aliasName) & " AS " & baseType
  )
  connection.createdTypeLogicalType(aliasName)

proc createUnionType*(connection: Connection, typeName, membersDDL: string,
                      orReplace = false): LogicalType =
  ## Creates a UNION type from raw member DDL (e.g.
  ## `"number INTEGER, string VARCHAR"`) and returns its logical type. Both
  ## arguments are spliced into the statement verbatim.
  discard connection.execute(
    (if orReplace: "CREATE OR REPLACE TYPE " else: "CREATE TYPE ") &
    quoteIdent(typeName) & " AS UNION(" & membersDDL & ")"
  )
  connection.createdTypeLogicalType(typeName)
