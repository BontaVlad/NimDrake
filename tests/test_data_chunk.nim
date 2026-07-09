import unittest2
import ../src/[database, query, qresult, types]

suite "DataChunk read-only API":
  test "chunk vector access + bindAs":
    let duck = newDatabase().connect()
    let r = duck.executeMaterialized(
      "SELECT 1::INTEGER AS idx, 'hello'::VARCHAR AS name, true::BOOLEAN AS flag"
    )
    for chunk in r:
      check chunk.vector(0).kind == DuckType.Integer
      check chunk.vector(1).kind == DuckType.Varchar
      check chunk.vector(2).kind == DuckType.Boolean
      check chunk.bindAs(0, DuckType.Integer).toSeq == @[1'i32]
      check chunk.bindAs(1, DuckType.Varchar).toSeq == @["hello"]
      check chunk.bindAs(2, DuckType.Boolean).toSeq == @[true]
