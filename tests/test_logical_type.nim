import unittest2

import ../src/[ffi, types]

suite "Test logical type":
  test "Test logical type creation from duckdb handle":
    let
      rawBooleanLogicalType =
        duckdb_create_logical_type(enum_DUCKDB_TYPE.DUCKDB_TYPE_BOOLEAN)
      logicalBooleanType = newLogicalType(rawBooleanLogicalType)

      rawVarCharLogicalType =
        duckdb_create_logical_type(enum_DUCKDB_TYPE.DUCKDB_TYPE_VARCHAR)
      logicalVarCharType = newLogicalType(rawVarCharLogicalType)

    assert $logicalBooleanType == "Boolean"
    assert $logicalVarCharType == "Varchar"

  test "Test logical type creation from duckType":
    let
      logicalBooleanType = newLogicalType(DuckType.Boolean)
      logicalVarCharType = newLogicalType(DuckType.VarChar)

    assert $logicalBooleanType == "Boolean"
    assert $logicalVarCharType == "Varchar"

  test "Composite logical type — List(BigInt)":
    let
      inner = newLogicalType(DuckType.BigInt)
      listType = duckdb_create_list_type(cast[duckdb_logical_type](inner.handle))
      lt = newLogicalType(listType)
    check $lt == "List"

  test "Composite logical type — Struct(a Int, b Varchar)":
    let
      inner1 = newLogicalType(DuckType.Integer)
      inner2 = newLogicalType(DuckType.Varchar)
      memberTypes = [cast[duckdb_logical_type](inner1.handle),
                     cast[duckdb_logical_type](inner2.handle)]
      names = [cstring("a"), cstring("b")]
      raw = duckdb_create_struct_type(addr memberTypes[0], addr names[0], 2)
      lt = newLogicalType(raw)
    check $lt == "Struct"
