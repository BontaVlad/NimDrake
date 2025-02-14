import
  /[
    types, config, api, database, query, query_result, table_functions, scalar_functions, vector, value
  ]

## NimDrake is a Nim language package designed to integrate with **DuckDB**,
## an in-process SQL OLAP database management system. It simplifies database interactions while maintaining flexibility for advanced use cases.
## NimDrake is built with two ideas in mind, the high-level interface offers quick and easy database operations, ideal for rapid development and simplicity,
## and a lower-level interface that directly interacts with DuckDB's core functionalities, enabling complex or high-performance implementations when necessary.
## This dual-layer approach ensures that NimDrake caters to both beginners and advanced users.

runnableExamples:
  let duck = newDatabase().connect()

  let outcome = duck
    .execute(
      """ SELECT seq AS int_col, 'Value_' || seq::VARCHAR AS varchar_col FROM generate_series(1,3) AS t(seq) """
    )
    .fetchAll()
  assert @[1'i64, 2'i64, 3'i64] == outcome[0].valueBigint
  assert @["Value_1", "Value_2", "Value_3"] == outcome[1].valueVarchar

export
  types, config, api, database, query, query_result, table_functions, scalar_functions, vector, value
