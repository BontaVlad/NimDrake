import std/[strformat, tables]
import /[ffi, exceptions, arc]

## DuckDB has a number of configuration options that can be used to change the behavior of the system.
## The configuration options can be set using either the SET statement or the PRAGMA statement.
## They can be reset to their original values using the RESET statement.
## The values of configuration options can be queried via the current_setting() scalar function or using the duckdb_settings() table function.

arcResource(duckdbDestroyConfig):
  type
    Config* = object
      handle: duckdbConfig
    ConfigValues* = Table[string, string]

proc setConfig*(config: Config, name: string, option: string) =
  ## Sets the specified option for the specified configuration. The configuration option is indicated by name. To obtain a list of config options, see duckdb_get_config_flag.
  ## This can fail(raises OperationError) if either the name is invalid, or if the value provided for the option is invalid.

  runnableExamples:
    let conf = newConfig()
    conf.setConfig("threads", "8")

  check(
    duckdbSetConfig(config.rawHandle, name.cstring, option.cstring),
    fmt"Unrecognized configuration option {name}",
  )

proc newConfig*(): Config =
  ## Initializes an empty configuration object that can be
  ## used to provide start-up options for the DuckDB instance
  runnableExamples:
    let conf = newConfig()

  result = Config()
  check(duckdbCreateConfig(result.handle.addr), "Failed to create config")

proc newConfig*(values: ConfigValues): Config =
  ## Initializes a configuration object from a table, used to provide start-up options for the DuckDB instance

  runnableExamples:
    import std/tables

    let conf = newConfig({"threads": "3"}.toTable)

  result = newConfig()
  for key, value in values:
    result.setConfig(key, value)
