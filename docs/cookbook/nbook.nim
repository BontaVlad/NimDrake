import nimibook

var book = initBookWithToc:
  entry("NimDrake Cookbook", "cookbook", numbered = false)
  section("Basics", "basics/index"):
    entry("Database and Connections", "database_and_connections")
    entry("Query Execution", "query_execution")
    entry("Working with Results", "working_with_results")
  section("Advanced Recipes", "advanced/index"):
    entry("Prepared Statements", "prepared_statements")
    entry("Bulk Insert with Appender", "bulk_insert")
    entry("User-Defined Functions", "user_defined_functions")
  section("Data Types", "datatypes/index"):
    entry("Complex Types", "complex_types")
    entry("Arrow Results", "arrow_results")
nimibookCli(book)