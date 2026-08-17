## DuckDB start-up configuration: tune options such as worker threads or
## memory limits at database creation time.
##
## Options can also be set later with the SQL `SET`/`PRAGMA` statements,
## read with `current_setting()`, and reset with `RESET` — but a `Config`
## applies **only** at `newDatabase` time, before the first connection.
## See `duckdb_settings()` for the option catalog.
import std/[strformat, tables]
import /[ffi, exceptions, arc]

arcResource(duckdbDestroyConfig):
  type
    Config* = object
      handle: duckdbConfig
    ConfigValues* = Table[string, string] ## Option name → value pairs.

proc setConfig*(config: Config, name: string, option: string) =
  ## Sets the option `name` to `option` on `config`. Returns nothing or
  ## raises `OperationError` if the name is unknown or the value is invalid.
  ## Call this before passing the Config to `newDatabase`.

  runnableExamples:
    let conf = newConfig()
    conf.setConfig("threads", "8")

  check(
    duckdbSetConfig(config.rawHandle, name.cstring, option.cstring),
    fmt"Unrecognized configuration option {name}",
  )

proc newConfig*(): Config =
  ## Creates an empty configuration; pass it to `newDatabase` to apply the
  ## options you then set with `setConfig`.

  runnableExamples:
    let conf = newConfig()

  result = Config()
  check(duckdbCreateConfig(result.handle.addr), "Failed to create config")

proc newConfig*(values: ConfigValues): Config =
  ## Creates a configuration pre-filled from the option `values` table.
  ## All keys must be valid DuckDB option names or the construction raises.

  runnableExamples:
    import std/tables

    let conf = newConfig({"threads": "3"}.toTable)

  result = newConfig()
  for key, value in values:
    result.setConfig(key, value)
