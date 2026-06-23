## Arrow integration module for NimDrake.
##
## This module provides the bridge between DuckDB query results and Apache Arrow
## via the `narrow` package. It is only available when the `features.nimdrake.arrow`
## feature is enabled at build time:
##
##   nimble install --parser:declarative --features:arrow
##
## The actual `fetchAsArrow` proc is defined in `query_result.nim` and re-exported
## from `nimdrake.nim`.

when defined(features.nimdrake.arrow):
  import ffi, query, database, query_result
  import narrow/column/metadata
  import narrow/tabular/[table, batch]

  export query_result.fetchAsArrow
