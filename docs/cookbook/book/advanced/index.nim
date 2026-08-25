import nimib, nimibook
import ../cookbook_theme

nbInit(theme = useCookbook)

nbText: """
# Advanced Recipes

Recipes that go beyond plain SQL: parameterized statements, high-throughput
inserts, and moving logic into the database with user-defined functions.

## Contents

* [Prepared Statements](prepared_statements.html)
* [Bulk Insert with Appender](bulk_insert.html)
* [User-Defined Functions](user_defined_functions.html)
"""
nbSave