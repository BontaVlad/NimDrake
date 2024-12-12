<div align="center">
  <picture>
    <source media="(prefers-color-scheme: light)" srcset="drake-svg-dark-theme.svg">
    <source media="(prefers-color-scheme: dark)" srcset="drake-svg-light-theme.svg">
    <img alt="NimDrake logo" src="drake-svg-light-theme.svg" height="100">
  </picture>
</div>
<br>

## NimDrake

Here should be a short description of the project, this is alpha stage, this is a Nim wrapper over duckdb.
Explain what is duckdb and why is it cool.

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
import nimdrake as ndk

let duck = ndk.connect()

echo duck.execute("SELECT * FROM range(5);")

```

### Example 2: Custom dataframe and some other examples
```nim
import nimdrake as ndk

let duck = ndk.connect()

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
