import nimib, nimibook
import ../cookbook_theme

nbInit(theme = useCookbook)

nbText: """
# Data Types

Recipes for working with non-trivial DuckDB types: nested and structured
values, and results that map to Arrow arrays.

## Contents

* [Complex Types](complex_types.html)
* [Struct Mapping](struct_mapping.html)
* [Arrow Results](arrow_results.html)
"""
nbSave
