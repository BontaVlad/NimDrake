import nimib, nimibook
import ./cookbook_theme

nbInit(theme = useCookbook)

nbText: """
# NimDrake Cookbook

Recipes for common tasks when working with DuckDB in Nim using
[NimDrake](https://github.com/BontaVlad/NimDrake).

For the complete API reference for every exported symbol, see the
[API documentation](https://bontavlad.github.io/NimDrake/theindex.html).

Every core recipe in this book is executed while the book is built: the code
snippet is compiled and run, and its response is included below the snippet.
If a core recipe stops working, the book build fails.

The recipes use three result paths:

* Use `execute` for small results and one-off SQL.
* Use `executeStreaming` when the result can be large or when you want to
  process one DuckDB chunk at a time.
* Use typed vectors when the result schema is known and you want typed,
  zero-copy reads. Materialize a `Table` only when you need random access
  across chunks.

The Arrow chapter is optional. Its executable snippets run when the cookbook
is built with `-d:features.nimdrake.arrow` and the Arrow GLib libraries.
"""

nbText: """
## Getting started

Import `nimdrake` and open an in-memory database. A `Database` owns the
DuckDB instance. Create one `Connection` for each independent query flow.

```nim
import nimdrake

let con = newDatabase().connect()
```

Most recipes create their own connection so that they can run independently.
When a recipe uses `con`, it means a live connection created with this pattern.

## Contents

* [Basics](basics/index.html)
  * [Database and Connections](basics/database_and_connections.html)
  * [Query Execution](basics/query_execution.html)
  * [Working with Results](basics/working_with_results.html)
* [Advanced Recipes](advanced/index.html)
  * [Prepared Statements](advanced/prepared_statements.html)
  * [Bulk Insert with Appender](advanced/bulk_insert.html)
  * [User-Defined Functions](advanced/user_defined_functions.html)
* [Data Types](datatypes/index.html)
  * [Complex Types](datatypes/complex_types.html)
  * [Struct Mapping](datatypes/struct_mapping.html)
  * [Arrow Results](datatypes/arrow_results.html)
"""
nbSave
