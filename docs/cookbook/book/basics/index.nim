import nimib, nimibook
import ../cookbook_theme

nbInit(theme = useCookbook)

nbText: """
# Basics

Fundamental recipes for opening a database, running queries, and reading
results. Every recipe creates its own connection so that it can run
independently.

## Contents

* [Database and Connections](database_and_connections.html)
* [Query Execution](query_execution.html)
* [Working with Results](working_with_results.html)
"""
nbSave