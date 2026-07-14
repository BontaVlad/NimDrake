## Table scan — in-process table function for DataFrame registration.
##
## Registers a DataFrame as a DuckDB table function so external SQL queries
## can read the DataFrame as if it were a table.

import std/[tables, strformat]
import /[ffi, database, types, qresult, table_functions, query]

type
  ExtraData* = ref object of RootObj
    data*: Table[string, QResult[Materialized]]

  BindData = ref object
    df: QResult[Materialized]

proc scanBind(info: BindInfo) = discard
proc scanInit(info: InitInfo) = discard
proc scanMain(info: FunctionInfo, rawChunk: duckdbDatachunk) = discard

proc register*(con: Connection, name: string, df: QResult[Materialized]) =
  ## Register a DataFrame so DuckDB can query it by name.
  ## Walks chunks from df.q and writes each row into a DuckDB data chunk.
  var extraData = ExtraData(data: initTable[string, QResult[Materialized]]())
  extraData.data[name] = df

  let tf = newTableFunction(
    name = "nim_tbl_scan",
    parameters = @[newLogicalType(DuckType.Varchar)],
    bindFunc = scanBind,
    initFunc = scanInit,
    initLocalFunc = scanInit,
    mainFunc = scanMain,
    extraData = extraData,
    projectionPushdown = false,
  )
  con.register(tf)
  con.execute(
    fmt"""CREATE OR REPLACE VIEW "{name}" AS SELECT * FROM nim_tbl_scan('{name}');"""
  )
