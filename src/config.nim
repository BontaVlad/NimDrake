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
  check(
    duckdbSetConfig(config, name.cstring, option.cstring),
    fmt"Unrecognized configuration option {name}",
    `=destroy`(config),
  )

proc newConfig*(): Config =
  ## Initializes an empty configuration object that can be
  ## used to provide start-up options for the DuckDB instance
  result = Config(nil)
  check(duckdbCreateConfig(result.addr), "Failed to create config")

proc newConfig*(values: ConfigValues): Config =
  result = newConfig()
  for key, value in values:
    result.setConfig(key, value)
