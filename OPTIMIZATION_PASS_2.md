# NimDrake Optimization Pass 2

This document is the implementation plan and progress ledger for the second
optimization pass. It is intentionally executable: every optimization has a
current implementation claim, a focused benchmark, correctness tests, and an
exit gate.

Pass 1 fixed ownership leaks, direct table-UDF writes, borrowed scalar UDF
inputs, vector binding caches, logical-type caches, bulk primitive reads, and
chunked homogeneous appends. Pass 2 keeps that behavior stable while closing
the remaining allocation, copying, projection, and repeated-dispatch gaps.

## Progress

Status values are `pending`, `in progress`, `blocked`, or `complete`.

| Phase | Status | Evidence |
|---|---|---|
| Repository and API audit | complete | Current source and history reviewed on 2026-08-18 |
| Revised plan | complete | This document |
| Criterion benchmark foundation | complete | Eight current-API suites pass and export JSON |
| Baseline timing run | complete | Non-Arrow suites run successfully; projection release run completed after the cross-thread ownership fix |
| Baseline heaptrack run | complete | Headless `benchmark-heaptrack` produces trace and summary JSON |
| Baseline FFI counts | complete | `benchmark-ffi` reports vector and child-call counters |
| MAP borrowed access | complete | Borrowed pairs, keys, values, lookup, and null-preserving refs pass tests |
| Raw decimal path | complete | Raw formatter is used by display and generic materialization; tests pass |
| Arrow window export | complete | Nil-schema export is used when Narrow exposes `exportRecordBatchArray`; Narrow `0.0.1` keeps the paired fallback. Focused normal and ASan tests pass; the array-only path records 0 schema outputs |
| Projection pushdown | complete | QResult projected fillers, legacy adapter, and cross-thread-safe registered scans pass tests and ASan |
| Canonical type table | complete | `colDuckTypeOf`, `valueTypeOf`, `rawVectorTypeOf`, and `TypeDescriptor` use the canonical mapping; compile-time mapping tests and type-path benchmarks pass |
| Value-oriented `NimValue` | complete | Scalars, UUID, UHUGEINT, temporal, interval, decimal, enum, and recursive values use native/value-oriented storage |
| Decoder tree | complete | Bulk LIST/ARRAY/STRUCT/MAP/UNION decoder caches child views, tags, and recursive setup |
| Append-based formatting | complete | Single append traversal passes complex tests and improves focused timing |
| Schema-driven binding | complete | Supplied schemas and appender dispatch support empty/NULL-first LIST, STRUCT, MAP, UNION, ENUM, and ARRAY values; prepared ARRAY binding, row-width validation, conversion failures, and rollback paths pass |
| Streaming and borrowed ingestion | complete | Typed row emitters, dynamic `NimValue` producers, borrowed scalar cells, and immediate borrowed LIST/ARRAY/STRUCT/MAP/UNION ingestion pass normal and sanitizer tests |
| Final tests and gates | complete | Non-Arrow and Arrow `just test 1` gates pass with ASan/LSan; non-Arrow and Arrow release matrices pass; Criterion, Heaptrack, and projection FFI checks complete |
| Vector/ColumnView focused benchmarks | complete | Added matched setup/access cases; direct `DataChunk.bindAs` is about 28% faster in the focused comparison and QResult tests pass under normal and ASan modes |
| Arrow/Narrow focused benchmarks | complete | Added one-window, multi-window, wide-batch, and prebuilt traversal cases; FFI counters distinguish schema conversion, window conversion, and vector access |

## Measurement Rules

Criterion 0.3.1 provides timing statistics and JSON export. It does not count
allocations or FFI calls. Those measurements use separate deterministic
profile modes.

### Timing mode

- Compile with `-d:release --opt:speed --mm:orc`.
- Do not use `-d:useMalloc`, sanitizers, LTO, `-ffast-math`, or profiling flags.
- Keep fixture setup outside `.measure.` unless setup is the behavior under test.
- Consume all results and use `blackBox` or a checked aggregate to prevent
  dead-code elimination.
- Use a deterministic fixture size large enough to amortize query startup,
  but small enough for repeated samples.
- Export Criterion JSON through `NIMDRAKE_BENCH_OUTPUT`.

### Heaptrack mode

Heaptrack must run a deterministic one-case workload, not an ordinary Criterion
executable. Criterion performs warmups, calibration, repeated samples, and
`GC_fullCollect`, which would merge framework and benchmark allocations.

The runner will compile with release optimization, debug symbols, frame
pointers, and `-d:useMalloc`, then execute:

```text
heaptrack <binary> --profile-case <case> --iterations <n>
heaptrack_print --print-allocators --print-peaks --print-temporary --print-leaks <trace>
```

Use a one-iteration trace and an N-iteration trace when a differential count is
needed. Normalize the difference by `N - 1`. Use a separate large one-shot run
for peak memory; do not treat a differential peak as additive.

Heaptrack is Linux-only. The recipe must fail clearly when `heaptrack` or
`heaptrack_print` is unavailable. ASan binaries must not be profiled unless the
installed heaptrack explicitly supports its `--asan` mode; sanitizer and
heaptrack runs are separate gates.

### FFI mode

FFI counts are collected by a Linux `LD_PRELOAD` interposer. It counts only
selected DuckDB and Arrow symbols and writes a JSON record at process exit.
Counts are not inferred from timing and are not mixed into Criterion samples.

Initial symbols include:

- `duckdb_data_chunk_get_vector`
- logical-type and nested child accessors
- `duckdb_vector_reference_vector`
- `duckdb_data_chunk_from_arrow`
- DuckDB value and logical-type create/destroy functions
- `garrow_record_batch_export` and its non-null schema-output count

The interposer is diagnostic infrastructure, not production code. It is Linux
and glibc-specific. Tests must still verify ownership and release callbacks
directly under sanitizers.

### Comparison rules

- Baseline and candidate must have matching benchmark labels and parameters.
- Compare Criterion slope estimates and confidence intervals, not only means.
- Repeat any change larger than 5 percent on a controlled machine before
  accepting it.
- Do not enforce timing thresholds on shared GitHub runners.
- Enforce absolute structural claims directly: no candidate key strings, no
  scalar ref node per materialized cell, no unused projected source columns,
  and no per-window Arrow schema export after the dependency supports it.

## Benchmark Suite

Replace the four stale files currently under `benchmarks/`. The new files use
current APIs and each exposes deterministic profile cases as well as Criterion
timing benchmarks.

| File | Focus |
|---|---|
| `benchmarks/config.nim` | Shared Criterion configuration and output path |
| `benchmarks/tools.nim` | Fixtures, result guards, profile dispatch, metadata |
| `benchmarks/bench_pass1.nim` | Regression guards for first-pass paths |
| `benchmarks/bench_map.nim` | Owning versus borrowed MAP iteration and lookup |
| `benchmarks/bench_nimvalue.nim` | Scalar, nested, equality, hash, and format paths |
| `benchmarks/bench_projection.nim` | Wide registered-source and QResult projections |
| `benchmarks/bench_arrow.nim` | Optional Narrow inbound Arrow windows |
| `benchmarks/bench_decimal.nim` | Raw decimal read, format, materialize, and write |
| `benchmarks/bench_type_paths.nim` | Runtime no-regression checks for type codecs |
| `benchmarks/bench_binding.nim` | Schema-driven complex value binding |
| `benchmarks/bench_ingestion.nim` | Chunk, appender, tuple/object, and streaming input |
| `benchmarks/compare.py` | JSON comparison by label and parameter |
| `benchmarks/heaptrack_summary.py` | Stable extraction of heaptrack totals |
| `benchmarks/ffi_counter.c` | Linux preload counter interposer |

The mandatory timing matrix is:

| Area | Cases |
|---|---|
| First-pass guards | Numeric and string scalar UDF, primitive scan, `toSeq`, direct table-UDF write, chunked append |
| MAP | String/string and string/blob; iteration, first/last/missing lookup, owning/borrowed |
| NimValue | NULL, BIGINT, VARCHAR, UUID, UHUGEINT, temporal, decimal, LIST, STRUCT, MAP, UNION |
| Projection | 128 columns selecting one, reordered eight, all columns, and `COUNT(*)`; QResult and registered source |
| Arrow | One window and many windows; primitive and nested input when Narrow is available |
| Decimal | Widths 4/8/16, scales 0/2/18, positive/negative, display and generic materialization |
| Type paths | Scalar UDF, aggregate, vector read/write, prepared bind, appender, table function |
| Binding | Empty, NULL-first, nullable, nested LIST/STRUCT/MAP/UNION/ARRAY |
| Ingestion | Homogeneous, nullable, tuple/object, `openArray`, callback, and direct chunk input |

Correctness edge cases are unit tests, not timing cases: empty maps, NULL keys
and values, embedded NUL bytes, reordered projections, zero-column projections,
Arrow conversion failures, exactly-once release callbacks, decimal overflow,
field mismatches, and partial ingestion failure.

## Optimization Items

### 1. Borrowed MAP access

**Priority:** high. **Status:** complete.

**Current claim:** `MapRowView.pairs`, `keys`, `values`, `contains`, `[]`, and
`getOrDefault` in `src/qresult.nim:1412-1497` use owning `Vector.[]` access for
string and blob keys and values. `DuckStringRef` and `Vector.borrow` already
provide the low-level zero-copy pieces.

Add `borrowPairs`, `borrowKeys`, `borrowValues`, and lookup overloads that
compare a `DuckStringRef` by length and bytes. Preserve owning APIs. Borrowed
results must carry validity separately because a NULL string and an empty
string can both have length zero. Document that refs expire with the source
chunk.

**Tests:** empty maps, NULL keys and values, empty payloads, embedded NULs,
missing keys, duplicate keys, and blob keys.

**Gate:** borrowed iteration and lookup perform no per-entry or candidate Nim
payload allocation; results match owning behavior.

### 2. Value-oriented `NimValue`

**Priority:** high. **Status:** complete.

This is a deliberate pre-1.0 representation break. `NimValue` may become a
value-type discriminated union. Do not preserve reference identity or `nil`
semantics if that costs scalar speed or ergonomics. Keep convenient constructors,
`$`, equality, hashing, and binding APIs coherent.

Scalars and NULL become inline values. Recursive containers retain indirection
only where required. STRUCT field names are schema metadata, not repeated row
payload. Add native fields for UHUGEINT, UUID, temporal values, intervals,
decimals, enums, and fixed ARRAY values. Format only on request.

**Tests:** round trips for NULL, nested LIST/STRUCT/MAP/UNION, UUID, UHUGEINT,
DECIMAL, temporal values, equality, hashing, and public constructor ergonomics.

**Gate:** no scalar ref allocation per cell; semantic output and structural
operations remain correct.

### 3. Projection pushdown for registered Nim sources

**Priority:** high. **Status:** complete.

`FillFn` in `src/qresult.nim:83-85` receives only a destination chunk. The
registered-source path now has a projection-aware callback while retaining a
legacy adapter for sources that only provide the full-schema filler.

Add an additive/versioned projection-aware callback. Enable it for QResult and
tensor sources. Legacy sources retain the existing full-column path through a
documented adapter. Test `COUNT(*)`, one-column, reordered, duplicate, and all
column projections.

**Gate:** instrumented sources do not touch unused columns; legacy sources keep
compiling and running.

### 4. Remove per-window Arrow schema export

**Priority:** medium, dependency-gated. **Status:** complete.

New Narrow revisions provide `exportRecordBatchArray`, which calls
`garrow_record_batch_export` with a nil schema output. NimDrake uses that path
when the API is available and retains a Narrow `0.0.1` fallback that releases
the unused schema. The converted DuckDB chunk retains ownership of the Arrow
buffers. NimDrake's optional dependency constraint remains `narrow >= 0.0.1`.

Test successful conversion, nested arrays, and multi-window batches. The focused
Arrow suite passes 19/19, and the ownership suite passes 2/2, under normal
execution and ASan/LSan. The ownership suite covers conversion failure before
transfer and exactly-once caller-side release. The Linux preload counter recorded
22 `garrow_record_batch_export` calls and zero non-null schema outputs. DuckDB
ownership of the ArrowArray remains unchanged.

**Gate:** no unused schema export per window, zero-copy buffers, and exact
release behavior under ASan/LSan.

### 5. Schema-driven recursive materialization

**Priority:** high. **Status:** complete.

Logical types, child types, and enum labels are already cached in
`src/types.nim:260-316`; do not duplicate that work in the plan. The remaining
cost is repeated runtime kind dispatch, `ColumnView` binding, child lookup,
recursive setup, and union-tag access in `src/complex.nim:154-368`.

Build a decoder tree per column chunk. Store child views, validity views, union
tag views, enum labels, ARRAY size, decimal metadata, and conversion operations.
The single-cell API becomes a thin one-cell decoder. The decoder must retain the
source chunk and preserve parent NULL versus empty-container semantics.

**Gate:** dispatch and child-vector setup are per decoder, not per scalar cell;
all supported DuckDB kinds produce the existing values.

### 6. Complete the decimal raw path

**Priority:** medium. **Status:** complete.

Raw decimal reads exist in `src/qresult.nim:1065-1078` and are now used by
display and generic materialization; high-level `DecimalType` conversion stays
available for callers that request it.

The raw `(unscaled, width, scale)` formatter and append-based materializer are
implemented. `setDecimalRaw` handles already-unscaled writes.

**Tests:** negative sub-unit values, zero scale, leading zeroes, width 38,
maximum magnitude, overflow, and exact output.

**Gate:** one final output string per textual cell and no temporary DecimalType
in raw display/materialization.

### 7. Reduce `NimValue` formatting temporaries

**Priority:** medium. **Status:** complete.

Replace `mapIt(...).join(...)` in `src/complex.nim:133-140` with one append-based
formatter. Avoid recursive child result strings, `replace` temporaries, and
per-byte `toHex` strings. Preserve SQL-like output, apostrophe escaping, and
lowercase blob hex.

**Gate:** no intermediate `seq[string]` or child result strings in nested
formatting; golden output tests pass.

### 8. One declarative Nim-to-DuckDB type table

**Priority:** foundation. **Status:** complete.

The scalar `colDuckTypeOf` mapping in `qresult.nim` reuses the canonical
`toDuckType(typedesc)` mapping in `types.nim`, while retaining explicit API
filters for ambiguous decimal and timezone values. `TypeDescriptor` provides
parameterization, nullability, borrowing, and API capabilities; `valueTypeOf`
and `rawVectorTypeOf` provide decoded and raw storage types. Keep API filters
separate from base mappings.

**Gate:** compile-time coverage for scalar UDF, aggregate, vector, appender,
prepared binding, and table-function paths; generated code has no measurable
regression in the type-path benchmarks.

### 9. Schema-driven `NimValue` binding

**Priority:** high. **Status:** complete.

`toDuckValue(nv, logicalType)` is used for prepared parameter schemas and
`appendRows(seq[seq[NimValue]])`. The appender caches target logical types once
and supports empty/NULL-first LIST values plus nested STRUCT, MAP, UNION, ENUM,
and fixed ARRAY values. Prepared ARRAY binding, row-width validation, field and
type mismatches, conversion failures, and rollback ownership tests pass. The
installed DuckDB 1.5.x C API returns nil from `duckdb_create_array_value`, so
fixed ARRAY values use the accepted child-LIST compatibility representation.

**Gate:** one value traversal, exact schema validation, and ownership tests for
all failure paths.

### 10. Streaming and borrowed ingestion APIs

**Priority:** high. **Status:** complete.

Tuple/object row ingestion, `openArray` inputs, closure iterators, and row
emitter callbacks route through the appender without retaining caller storage;
`Option` fields preserve NULLs. Dynamic `NimValue` rows support sequence and
lazy emitter inputs with target-schema dispatch. Borrowed VARCHAR/BIT/BLOB cells
can be appended from `DuckStringRef` views with length-aware copying, including
embedded NUL bytes. `appendBorrowed` consumes LIST, ARRAY, STRUCT, MAP, and UNION
views immediately. Conversion failures clear the pending appender buffer and
roll back the transaction.

**Gate:** heterogeneous rows need no manual cell dispatch, large input does not
require one sequence per row, and existing `appendRows` remains available.

## Dependency and Tooling Work

1. Pin Criterion to the tested 0.3.1 API. Use Atlas only if the project adopts a
   project-local dependency tree; do not create Atlas state as an incidental
   benchmark change.
2. Add a reproducible Narrow revision once the array-only export exists in a
   published revision. Keep Arrow dependencies optional and keep non-Arrow
   benchmarks buildable without Arrow GLib.
3. Add benchmark recipes to `justfile`: `benchmark`, `benchmark-compare`,
   `benchmark-heaptrack`, `benchmark-ffi`, and `benchmark-clean`.
4. Add benchmark smoke compilation to CI. Do not make noisy timing thresholds a
   shared-runner CI requirement.
5. Keep generated traces, binaries, JSON results, and profiles ignored. Never
   commit heaptrack traces or machine-specific baselines unless explicitly
   requested.

## Exit Criteria

- Every optimization item has at least one timing case and one structural,
  allocation, or FFI measurement where applicable.
- Baseline results exist before the corresponding implementation change.
- Normal tests, release tests, and ownership-sensitive sanitizer tests pass.
- Arrow tests pass when the optional dependency is installed; blocked Arrow
  work is explicitly recorded rather than silently skipped.
- Heaptrack reports are available for all non-Arrow allocation-sensitive profile
  cases on Linux.
- FFI counters confirm projection, decoder, and Arrow call-count claims.
- API compatibility is reviewed as a pre-1.0 design decision, not preserved at
  the expense of speed.
- This document's Progress table is updated after each verified phase.

## Working Commands

```text
just benchmark
just benchmark benchmarks/bench_map.nim -o benchmarks/results/baseline
just benchmark-compare benchmarks/results/baseline benchmarks/results/candidate
just benchmark-heaptrack benchmarks/bench_nimvalue.nim --case scalar --iterations 100
just benchmark-ffi benchmarks/bench_projection.nim --case one_column --iterations 100
just test
just test --features=arrow
```
