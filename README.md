<div align="center">
  <picture>
    <source media="(prefers-color-scheme: light)" srcset="drake-svg-light-theme.svg">
    <source media="(prefers-color-scheme: dark)" srcset="drake-svg-dark-theme.svg">
    <img alt="NimDrake logo" src="drake-svg-light-theme.svg" height="200">
  </picture>
</div>
<br>

## NimDrake

NimDrake is a [Nim](https://nim-lang.org/) language wrapper for [DuckDB](https://duckdb.org/), a high-performance analytical database system known for its speed, reliability, portability, and ease of use. DuckDB provides a rich SQL dialect that goes far beyond basic SQL, supporting features like arbitrary and nested correlated subqueries, window functions, collations, and complex types (arrays, structs, maps).  Several extensions further simplify SQL usage. 

**Please note:** NimDrake is currently in a pre-alpha stage and is considered experimental. It contains bugs and lacks some intended features. Use with caution and report any issues you encounter.

---

## Installation

Here should be the nimble installtion when this code is ok to be published, but 
it should contain also the manual way

1. Clone this repository to your local machine:
   ```bash
   git clone https://github.com/foo/bar
   ```

2. Navigate to the repository folder:
   ```bash
   nimble install NimDrake
   ```

## Code Examples

Here are a few simple examples of how to use this repository:

### Example 1: Simple query
```nim
import nimdrake

let duck = connect()

echo duck.execute("SELECT * FROM range(100) AS example;")

# Environment Variables for Controlling Dataframe Display Options
# - **display_show_index** (True/False): Determines whether to show or hide row index columns. Set `True` to display indexes, `False` to hide them.  
# - **display_max_rows**: Specifies the maximum number of rows displayed in a dataframe output.
# - **display_max_columns** (Default 100): Restricts the maximum number of columns to be shown at once to prevent overwhelming displays; set to `100` as default.
# - **display_clip_column_name**: Limits the length of column names displayed, which can help in keeping outputs clean when dealing with long-named columns. Set it to `20`.

# output:
┌───────┬───────────────┐
│  #    │     range     │
├───────┼───────────────┤
│  0    │     0         │
│  1    │     1         │
│  2    │     2         │
│  3    │     3         │
│  4    │     4         │
│  ...  │     ...       │
│  95   │     95        │
│  96   │     96        │
│  97   │     97        │
│  98   │     98        │
│  99   │     99        │
└───────┴───────────────┘

```

### Example 2: Access query results using the Vector Interface.
```nim
let duck = connect()

let outcome = duck.execute(""" SELECT seq AS int_col, 'Value_' || seq::VARCHAR AS varchar_col FROM generate_series(1,3) AS t(seq) """).fetchAll()
echo outcome[0].valueBigint # -> @[1, 2, 3]
echo outcome[1].valueVarchar # -> @["Value_1", "Value_2", "Value_3"]

# we can also access by column name

let outcome = duck.execute(""" SELECT seq AS int_col, 'Value_' || seq::VARCHAR AS varchar_col FROM generate_series(1,3) AS t(seq) """).fetchAllNamed()
echo outcome["int_col"].valueBigint # -> @[1, 2, 3]
echo outcome["varchar_col"].valueVarchar # -> @["Value_1", "Value_2", "Value_3"]

```

### Example 3: Using the row iterator interface
```nim
let duck = connect()

let task = duck.execute(""" SELECT seq AS int_col, 'Value_' || seq::VARCHAR AS varchar_col FROM generate_series(1,3) AS t(seq) """)
for i, row in enumerate(task.rows):
  echo fmt"row {i}: ({row[0]}, {row[1]})"
  
#output:
# row 0: (1, Value_1)
# row 1: (2, Value_2)
# row 2: (3, Value_3)
```

---

## Contribution

Talk about justfiles and the commands

---

## Acknowledgments

A special thanks to:

- The **Nim programming community** for their support and inspiration.
- Some third party libraries
- Futhhark project

Feel free to fork, contribute, and share this repository. 

---
