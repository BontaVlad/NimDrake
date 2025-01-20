import std/[strformat, tables]
import /[api, exceptions]

## DuckDB has a number of configuration options that can be used to change the behavior of the system.
## The configuration options can be set using either the SET statement or the PRAGMA statement.
## They can be reset to their original values using the RESET statement.
## The values of configuration options can be queried via the current_setting() scalar function or using the duckdb_settings() table function.

type
  Config* = distinct ptr duckdbConfig
  ConfigValues* = Table[string, string]

converter toBase*(c: ptr Config): ptr duckdbConfig =
  cast[ptr duckdbConfig](c)

converter toBase*(c: Config): duckdbConfig =
  cast[duckdbConfig](c)

proc `=destroy`*(conf: Config) =
  if not isNil(conf.addr):
    duckdbDestroyConfig(conf.addr)

proc setConfig*(config: Config, name: string, option: string) =
  ## Sets the specified option for the specified configuration. The configuration option is indicated by name. To obtain a list of config options, see duckdb_get_config_flag.
  ##This can fail(raises OperationError) if either the name is invalid, or if the value provided for the option is invalid.

  runnableExamples:
    import nimdrake

    let conf = newConfig()
    conf.setConfig("threads", "8")

    let con = newDatabase(conf).connect()
    let outcome =
      con.execute("SELECT current_setting('threads') AS threads;").fetchall()
    assert outcome[0].valueBigint == @[8'i64]

    conf.setConfig("threads", "2")

    let con2 = newDatabase(conf).connect()
    let outcome2 =
      con2.execute("SELECT current_setting('threads') AS threads;").fetchall()
    assert outcome2[0].valueBigint == @[2'i64]

  check(
    duckdbSetConfig(config, name.cstring, option.cstring),
    fmt"Unrecognized configuration option {name}",
    `=destroy`(config),
  )

proc newConfig*(): Config =
  ## Initializes an empty configuration object that can be
  ## used to provide start-up options for the DuckDB instance
  runnableExamples:
    import nimdrake

    let conf = newConfig()

  result = Config(nil)
  check(duckdbCreateConfig(result.addr), "Failed to create config")

proc newConfig*(values: ConfigValues): Config =
  ## Initializes a configuration object from a table, used to provide start-up options for the DuckDB instance

  runnableExamples:
    import std/tables
    import nimdrake

    let conf = newConfig({"threads": "3"}.toTable)

    let con = newDatabase(conf).connect()
    let outcome =
      con.execute("SELECT current_setting('threads') AS threads;").fetchall()
    assert outcome[0].valueBigint == @[3'i64]

  result = newConfig()
  for key, value in values:
    result.setConfig(key, value)
