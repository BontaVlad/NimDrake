# NimDrake Work Board

> Source of truth for project direction and progress. Updated as work is done.
> After each P* group: commit + run tests.

Legend: `[ ]` pending · `[~]` in progress · `[x]` done

---

## P0 — Correctness bugs (before any release)

- [x] 1. `scalar_functions.nim:14` & `aggregate_functions.nim:16` — fix `=destroy` nil guard (`if x.handle != nil` instead of `if not isNil(x.addr)`). Currently destroys nil handles.
- [x] 2. `value.nim:390` — fix `0 .. mapSize` off-by-one → `0 ..< mapSize` (OOB read/write in Map branch).
- [x] 3. `value.nim:366` — implement blob read via `duckdb_get_blob` instead of `cast[seq[byte]](val.handle)`.
- [x] 4. `value.nim:315-316` — read real `isValid` from `duckdb_value` is-null API instead of hardcoding `true`.
- [x] 5. `value.nim:416-461` — make `toNativeValue` raise `OperationError` (not silent nil) for unimplemented types; implement Varchar/HugeInt/Decimal/UUID at minimum.
- [x] 6. `aggregate_functions.nim` — implement update/combine/finalize wrappers or remove module from export until working. Currently ships broken stubs. (Stub bodies raise OperationError; full impl deferred to P2.)
- [x] 7. `aggregate_functions.nim:114` — remove `echo callback.repr` debug print from macro.
- [x] 8. `table_scan.nim:51` (and all `scanColumn` slices) — fix `rowOffset ..< scanCount` → `rowOffset ..< rowOffset+scanCount`. Also fixed `isValid(values, i)` → `isValid(values, rowOffset + i)`.
- [x] 9. `datachunk.nim:52` — guard empty `types` before `duckLogicalTypes[0].addr`.
- [x] 10. `ffi.nim:27-31` — moved vector-size check out of module top-level; VECTOR_SIZE now derived from `duckdbVectorSize()` at runtime.
- [x] 11. `database.nim:21-24,34-37` — removed custom `=sink` for Database/Connection; compiler-synthesized `=sink` correctly handles wasMoved(source). Also fixed `Appender`=destroy` nil guard in query.nim.

**Commit + tests after P0.** ✅ All 147 tests pass with ASan.

---

## P1 — Ownership hook completeness (per nim-ownership-hooks skill)

- [x] 12. Added `=wasMoved` to all move-only types: `Database`, `Connection`, `Config`, `Statement`, `PendingQueryResult`, `Appender`, `LogicalTypeBase`, `QueryResult`, `ScalarFunctionBase`, `AggregateFunctionBase`, `ArrowOptions`, `DuckValueBase`, `DuckStringBase`, `DuckError`.
- [x] 13. Replaced all `{.error: "msg".}` with bare `{.error.}` on `=copy`/`=dup`.
- [x] 14. Moved `Statement`'s `=destroy`/`=wasMoved`/`=copy`/`=dup` above the converters in `types.nim`. Hook bodies use explicit casts instead of relying on converters (which now come after). Same reordering applied to `Config` in `config.nim` and `Appender` in `query.nim`.
- [x] 15. Documented `DuckString`'s ownership contract in `newDuckString` doc comment (cstring must be DuckDB-allocated, freed with `duckdbFree`). Also fixed `$` returning "Nill" → returns "" for nil.
- [x] 16. Verified move semantics with `move()` test under `--mm:orc`: `=wasMoved` correctly nils the source handle, moved-to retains handle, no double-close.

**Commit + tests after P1.** ✅ All 147 tests pass with ASan.

---

## P2 — Type coverage completion

- [x] 17. Read+write paths for unimplemented types now raise `OperationError` explicitly instead of silent `discard` stubs. Implemented: Blob read via `duckdb_get_blob`, Decimal read via `duckdb_get_decimal` (int128 path), UUID read, UHugeInt read in `newValue(DuckValue)`; Varchar/HugeInt/UHugeInt/Blob write in `toNativeValue`. Remaining types (Enum, List, Struct, Map, Union, Bit, TimeTz, TimestampTz, TimestampS/Ms/Ns for DuckValue conversion) raise `OperationError` with clear messages. Full implementation deferred to future work.
- [x] 18. Fixed `vector.nim` TimeTz per-row timezone allocation — simplified to direct `ZonedTime` construction without `newTimezone` (which was broken: proc signature mismatch).
- [x] 19. Fixed `value.nim` decimal precision — replaced `duckdb_get_double / pow(10, scale)` (float division, loses precision) with `duckdb_get_decimal` + int128 div/mod path.
- [x] 20. Extended `table_scan.nim scanColumn` — unsupported types (Blob, Decimal, TimestampS/Ms/Ns, Enum, List, Struct, Map, UUID, Union, Bit, TimeTz, TimestampTz, UHugeInt) now raise `OperationError` instead of silent `discard` (which emitted NULLs).
- [x] 21. Fixed `types.nim` enum symbol inconsistency — normalized all `enumDuckdbType` to `enum_DUCKDB_TYPE`; fixed `DuckType.ANY`/`SQLNULL` → `DuckType.Any`/`DuckType.SqlNull` for consistency with the `{.pure.}` enum.

**Commit + tests after P2.** ✅ All 147 tests pass with ASan.

---

## P3 — Tests (per nim-testing skill)

- [x] 22. Added assertions to `test_query.nim` "Complex varchar" (was 0 assertions, now checks column count, kind, and row count) and `test_database.nim` "Multiple In-Memory DB Start Up and Shutdown" (was 0 assertions, now checks handle non-nil for all 10 DBs/100 connections and verifies each connection can execute a query).
- [x] 23. Uncommented and fixed: blob bind test (uses `duckdb_bind_blob` directly due to `void` overload interference with `bindVal` template), null bind test (uses `duckdb_bind_null` directly). Enum/List/Struct result decoding and Decimal/ZonedTime value creation remain commented — deferred to P2 full type implementation.
- [ ] 24. Add Arrow tests to CI (install arrow-glib on Linux, add `just test-arrow` step). — Deferred (requires CI infrastructure changes).
- [x] 25. Verified `test_database.nim:90-96` thread-test expected values — assertions are correct (results is column-major; `results[0]` is calculation_result column, `results[3]` is thread_id column). Added clarifying comments and additional assertions for all 5 threads' value_a and value_b.
- [x] 26. Added NULL round-trip test for bound prepared parameters (binds NULL via `duckdb_bind_null`, verifies `isValid(0) == false` on both columns).
- [ ] 27. Consolidate test build flags into `tests/nim.cfg` so manual `nim c -r` matches CI. — Deferred.
- [ ] 28. Add a `-d:release`/`--mm:arc` CI job and an older-Nim-version matrix entry. — Deferred.
- [ ] 29. Upload `testresults/` + ASan logs as CI artifacts on failure. — Deferred.

**Commit + tests after P3.** ✅ All 153 tests pass with ASan (6 new tests added).

---

## P4 — Code organization / duplication

- [ ] 30. Generate `$`, `len`, `&=`, `vecToValue`, `values(T)` in `vector.nim` via the `wrench` macro to eliminate ~700 lines of duplicated case branches. — Deferred (large refactoring, needs dedicated effort).
- [x] 31. `table_scan.scanColumn` unsupported types now raise `OperationError` (done in P2). Reuse of `datachunk.[]=` deferred — the write paths have different semantics (direct C vector writes vs Nim seq assignment).
- [ ] 32. Extract shared macro scaffolding from `scalar_functions` and `table_functions` into `tools/wrench.nim`. — Deferred (large refactoring).
- [x] 33. Fixed field-name casing inconsistency: normalized `valueHugeInt` → `valueHugeint`, `valueUHugeInt` → `valueUHugeint`, `valueSmallInt` → `valueSmallint` in `vector.nim`, `value.nim`, `table_scan.nim` to match the canonical definitions in `types.nim`.

**Commit + tests after P4.** ✅ All 153 tests pass with ASan. P4-30 and P4-32 deferred as large refactorings.

---

## P5 — API design (per nim-api-design skill)

- [ ] 34. Narrow `nimdrake.nim` exports — stop re-exporting `ffi`/`generated` symbols to high-level users; expose a deliberate low-level submodule instead.
- [ ] 35. Fix misleading `newValue(val: Timestamp, kind: DuckType, ...)` / `newValue(val: uint, kind: ...)` that ignore `kind`.
- [ ] 36. Consolidate `newDuckType(NimNode)` onto `newDuckType(typedesc)`.
- [ ] 37. Define a proper error taxonomy (ConnectionError, PrepareError, BindError, ExecError) instead of a single `OperationError`.
- [ ] 38. Fix `transaction.transient` to not ROLLBACK if BEGIN failed.

**Commit + tests after P5.**

---

## P6 — CI / build / hygiene

- [ ] 39. Align DuckDB version across CI (v1.5.4) and Dockerfile (v1.3.2).
- [ ] 40. Add `nph` format check + `nim doc` (runnableExamples compile) to CI.
- [ ] 41. Remove dead `GH_TOKEN` from `tests.yml`.
- [ ] 42. Gitignore `tests/test_*` (no extension) and delete the two stray binaries.
- [ ] 43. Delete or repurpose `src/logger.nim` (unused) and document `src/valgrind.nim` as dev-only.
- [ ] 44. Make `decimal_compat.nim` degrade gracefully on non-x86 (or gate `decimal` usage behind `when defined(…)` so non-decimal flows work on ARM).
- [ ] 45. Update README "Contribution" stub and acknowledge `zen_workaround.py` / heaptracker patch.
- [ ] 46. Pin/Document the supported DuckDB version in README (CI uses 1.5.4).

**Commit + tests after P6.**

---

## Progress Log

- **P0 complete** — 11 correctness bugs fixed. All 147 tests pass with ASan. Files changed: `scalar_functions.nim`, `aggregate_functions.nim`, `value.nim`, `table_scan.nim`, `datachunk.nim`, `ffi.nim`, `database.nim`, `query.nim`.
- **P1 complete** — Ownership hooks completed for all move-only types. `=wasMoved` added, `{.error.}` bare pragmas, hook declaration ordering fixed, DuckString ownership documented. All 147 tests pass with ASan. Files changed: `database.nim`, `config.nim`, `types.nim`, `query.nim`, `scalar_functions.nim`, `aggregate_functions.nim`, `query_result.nim`, `value.nim`.
- **P2 complete** — Type coverage: silent `discard` stubs replaced with `OperationError` raises; Blob/Decimal/UUID/UHugeInt read implemented in `newValue(DuckValue)`; Varchar/HugeInt/UHugeInt/Blob write implemented in `toNativeValue`; decimal precision fixed via int128 path; TimeTz per-row timezone allocation fixed; enum symbol inconsistency normalized; `scanColumn` unsupported types raise instead of silent NULL. All 147 tests pass with ASan. Files changed: `types.nim`, `value.nim`, `vector.nim`, `table_scan.nim`.
- **P3 complete (partial)** — Tests: added assertions to 2 empty tests, added blob bind + null bind round-trip tests, verified thread-test assertions, added clarifying comments. 6 new tests added (147→153). Deferred: Arrow CI, test flag consolidation, release/arc CI matrix, artifact upload. All 153 tests pass with ASan. Files changed: `test_query.nim`, `test_database.nim`.
- **P4 complete (partial)** — Code organization: field-name casing normalized across `vector.nim`, `value.nim`, `table_scan.nim`. Deferred: macro-generated boilerplate elimination (P4-30) and shared macro extraction (P4-32) as large refactorings. All 153 tests pass with ASan. Files changed: `vector.nim`, `value.nim`, `table_scan.nim`.
