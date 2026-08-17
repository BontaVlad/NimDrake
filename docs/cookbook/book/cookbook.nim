import nimib, nimibook

nbInit(theme = useNimibook)

nbText: """
# NimDrake Cookbook

Recipes for common tasks when working with DuckDB in Nim using
[NimDrake](https://github.com/BontaVlad/NimDrake).

For the complete API reference for every exported symbol, see the
[API documentation](https://bontavlad.github.io/NimDrake/theindex.html).

Every recipe in this book is executed while the book is built: the code
snippet is compiled and run, and its response is included below the snippet.
If a recipe stops working, the book build fails.
"""

nbText: """
## Getting started

Import `nimdrake` and open an in-memory database:

```nim
import nimdrake

let con = newDatabase().connect()
```

All recipes assume these imports and a live connection `con`.

## Contents

* [Database and Connections](database_and_connections.html)
* [Query Execution](query_execution.html)
* [Working with Results](working_with_results.html)
* [Prepared Statements](prepared_statements.html)
* [Bulk Insert with Appender](bulk_insert.html)
* [User-Defined Functions](user_defined_functions.html)
* [Complex Types](complex_types.html)
"""
nbSave