import unittest
import std/tables
import ../../src/[config, query, query_result, database, exceptions]

suite "database config":
  test "Settings before database init with setConfig":
    let config = newConfig()
    config.setConfig("threads", "8")

    let con = connect(config)
    let outcome =
      con.execute("SELECT current_setting('threads') AS threads;").fetchall()
    assert outcome[0].valueBigint == @[8'i64]

    config.setConfig("threads", "2")

    let con2 = connect(config)
    let outcome2 =
      con2.execute("SELECT current_setting('threads') AS threads;").fetchall()
    assert outcome2[0].valueBigint == @[2'i64]

  test "Settings before database init directly from initialization":
    let config = newConfig({"threads": "3"}.toTable)

    let con = connect(config)
    let outcome =
      con.execute("SELECT current_setting('threads') AS threads;").fetchall()
    assert outcome[0].valueBigint ==
      @[3'i64]

        # triggers the memory sanitizer
        # test "Incorrect setting key should throw an error":
        #   doAssertRaises(OperationError):
        #     let
        #       config = newConfig({"invalid": "3"}.toTable)
        #       con = connect(config)

        # test "Incorrect setting value should throw an error":
        #   doAssertRaises(OperationError):
        #     let config = newConfig({"threads": "invalid"}.toTable)
