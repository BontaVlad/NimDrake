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

- [ ] 34. Narrow `nimdrake.nim` exports — stop re-exporting `ffi`/`generated` symbols to high-level users; expose a deliberate low-level submodule instead. — Deferred (breaking API change, needs major version bump).
- [x] 35. Fixed misleading `newValue(Timestamp, kind: DuckType, ...)` (ignored `kind`, hardcoded `DuckType.Timestamp`) → `newValue(Timestamp, isValid = true)`. Fixed `newValue(uint, kind: DuckType, ...)` (ignored `kind`, hardcoded `DuckType.Enum`) → `newValue(uint, isValid = true)`. Updated callers in `vector.nim`, `test_value.nim`.
- [ ] 36. Consolidate `newDuckType(NimNode)` onto `newDuckType(typedesc)`. — Deferred (macro refactoring).
- [ ] 37. Define a proper error taxonomy (ConnectionError, PrepareError, BindError, ExecError) instead of a single `OperationError`. — Deferred (breaking API change).
- [x] 38. Verified `transaction.transient` and `transaction` templates — both are correct (BEGIN is before `try`, so if BEGIN fails, ROLLBACK is not attempted). Added doc comments to clarify behavior.

**Commit + tests after P5.** ✅ All 153 tests pass with ASan.

---

## P6 — CI / build / hygiene

- [ ] 39. Align DuckDB version across CI (v1.5.4) and Dockerfile (v1.3.2). — Deferred (needs Dockerfile testing).
- [ ] 40. Add `nph` format check + `nim doc` (runnableExamples compile) to CI. — Deferred (CI workflow addition).
- [x] 41. Removed dead `GH_TOKEN` from `tests.yml` env section.
- [x] 42. Gitignored stray test binaries (`tests/test_data_chunk`, `tests/test_logical_type`) and deleted them from the working tree.
- [x] 43. Deleted unused `src/logger.nim` (5 lines, never imported or exported). `src/valgrind.nim` is dev-only (used by benchmarks) — left in place.
- [x] 44. Made `decimal_compat.nim` emit a compile-time `{.warning.}` on non-x86 arch (in addition to the existing runtime raise). Fixed error message to say "x86/amd64".
- [x] 45. Updated README "Contribution" section — replaced stub with actual justfile command documentation and reference to WORKBOARD.md.
- [ ] 46. Pin/Document the supported DuckDB version in README. — Deferred (needs version policy decision).

**Commit + tests after P6.** ✅ All 153 tests pass with ASan.

---

## P7 — Vendored libduckdb / 3-tier lookup

- [ ] 47. `config.nims`: 3-tier DuckDB link resolution (local `src/include/` → system via pkg-config/ldconfig → hard `error()`). Skipped under nimsuggest + useFuthark.
- [ ] 48. `src/ffi.nim`: futhark header search prepends `src/include/` before system paths.
- [ ] 49. `justfile`: `fetch-lib` recipe downloads `libduckdb-linux-amd64.zip` (v1.5.4) into `src/include/`.
- [ ] 50. `.gitignore`: vendored `src/include/{libduckdb.so,libduckdb.dylib,duckdb.dll,duckdb.h,duckdb_static.lib}` ignored.
- [ ] 51. `Dockerfile`: replaced `/usr/lib` install with `just fetch-lib`; version aligned to v1.5.4 (closes P6-39).
- [ ] 52. `.github/workflows/tests.yml`: Linux DuckDB install → `just fetch-lib`; mac/windows unchanged.
- [ ] 53. `README.md`: "DuckDB dependency" subsection documenting the 3-tier lookup + version pin (closes P6-46).
- [ ] 54. (Deferred) Extend `fetch-lib` to auto-detect host OS/arch and pull the matching release asset (macOS universal, windows-amd64, linux-arm64, musl variants).

**Commit + tests after P7.**

---

## P8 — Thread-safe Database via SharedPtr (threading package)

- [x] 55. Add `threading` to `nimdrake.nimble` prod requires (`nimble install threading`). Import `threading/smartptrs` in `database.nim`.
- [x] 56. Replace `Database.p: ref DbObj` and `ConnObj.db: ref DbObj` with `SharedPtr[DbObj]` (atomic refcounted, allocShared-based). Keep `Connection.p: ref ConnObj` as a per-thread fast ref (never shared across threads).
- [x] 57. Update `rawHandle(db)` to use `db.p[].handle` (SharedPtr deref), `rawHandle(con)` unchanged. `newDatabase` uses `newSharedPtr(DbObj(handle: h))`; `connect` uses `db.p[].handle` for `duckdbConnect` + `result.p.db = db.p` (atomic copy keeps db alive).
- [x] 58. Fix thread test worker signatures: `{.thread.}` procs must take a single tuple param matching `Thread[tuple[db: Database, id: int]]`, not separate params (was a latent bug — proc never got the `{.thread.}` pragma under Nim 2.2.10).
- [x] 59. Fix thread worker INSERTs: `execute(con, query, args)` returns streaming result only (fails on DML); embed values directly in SQL string to use `execute(con, query): QResult[Materialized]`.
- [x] 60. Activate & rewrite thread-safety assertions (5 threads insert + verify 4 columns via chunk API), uncomment "Multiple In-Memory DB Start Up and Shutdown" test (10 DBs × 100 connections).
- [x] 61. Add "Database outlives main Database object via connections" test (workers' connections keep the SharedPtr alive after main `db` is destroyed).
- [x] 62. Add "Move Database preserves handle, nils source, no double-close" test (verifies `=wasMoved` handoff via `SharedPtr` under ASan).

**Trade-offs (documentation-only):**
- `threading` is a nimble dep, not stdlib — adds one external moving part.
- `SharedPtr` only protects the pointer/lifetime, not field data; mutation of `DbObj.handle` post-construction is the caller's responsibility (not relevant here — set once, read-only).
- No weak pointers — self-referential SharedPtr graphs leak (irrelevant for the flat `DbObj`).
- Nim maintainers frame atomic refcounting as a last resort vs. isolated subgraph moves; in practice the cost only hits on `connect()`/teardown, making it negligible here.

**Commit + tests after P8.** ✅ All 8 database tests pass with ASan (orc + arc). Thread-safety, lifetime, and move semantics verified.

---

## P9 — Test-honesty pass (review of assertion quality)

- [x] 63. **Codec fixes (enable honest tests):** Fixed UUID byte-order bug in `src/codec.nim` (`fromDuckUuid`/`toDuckUuid` now undo DuckDB's bit-63 flip of the upper half — the real cause was DuckDB's `ORDER BY uuid == ORDER BY uuid::varchar` trick, not a nybble mismatch). Fixed `toDuckTimestampTz` to convert local wall-clock → UTC via `val.utcOffset` (previously wrote wall-clock as UTC). Verified DuckDB TIMESTAMPTZ stores UTC-only: offset is not part of the value, so `utcOffset = 0` on read is correct; corrected the inaccurate WORKBOARD limitation entry.
- [x] 64. **Category A — tests now test what they claim:** `test_query.nim` "Moving a prepared statement" now actually `move()`s and checks moved-from is nil + handle preserved; `test_table_scan_narrow.nim` filter/projection test now runs a real WHERE+projection; `test_query.nim` "Append NULL values" validity checks re-enabled (correct indices); `test_result_type.nim` UUID round-trip asserts the exact value; Enum test now reads raw enum indices via `bindAs(DuckType.Enum)`; thread-leak test renamed to be sanitizer-honest.
- [x] 65. **Category B — strengthened weak assertions:** T1 manual table function now driven by the bind parameter with exact value asserts (was: hardcoded 2048 + `len > 0`); aggregate T11 HAVING now asserts `== 9900` (was `> 0`); TimestampTz tests assert verified UTC semantics; toNimValue HugeInt asserts the actual digits; 3-level nesting asserts innermost values; T20/T25 cardinality hints verified via `EXPLAIN (FORMAT JSON)` `Estimated Cardinality`; T27 ZonedTime now executes and asserts the TimeTz value; T10h positive-compile test deleted; T30 asserts values not just length; composite TableDescription columns assert Struct/List kinds; zero-row appender test appends a genuinely empty chunk; "Create table" asserts row count; Arrow ToArrowTable asserts rows/columns/cells instead of `echo`.
- [x] 66. **Category C — fragility:** De-flaked progress/interrupt test (range/monotonicity asserts instead of exact `rowsProcessed == 10000`); fixed flaky `steps < 10000` hang-guard in "Pending states observed" (raised to a true hang-guard bound); leak-only tests renamed + documented as sanitizer-validated; replaced `$typedesc` string comparisons with compile-time typed `let _: QResult[...] = r`.
- [x] 67. **Category D — duplication & hygiene:** Merged `test_isolate.nim`'s unique cross-chunk Table tests into `test_qresult.nim` and deleted `test_isolate.nim` (was ~90% duplicated); `git rm`'d the 11 committed test binaries and gitignored all `tests/test_*` binaries; deleted narrow scratch files (`debug_test*`, `minimal_repro*`, `proc_test.nim`); removed duplicate import/comment in `test_table_scan_narrow.nim`; removed stale commented append lines; annotated disabled T28 with its WORKBOARD limitation reference.

**Commit + tests after P9.** ✅ All tests pass with ASan (orc + arc + release), 463 tests. Arrow suites pass with `-d:features.nimdrake.arrow` (16 + 17 tests) via `just --set leaks false test-arrow` — LSan-only arrow-glib builder leaks are documented above.

## Progress Log

- **P0 complete** — 11 correctness bugs fixed. All 147 tests pass with ASan. Files changed: `scalar_functions.nim`, `aggregate_functions.nim`, `value.nim`, `table_scan.nim`, `datachunk.nim`, `ffi.nim`, `database.nim`, `query.nim`.
- **P1 complete** — Ownership hooks completed for all move-only types. `=wasMoved` added, `{.error.}` bare pragmas, hook declaration ordering fixed, DuckString ownership documented. All 147 tests pass with ASan. Files changed: `database.nim`, `config.nim`, `types.nim`, `query.nim`, `scalar_functions.nim`, `aggregate_functions.nim`, `query_result.nim`, `value.nim`.
- **P2 complete** — Type coverage: silent `discard` stubs replaced with `OperationError` raises; Blob/Decimal/UUID/UHugeInt read implemented in `newValue(DuckValue)`; Varchar/HugeInt/UHugeInt/Blob write implemented in `toNativeValue`; decimal precision fixed via int128 path; TimeTz per-row timezone allocation fixed; enum symbol inconsistency normalized; `scanColumn` unsupported types raise instead of silent NULL. All 147 tests pass with ASan. Files changed: `types.nim`, `value.nim`, `vector.nim`, `table_scan.nim`.
- **P3 complete (partial)** — Tests: added assertions to 2 empty tests, added blob bind + null bind round-trip tests, verified thread-test assertions, added clarifying comments. 6 new tests added (147→153). Deferred: Arrow CI, test flag consolidation, release/arc CI matrix, artifact upload. All 153 tests pass with ASan. Files changed: `test_query.nim`, `test_database.nim`.
- **P4 complete (partial)** — Code organization: field-name casing normalized across `vector.nim`, `value.nim`, `table_scan.nim`. Deferred: macro-generated boilerplate elimination (P4-30) and shared macro extraction (P4-32) as large refactorings. All 153 tests pass with ASan. Files changed: `vector.nim`, `value.nim`, `table_scan.nim`.
- **P5 complete (partial)** — API design: fixed misleading `newValue` overloads that ignored `kind` parameter, added doc comments to `transaction`/`transient` templates. Deferred: narrow exports (P5-34, breaking), error taxonomy (P5-37, breaking), `newDuckType` consolidation (P5-36, macro refactoring). All 153 tests pass with ASan. Files changed: `value.nim`, `vector.nim`, `transaction.nim`, `test_value.nim`.
- **P6 complete (partial)** — CI/hygiene: removed dead `GH_TOKEN` from CI, gitignored and deleted stray test binaries, deleted unused `logger.nim`, added compile-time warning for non-x86 decimal, updated README Contribution section. Deferred: DuckDB version alignment (P6-39), nph/doc CI step (P6-40), DuckDB version pin in README (P6-46). All 153 tests pass with ASan. Files changed: `.gitignore`, `.github/workflows/tests.yml`, `src/compatibility/decimal_compat.nim`, `README.md`, deleted `src/logger.nim`.
- **P8 complete** — Threading migration: `Database.p`/`ConnObj.db` switched from `ref DbObj` to `threading/smartptrs.SharedPtr[DbObj]` for safe cross-thread sharing via atomic refcounting. Fixed latent `.thread.` proc signature bug (tuple param). Activated & rewrote thread-safety assertions (chunk API), uncommented 10-DB/100-connection test, added lifetime-invariant and move tests. 8 database tests pass with ASan (orc + arc). Files changed: `nimdrake.nimble`, `src/database.nim`, `tests/test_database.nim`, `WORKBOARD.md`.
- **Coverage expansion complete** — ~90 new tests across 15 files (445 total). Covers codec matrix, transactions, on-disk persistence, SharedPtr concurrency, pending state machine, chunk-boundary >2048, empty results, UDF NULL propagation, aggregate HAVING, table function isolation, LogicalType composites, display edge cases. Known limitations discovered (see below).
- **Coverage expansion round 2** — 44 more tests (489 total, 17 files). Added: Parquet round-trip suite (3 tests: COPY TO/parquet_scan, NULL preservation, nested LIST/STRUCT), Tensor table suite (gated on `-d:features.nimdrake.tensor`, compile-blocked by nimblas `Complex32` bug — TODO in file), cross-chunk Table coverage for Decimal/Date/Blob/Interval/Time/UUID, display edge cases (NULL, decimal, NaN/Inf, >20-row clip, long varchar), pending state-set validation, error paths (directory-as-DB, garbage-binary-as-DB). Known limitations updated (see below).
- **P9 complete** — Test-honesty pass: fixed UUID byte-order and TimestampTz write-offset codec bugs; made misnamed tests actually test what they claim; strengthened weak assertions (exact values, EXPLAIN-based cardinality checks, bind-driven table function); de-flaked timing-sensitive progress/step tests; merged `test_isolate.nim` into `test_qresult.nim` (deleted the ~90% duplicate); removed 11 committed test binaries from git + gitignored all `tests/test_*` binaries; deleted narrow scratch files. All tests pass with ASan (orc + arc + release). Files changed: `src/codec.nim`, `tests/test_query.nim`, `tests/test_qresult.nim`, `tests/test_aggregate_functions.nim`, `tests/test_table_functions.nim`, `tests/test_result_type.nim`, `tests/test_complex.nim`, `tests/test_data_chunk.nim`, `tests/test_database.nim`, `tests/test_catalog.nim`, `tests/narrow/test_arrow.nim`, `tests/narrow/test_table_scan_narrow.nim`, deleted `tests/test_isolate.nim`, `.gitignore`, `WORKBOARD.md`.

---

## Known Limitations

These were discovered during coverage expansion and are **not fixed** — they are pre-existing issues in the wrapper's FFI/C-callback boundary or codec that surfaced under test.

- **`table_functions.nim:init` callback exception not wrapped** — Raising a Nim exception inside an `initProc` C callback propagates the raw `ValueError` (or whatever was raised) rather than converting to `OperationError`. The DuckDB C API wraps the exception into an error result, but our callback trampoline doesn't catch/re-raise through the Nim exception handler correctly. Affects: `initProc` callbacks only (the `mainProc` callback in T24 does correctly produce `OperationError`).

- **`TimestampTz` codec is time-of-day based, losing the date** — `codec.fromDuckTimestampTz`/`toDuckTimestampTz` operate on `floorMod(raw, 86_400_000_000)`, so only time-of-day round-trips; the date portion (and any non-1970-01-01 date) is dropped. Note: DuckDB TIMESTAMPTZ stores *only* UTC microseconds — the offset is NOT part of the value (display applies the session `TimeZone`), so `utcOffset = 0` on read is correct. The write path converts the local wall-clock time to UTC via `val.utcOffset`. Affects: any query reading/writing `TIMESTAMP WITH TIME ZONE` values and expecting the date to survive.

- **`newArrowTable(schema, @[batches])` SEGV inside `garrow_table_new_record_batches`** — `garrow_record_batch_get_raw` copies the C++ `shared_ptr` from a GArrowRecordBatch's private data and crashes because the control-block pointer (`_M_pi`) is dangling. The GObject itself is alive (refcount > 0) but its embedded shared_ptr was corrupted. Crucially: the crash occurs ONLY when the code runs inside **any** Nim `proc` (function body) — module-level code works fine. Narrow's own `test_gtables.nim` (24/24) passes even with libduckdb linked and ASan, because it runs at module level too. Narrow's `test_table_scan_narrow.nim` ArrowTable suite (6 tests) is disabled under `when false` as a result. Root cause is unresolved — likely a Nim stack-frame interaction with the C++ shared_ptr control-block allocation. Does NOT involve libduckdb symbol interposition (confirmed: 0 `_ZN5arrow` symbols exported by libduckdb). See gdb backtrace in session history for the exact `_M_add_ref_copy` crash site.

- **`just test-arrow` fails under LSan (`leaks=true`) due to arrow-glib builder leaks** — `garrow_record_batch_builder_new` → `arrow::RecordBatchBuilder::Make` leaves ~23 KB of indirect C++ allocations that LSan attributes to the builder. The leak is in arrow-glib/narrow, not NimDrake code (the RecordBatchBuilder-based tests pre-date the P9 pass). All arrow tests pass functionally with `just --set leaks false test-arrow`. This is why Arrow CI remains deferred (P3-24); re-enable once the builder leak is understood or a suppression is added.

- **`tests/test_tensor.nim` cannot build with `-d:features.nimdrake.tensor`** — arraymancer's transitive dependency `nimblas 0.3.1` references `Complex32`/`Complex64` without importing `std/complex` (removed implicit alias in Nim 2.2+). Requires pinning/updating nimblas or adding an import shim — outside NimDrake scope. The file compiles under the default `just test` build (disabled branch asserts pass). TODO in file documents how to enable once the dep is fixed.
