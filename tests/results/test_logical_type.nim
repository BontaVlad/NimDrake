import std/[unittest]
import ../../src/[api, types]

suite "Test logical type":
  test "Test logical type creation from duckdb handle":
    let
      rawBooleanLogicalType = duckdb_create_logical_type(enum_DUCKDB_TYPE.DUCKDB_TYPE_BOOLEAN)
      logicalBooleanType = newLogicalType(rawBooleanLogicalType)

      rawVarCharLogicalType = duckdb_create_logical_type(enum_DUCKDB_TYPE.DUCKDB_TYPE_VARCHAR)
      logicalVarCharType = newLogicalType(rawVarCharLogicalType)

    assert $logicalBooleanType == "Boolean"
    assert $logicalVarCharType == "Varchar"

  test "Test logical type creation from duckType":
    let
      logicalBooleanType = newLogicalType(DuckType.Boolean)
      logicalVarCharType = newLogicalType(DuckType.VarChar)

    assert $logicalBooleanType == "Boolean"
    assert $logicalVarCharType == "Varchar"
