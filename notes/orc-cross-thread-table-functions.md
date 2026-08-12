# ORC, cross-thread table-function callbacks, and `destroyInit` SIGSEGV

## Symptom

`test_table_functions` crashed on Windows CI (`Error: execution of an external
program failed: ...test_table_functions.exe`) but passed on Linux/macOS.
A minimal repro crashed ~5/10 on Linux too, *only* with
`--mm:orc --threads:on`, never with `--mm:arc` or `--threads:off`.

Stack trace bottom:

```
table_functions.nim  destroyInit
system/orc.nim       nimDecRefIsLastCyclicDyn
system/orc.nim       rememberCycle
system/orc.nim       unregisterCycle
SIGSEGV: Attempt to read from nil?
```

## Root cause

DuckDB runs a table function's `init`, `main`, and `destroy` callbacks on
**whichever OS thread its scheduler picks**. ORC's cycle bookkeeping
(`roots`, `rootsThreshold`) is `{.threadvar.}` — **per OS thread**.

The `registerTableFunction` macro generated, inside `mainProc`:

```nim
let initData = cast[InitData](duckdb_function_get_init_data(info))
var it = initData.iter      # <-- the bug
```

Because `initData` is a `ref`, Nim compiles `var it = initData.iter` as an
**owning** `=copy` of the closure:

1. `nimIncRefCyclic(env)` — env rc 0 → 1
2. at `mainProc` scope end: `=destroy(it)` → `nimDecRefIsLastCyclicDyn(env)`
   - rc is now 1 → 0 but **not last** (zero-based; the field still owns one),
     so `rememberCycle(false, env)` → `registerCycle(env)` →
     `env.rootIdx = K` written into **this thread's `roots`** (the worker).
3. Later, `destroyInit` on the **Nim/main thread** does `=destroy(InitData.iter)`
   → last dec → `rememberCycle(true, env)` → `env.rootIdx == K > 0` →
   `unregisterCycle(env)` uses `K` to index the **main thread's `roots`** —
   a different array → out-of-bounds read → **SIGSEGV**.

The cell header (`rootIdx`) is in the cell's own memory, so it **survives the
thread switch**; the per-thread `roots` array does not.

## Fix

Borrow the iterator as a non-owning `.cursor` — no incRef/decRef on the worker
thread, so no `registerCycle` runs there and `rootIdx` is never set cross-thread:

```nim
mainBody.add(newVarStmt(
  nnkPragmaExpr.newTree(itSym, nnkPragma.newTree(ident"cursor")),
  newDotExpr(ident"initData", ident"iter")))
```

Streaming is preserved: DuckDB still calls `it()` call-by-call on the worker;
only the refcount bookkeeping is removed.

## Why `GC_ref` is not the fix

`GC_ref(data)` is already done in `initProc` (keeps `InitData` alive while
DuckDB holds the raw pointer). Adding `GC_ref` on the env only raises rc; it
does not stop the **intermediate** incRef+non-last-dec that `mainProc`'s owning
copy performs on the worker — that's what calls `registerCycle` in the wrong
thread. The issue isn't premature free; it's cross-thread cycle registration.

## What to check when this class of crash comes back

A SIGSEGV inside `unregisterCycle`/`registerCycle` under `--mm:orc`:

1. Is `--threads:on`? Does the crash go away with `--threads:off` or
   `--mm:arc`? (Both point at ORC threadvar confusion, not a refcount bug.)
2. Is any Nim ref round-tripped through a C library callback that may run on
   another thread?
3. If so: is that ref **registered** (non-last decrement → `registerCycle`)
   on one thread but **unregistered** (last decrement → `unregisterCycle`)
   on another? A single `register`↔`unregister` pair split across threads is
   enough to crash.
4. The fix is to make every Nim-managed ref touched by the C callback be
   *allocated, refcount-decremented, and freed* on the same Nim-registered
   thread. Borrow via `.cursor`/`ptr` on the foreign thread; or move the
   owning ref onto a Nim-owned thread.

## Repro recipe (kept for posterity)

```bash
nim c -r --mm:orc --threads:on --opt:none -d:debug -d:useMalloc \
  --passL:"-Lsrc/include" --passL:"-lduckdb" \
  --passL:"-Wl,-rpath,src/include" repro.nim   # ~50% crash
nim c -r --mm:arc   ...   # 0% crash
nim c -r --threads:off ... # 0% crash
```

Where `repro.nim` is: connect, `registerTableFunction(countToN)`, execute
`SELECT * FROM countToN(3)`, discard the result, leave the block.
The crash is flaky because DuckDB only spawns a worker when its scheduler
decides to — small queries sometimes run inline on the Nim thread.