## NimDrake is a Nim language package designed to integrate with **DuckDB**,
## an in-process SQL OLAP database management system. It simplifies database
## interactions while maintaining flexibility for advanced use cases.
##
## NimDrake is built with two ideas in mind: the high-level interface offers
## quick and easy database operations, ideal for rapid development and
## simplicity; a lower-level interface interacts directly with DuckDB's core
## functionality for complex or high-performance implementations when
## necessary. This dual-layer approach caters to both beginners and advanced
## users.
##
## The mental model, top to bottom:
##
## - `Database` → `Connection` — open a database, then `connect` one or more
##   connections (thread-safe but serialized while querying; prefer one
##   connection per thread).
## - Queries — `execute` (raw SQL), prepared statements via `newStatement` +
##   `bindVal`, or step-through `pending` execution; see the `query` module.
## - Results — a `QResult` of `DataChunk`s; `chunk.bindAs(i, kt)` gives a typed
##   `Vector[kt]` for reading, or `Table` for random access.
## - Extend — register scalar UDFs (`registerScalar`), table functions
##   (`registerTableFunction`), or scan your own Nim data as views
##   (`register`).
##
## For examples of every layer, see the `query` and `table_functions` module
## docs, and the cookbook online at
## https://bontavlad.github.io/NimDrake/cookbook/cookbook.html.

import
  /[
    types, config, complex, ffi, database, qresult, codec, table,
    query, table_functions, scalar_functions, replacement_scans, display,
    table_scan, aggregate_functions, catalog, transaction, exceptions,
    struct_mapping,
  ]

when defined(features.nimdrake.arrow):
  import /[arrow, narrow_table_scan]

import /compatibility/tensor_table
export tensor_table

runnableExamples:
  let duck = newDatabase().connect()

  let outcome = duck
    .execute(
      """ SELECT seq AS int_col, 'Value_' || seq::VARCHAR AS varchar_col FROM generate_series(1,3) AS t(seq) """
    )
  for chunk in outcome:
    assert @[1'i64, 2'i64, 3'i64] == chunk.bindAs(0, DuckType.BigInt).toSeq
  for chunk in outcome:
    assert @["Value_1", "Value_2", "Value_3"] == chunk.bindAs(1, DuckType.Varchar).toSeq

export
  types, config, complex, ffi, database, query, qresult, codec, table,
  table_functions, scalar_functions, replacement_scans, display,
  table_scan, aggregate_functions, catalog, transaction, exceptions,
  struct_mapping

when defined(features.nimdrake.arrow):
  export arrow, narrow_table_scan
