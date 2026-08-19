# NimDrake Benchmarking Manual

This manual describes the benchmark tools in this repository.

The repository has three measurement paths:

- Criterion measures execution time.
- Heaptrack measures heap allocation behavior.
- The FFI counter counts selected DuckDB and Arrow calls.

Use the same benchmark case, input size, compiler mode, and iteration count when
you compare two NimDrake revisions. Do not compare results from different
machines or different build modes as if they were one measurement.

## 1. Prepare the Environment

Run these commands from the repository root.

```text
nimble install -y
nimble install -y criterion unittest2
```

The benchmark files require Criterion `0.3.1` or a compatible version from the
project development dependencies.

Install `just` to run the repository recipes.

Install Python 3 for the JSON comparison and Heaptrack summary tools.

Install a C compiler for the FFI counter.

Install Heaptrack and `heaptrack_print` for allocation profiles.

On Debian or Ubuntu, the system packages are usually:

```text
sudo apt install build-essential python3 heaptrack
```

The FFI counter uses Linux `LD_PRELOAD` and `dlsym`. It is intended for Linux
systems that use glibc. It is not a portable counter for Windows or macOS.

Build the optional Arrow dependency before you run the Arrow benchmark.

```text
nimble install -y --features:arrow
```

The Arrow benchmark also requires the system Arrow GLib libraries used by
Narrow. The normal benchmark command skips `benchmarks/bench_arrow.nim`.

## 2. Understand the Benchmark Modes

Every benchmark file supports two modes.

The normal mode runs Criterion timing cases. The runner performs warmup,
calibration, repeated samples, and result checks.

The profile mode runs one named workload repeatedly. Heaptrack and the FFI
counter use profile mode because it excludes Criterion's warmup and calibration
work from the measured workload.

Profile mode accepts these argument forms:

```text
--profile-case NAME
--case NAME
-c NAME
--iterations COUNT
-n COUNT
```

You can also set the profile case with `NIMDRAKE_PROFILE_CASE`. The default
profile iteration count is `1`.

## 3. Run Criterion Benchmarks

Run all non-Arrow benchmark files with a timestamped output directory.

```text
just benchmark
```

The command creates these paths:

```text
benchmarks/results/YYYYMMDD_HHMMSS/
nimcache/benchmarks/
```

Each benchmark writes one Criterion JSON file to the result directory. The
binary files go to `nimcache/benchmarks`.

Save the output path explicitly when you need a stable directory name.

```text
just benchmark "" benchmarks/results/baseline
```

Run one benchmark file.

```text
just benchmark benchmarks/bench_map.nim benchmarks/results/map-candidate
```

Run every benchmark file in a directory.

```text
just benchmark benchmarks benchmarks/results/candidate
```

The runner compiles normal benchmarks with these important options:

```text
-d:release --opt:speed --mm:orc
```

The runner does not use AddressSanitizer, LeakSanitizer, `-d:useMalloc`, or
LTO for normal timing runs.

### 3.1 Run the Arrow Benchmark

Run the optional Arrow benchmark with the dedicated recipe.

```text
just benchmark-arrow
```

Save the Arrow result in a named directory.

```text
just benchmark-arrow benchmarks/bench_arrow.nim benchmarks/results/arrow-candidate
```

The recipe compiles with:

```text
-d:features.nimdrake.arrow
```

Do not pass `benchmarks/bench_arrow.nim` to the normal `just benchmark` command.
The normal recipe skips that file by design.

### 3.2 Select the Criterion Output Path

The benchmark programs read `NIMDRAKE_BENCH_OUTPUT`. The `just benchmark`
recipe sets this variable for each benchmark file.

If you run a compiled benchmark directly, set the variable yourself.

```text
NIMDRAKE_BENCH_OUTPUT=benchmarks/results/manual/bench_map.json \
  nimcache/benchmarks/bench_map
```

Criterion writes timing data as JSON. The comparison tool reads the `label`,
`raw_data.time`, and `raw_data.iterations` fields.

## 4. Choose a Benchmark Case

Use the following profile-case names with Heaptrack or the FFI counter.

| File | Profile cases |
|---|---|
| `bench_callbacks.nim` | `scalar_owning`, `scalar_borrowed`, `aggregate_builtin`, `aggregate_row`, `aggregate_vector`, `table_all_columns`, `table_projected` |
| `bench_data_paths.nim` | `streaming_scan`, `nullable_items`, `nullable_bulk`, `nested_borrowed`, `nested_owning`, `table_random_access` |
| `bench_pass1.nim` | `integer_scan`, `string_scan`, `chunk_build` |
| `bench_map.nim` | `owning_lookup`, `borrowed_lookup`, `borrowed_iteration` |
| `bench_nimvalue.nim` | `scalar_materialization`, `nested_materialization`, `nested_format` |
| `bench_projection.nim` | `one_column`, `reordered`, `all_columns`, `registered_one_column` |
| `bench_decimal.nim` | `materialize`, `read_format` |
| `bench_binding.nim` | `list`, `struct`, `empty_list`, `null_first_list` |
| `bench_ingestion.nim` | `column_build`, `builder`, `tuple_rows` |
| `bench_type_paths.nim` | `scalar_udf`, `appender` |
| `bench_vector.nim` | `column_view`, `bind_typed`, `bind_from_chunk`, `indexed_read`, `iterator_read`, `bulk_read`, `string_read`, `string_borrow` |
| `bench_arrow.nim` | `one_window`, `many_windows`, `many_windows_wide`, `traverse_prebuilt` |

For vector benchmarks, compare `column_view` with `bind_typed` and
`bind_from_chunk`, then compare `indexed_read`, `iterator_read`, and `bulk_read`
to separate view setup from row access. Compare `string_read` with
`string_borrow` when string materialization is part of the workload.

For nullable bulk paths, compare `nullable_items` with `nullable_bulk`. The
`toSeqOpt` path preserves NULL values but allocates its result sequence; use
`toSeqOptInto` when a repeated scan can reuse a caller-owned destination. For
LIST slices, `toSeqInto` provides the same reuse pattern. `TableVector` uses a
validated direct chunk calculation for regular chunk layouts and falls back to
offset binary search for irregular layouts; include both layouts when testing
cross-chunk access.

For a list benchmark, compare `owning_lookup` with `borrowed_lookup` or
`borrowed_iteration`. For projection work, compare `one_column` with
`registered_one_column` and inspect the FFI vector counts. For Arrow work,
compare `one_window` with `many_windows` and `many_windows_wide`. Use
`traverse_prebuilt` to separate conversion from materialization and inspect the
Arrow export and DuckDB conversion counters.

## 5. Run Heaptrack

Heaptrack records allocation activity for one deterministic profile case.

Run a profile with the default iteration count of `100`.

```text
just benchmark-heaptrack benchmarks/bench_map.nim borrowed_lookup
```

Set the iteration count explicitly for a comparison.

```text
just benchmark-heaptrack benchmarks/bench_map.nim borrowed_lookup 100
```

The recipe performs these actions:

1. Compile the benchmark in release mode.
2. Enable `-d:useMalloc`.
3. Keep debug information and frame pointers.
4. Record the profile with `heaptrack --record-only`.
5. Print allocator, peak, temporary, and leak sections.
6. Write a text report beside the Heaptrack trace.
7. Extract stable totals into a JSON summary.

The output paths have this form:

```text
profiles/bench_map-borrowed_lookup-YYYYMMDD_HHMMSS.*
```

The files usually include:

```text
*.zst or *.gz       Heaptrack trace
*.txt               heaptrack_print report
*.json              extracted summary
```

The summary contains the fields that the parser finds:

```json
{
  "allocations": "...",
  "leaked": "...",
  "peak": "...",
  "temporary": "..."
}
```

The exact unit strings come from the installed Heaptrack version. Compare the
same field from two runs with the same Heaptrack version.

### 5.1 Use Heaptrack Correctly

Profile one case at a time.

```text
just benchmark-heaptrack benchmarks/bench_nimvalue.nim nested_format 100
```

Use the same iteration count for the baseline and candidate.

```text
just benchmark-heaptrack benchmarks/bench_nimvalue.nim nested_format 1000
```

Run a one-iteration profile when you need startup and peak information.

Run a larger profile when you need a stable allocation total.

Subtract one-iteration totals from larger-run totals. Divide the difference by
`N - 1` to estimate the cost of one additional workload iteration.

Do not run an ASan binary under Heaptrack. Use the normal Heaptrack build for
allocation counts, and use the test recipe for sanitizer checks.

Do not treat the differential peak as an additive allocation count. Run a
separate large profile when you need peak heap memory.

### 5.2 Read Heaptrack Output

Use `allocations` to compare calls to allocation functions.

Use `temporary` to compare temporary allocation activity.

Use `peak` to compare the maximum heap size.

Use `leaked` to find allocations that Heaptrack reports as still reachable or
leaked at process exit.

Heaptrack totals include benchmark setup and library startup. Use the same
binary structure, input size, and iteration count for both revisions.

## 6. Build and Run the FFI Counter

The FFI counter is a shared library. The `benchmark-ffi` recipe compiles it and
loads it into the benchmark process with `LD_PRELOAD`.

Run a map lookup count.

```text
just benchmark-ffi benchmarks/bench_map.nim borrowed_lookup
```

Run a projection count with a fixed workload count.

```text
just benchmark-ffi benchmarks/bench_projection.nim one_column 100
```

The recipe performs these actions:

1. Compile `benchmarks/ffi_counter.c` as `ffi_counter.so`.
2. Compile the selected benchmark in release mode.
3. Set `LD_PRELOAD` to the counter library.
4. Set `NIMDRAKE_FFI_OUTPUT` to a timestamped JSON path.
5. Run the selected profile case for the requested iterations.
6. Format the JSON output with `python3 -m json.tool`.

The result path has this form:

```text
profiles/bench_projection-one_column-YYYYMMDD_HHMMSS.json
```

### 6.1 Counters in the JSON File

The counter writes these fields:

| Field | Meaning |
|---|---|
| `duckdb_data_chunk_get_vector` | Calls that obtain a vector from a data chunk |
| `duckdb_data_chunk_from_arrow` | Calls that convert one exported ArrowArray into a DuckDB data chunk |
| `duckdb_schema_from_arrow` | Calls that convert an Arrow schema into DuckDB's converted schema |
| `duckdb_destroy_arrow_converted_schema` | Calls that release a converted Arrow schema |
| `duckdb_vector_reference_vector` | Calls that reference one vector from another |
| `duckdb_vector_get_column_type` | Calls that obtain a vector logical type |
| `duckdb_vector_get_data` | Calls that obtain a vector data pointer |
| `duckdb_vector_get_validity` | Calls that obtain a vector validity pointer |
| `duckdb_list_vector_get_child` | LIST child-vector access calls |
| `duckdb_struct_vector_get_child` | STRUCT child-vector access calls |
| `duckdb_array_vector_get_child` | ARRAY child-vector access calls |
| `garrow_record_batch_export` | Arrow record-batch export calls |
| `garrow_record_batch_export_schema` | Arrow exports that receive a non-null schema output |

The counter writes its JSON during process shutdown. A missing output file means
that the process stopped before normal library shutdown or that the output path
was not writable.

### 6.2 Compare FFI Counter Results

Run the same profile case for both revisions.

```text
just benchmark-ffi benchmarks/bench_projection.nim one_column 100
```

Copy each JSON result to a stable name without changing its contents.

```text
cp profiles/bench_projection-one_column-YYYYMMDD_HHMMSS.json \
  /tmp/projection-baseline.json
cp profiles/bench_projection-one_column-YYYYMMDD_HHMMSS.json \
  /tmp/projection-candidate.json
```

Replace each timestamp with the actual timestamp from that run.

Print both files in a stable key order.

```text
python3 - <<'PY'
import json
from pathlib import Path

for name in ("/tmp/projection-baseline.json", "/tmp/projection-candidate.json"):
    print(name)
    values = json.loads(Path(name).read_text())
    for key in sorted(values):
        print(f"  {key}: {values[key]}")
PY
```

Print the candidate-minus-baseline difference for every counter.

```text
python3 - <<'PY'
import json
from pathlib import Path

baseline = json.loads(Path("/tmp/projection-baseline.json").read_text())
candidate = json.loads(Path("/tmp/projection-candidate.json").read_text())

for key in sorted(set(baseline) | set(candidate)):
    old = int(baseline.get(key, 0))
    new = int(candidate.get(key, 0))
    delta = new - old
    percent = (delta / old * 100.0) if old else 0.0
    print(f"{key}: baseline={old} candidate={new} delta={delta:+d} ({percent:+.2f}%)")
PY
```

Interpret the difference as follows:

- A negative count means that the candidate made fewer calls.
- A positive count means that the candidate made more calls.
- A zero count means that both runs made the same number of intercepted calls.
- A zero baseline count has no useful percentage change.

Compare counts only when both runs use the same profile case and iteration
count. The counts include calls from process setup and library initialization.

For a per-iteration estimate, run both profiles with `1` iteration and then
with `N` iterations. Subtract the one-iteration count from the N-iteration
count. Divide by `N - 1`.

### 6.3 Arrow Counter Checks

Build and run the Arrow profile with the Arrow feature enabled.

```text
just benchmark-ffi benchmarks/bench_arrow.nim many_windows 100
```

The command uses the benchmark file's Arrow imports. The local environment must
provide Narrow and the Arrow GLib libraries.

For the array-only export optimization, inspect these two fields:

```text
garrow_record_batch_export
garrow_record_batch_export_schema
```

The schema counter must be zero when NimDrake passes a nil schema output to
Arrow. The export counter must match the number of Arrow export operations for
the workload. With Narrow's older paired-export API, the schema counter is
expected to match the export count because NimDrake releases that unused
schema locally. `duckdb_schema_from_arrow` should be one per materialized
RecordBatch, not one per window.

Do not treat a zero schema count as proof of zero-copy ownership by itself.
Use the Arrow ownership tests and ASan/LSan tests for ownership evidence.

## 7. Compare Criterion Results

Run a baseline before you change the implementation.

```text
just benchmark benchmarks/bench_map.nim benchmarks/results/baseline-map
```

Run the same benchmark after the change.

```text
just benchmark benchmarks/bench_map.nim benchmarks/results/candidate-map
```

Compare the directories.

```text
just benchmark-compare benchmarks/results/baseline-map benchmarks/results/candidate-map
```

The comparison prints time in microseconds and a percentage change.

The percentage uses this formula:

```text
(candidate mean - baseline mean) / baseline mean * 100
```

A positive value means that the candidate is slower. A negative value means
that the candidate is faster.

The comparison also prints a Welch t statistic. Use it as a variation signal,
not as a release threshold.

Print only changes at or above a percentage threshold.

```text
just benchmark-compare benchmarks/results/baseline-map benchmarks/results/candidate-map 5
```

The threshold is an absolute percentage. A threshold of `5` hides changes from
`-5%` through `+5%`.

Compare one JSON file when you need one benchmark label.

```text
just benchmark-compare \
  benchmarks/results/baseline-map/bench_map.json \
  benchmarks/results/candidate-map/bench_map.json
```

The tool returns a nonzero status when the baseline and candidate do not have
the same benchmark labels. It also returns a nonzero status when a baseline
JSON file has no matching candidate file.

## 8. Use a Baseline and Candidate Protocol

Record the revision, operating system, CPU, compiler version, DuckDB version,
Nim version, and benchmark command for every run.

Run the baseline and candidate on the same machine.

Use the same release build flags for both runs.

Use the same benchmark output directory naming scheme.

Run each timing comparison more than once when the change is larger than five
percent.

Accept an optimization only when timing, allocation, and FFI evidence support
the same conclusion.

Use tests for correctness. Do not use a faster benchmark as proof of correct
behavior.

A useful directory layout is:

```text
benchmarks/results/
  baseline-20260818/
  candidate-20260818/
profiles/
  baseline-map-borrowed_lookup-20260818.json
  candidate-map-borrowed_lookup-20260818.json
```

Keep machine-specific benchmark results out of commits unless the project
explicitly requests them.

## 9. Clean Generated Files

Remove benchmark binaries, profiles, and result directories with:

```text
just benchmark-clean
```

This command removes:

```text
nimcache/benchmarks
profiles
benchmarks/results
```

The command does not remove source files or normal test artifacts.

## 10. Troubleshooting

### `heaptrack is required`

Install Heaptrack and make sure that `heaptrack` is in `PATH`.

### `heaptrack_print is required`

Install the Heaptrack tools package that provides `heaptrack_print`.

### `a C compiler is required`

Install GCC, Clang, or another compiler that provides the `cc` command.

### `unknown ... profile case`

Use a case name from the table in Section 4. Do not use a Criterion label unless
the benchmark file also defines that name in `runProfile`.

### The FFI JSON file is missing

Make sure that the benchmark process can write to `profiles`.

Make sure that the process exits normally.

Make sure that the selected binary loads the preloaded shared library.

### FFI counts are zero

Make sure that the selected DuckDB or Arrow symbols are present in the loaded
libraries.

Make sure that the benchmark executes the expected profile case.

Use `ldd` on the benchmark binary and inspect the loaded DuckDB libraries.

### The Arrow benchmark does not compile

Install the Arrow feature dependencies and the system Arrow GLib libraries.

Run the non-Arrow benchmarks separately when the optional Arrow stack is absent.

### Timing results vary between runs

Close unrelated CPU-heavy programs.

Run the baseline and candidate on the same machine.

Increase the benchmark budget only after the benchmark passes its correctness
checks.

Use Heaptrack and the FFI counter to identify structural changes that timing
alone cannot explain.

## 11. Recommended Complete Run

Use this sequence for an optimization change.

```text
just test 1
just benchmark benchmarks/bench_map.nim benchmarks/results/baseline-map
just benchmark-heaptrack benchmarks/bench_map.nim borrowed_lookup 100
just benchmark-ffi benchmarks/bench_map.nim borrowed_lookup 100
```

Build the candidate revision, then repeat the same commands with candidate
output names.

Compare timing JSON files.

Compare Heaptrack summary JSON files by field.

Compare FFI JSON files with the Python difference command from Section 6.2.

Run the Arrow commands separately when the change affects Arrow integration.

Record the results in `OPTIMIZATION_PASS_2.md` after the measurements pass.

## 12. Build a Full Activity Report

Run every profile case with perf, Heaptrack, the FFI counter, and Samply.

```text
just benchmark-profile-suite
```

The command calibrates each perf and Samply run to approximately one second.
It limits Heaptrack to 10 workload iterations and the FFI counter to 100.

These limits serve different purposes:

- Perf and Samply need enough runtime to collect a useful sample population.
  The calibration target provides a similar sample budget for fast and slow
  workloads.
- Heaptrack records allocation events and call stacks. A large iteration count
  creates a large trace and increases analysis time. Ten iterations provide a
  repeatable differential allocation count for most workloads.
- The FFI counter records integer call counts. It has low trace overhead, so
  100 iterations reduce startup-count noise and make per-workload call counts
  easier to measure.

The harness runs one iteration and then a repeated run for Heaptrack and the
FFI counter. It subtracts the one-iteration result from the repeated result.
It divides the difference by the number of additional iterations. The report
therefore shows calls or allocations for one workload, not process startup.

The values are caps. If calibration selects fewer iterations, the harness uses
that lower value. The FFI counter uses at least two iterations so that it can
calculate a differential value.

### 12.1 Add Custom Samply Markers

Use `src/samplyprofiler.nim` to add named interval markers to a Samply profile.
The module is enabled only by `-d:samply`. In normal builds, the `profile`
template expands to its body and emits no marker file.

The thread-local `profile "name":` template initializes the profiler on first
use in each thread, so the marker file attaches to whichever thread actually
runs the profiled scope. Call `closeThreadProfiler` once at the end of the
thread that owns the workload:

```nim
import ../src/samplyprofiler

profile "execute-query":
  let result = connection.execute(sql)
  consume(result)

closeThreadProfiler()
```

At module scope, call `closeThreadProfiler` explicitly at the end of the file.
`defer` is not supported at module scope; inside a `proc`, this form works:

```nim
proc run() =
  defer: closeThreadProfiler()
  profile "execute-query":
    let result = connection.execute(sql)
    consume(result)
```

To initialize with non-default options (for example `PerProcess` mode), call
`initThreadProfiler` explicitly before the first `profile` block; the explicit
call replaces the automatic one.

For an explicit profiler, use the overload that receives the profiler first:

```nim
var profiler = initSamplyProfiler(PerThread)
defer: profiler.close()

profile(profiler, "parse-request"):
  let request = parseRequest(input)
  validateRequest(request)
```

Scopes can be nested. Each scope closes its own interval in a `finally` block,
so the inner marker is completed before the outer marker. This also records a
closed interval when the scoped body raises an exception:

```nim
profile(profiler, "query-pipeline"):
  profile(profiler, "parse"):
    parse(sql)
  profile(profiler, "plan"):
    buildPlan()
  profile(profiler, "execute"):
    executePlan()
```

Use `begin` and `finish` when the interval does not match one lexical block:

```nim
let start = profiler.begin("stream rows")
for row in scanRows():
  consume(row)
profiler.finish(start, "stream rows")
```

The default `PerThread` mode writes `marker-<pid>-<tid>.txt`. Samply uses the
mapping event for that file to associate markers with the correct thread.
`PerProcess` writes `marker-<pid>.txt` and is appropriate when one thread owns
the profiler:

```nim
var profiler = initSamplyProfiler(PerProcess)
defer: profiler.close()
profile(profiler, "single-threaded workload"):
  runWorkload()
```

The file is created in the working directory. When that directory cannot host
a writable shared memory mapping (for example a Windows drive accessed from
WSL), the module falls back to the system temp directory automatically; read
`profiler.path` if you need the actual location. On `close`, the mapping is
flushed (`msync` + `munmap`) and the file is trimmed to the marker bytes
(`ftruncate`); on abrupt exit the OS still writes back `MAP_SHARED` pages,
so markers are not lost, only the trim is skipped.

Build the instrumented binary and record it with Samply:

```text
nim c -d:release -d:samply -o:myapp src/myapp.nim
samply record ./myapp
```

The repository recipe adds `-d:samply` automatically:

```text
just samply tests/test_dsl_complex.nim "samply workload*"
```

Each completed interval is stored as one line with monotonic nanoseconds:

```text
<start_ns> <end_ns> <name>
```

Names may contain spaces. Newline characters in names are replaced with spaces
to preserve the line format. Samply's external marker-file support is unstable,
so treat this file format as an integration detail rather than a public data
format.

Increase these caps when a workload has very low allocation or FFI activity.
Keep the same caps for the baseline and candidate when you compare revisions.

The command attempts the optional Arrow benchmark. If Arrow is not available,
the report records each Arrow case as skipped and includes the compiler error.

Use an explicit output directory when you need a stable path.

```text
just benchmark-profile-suite profiles/full-activity
```

The output directory contains these files:

```text
ACTIVITY_REPORT.md
summary.json
bin/
cases/BENCHMARK/CASE/perf.data
cases/BENCHMARK/CASE/heaptrack*.zst
cases/BENCHMARK/CASE/samply.json.gz
```

`ACTIVITY_REPORT.md` contains these sections:

- CPU activity by Nim, DuckDB, Arrow, runtime, kernel, and unknown code.
- The top Nim self-time symbols.
- The top allocation sources for each workload iteration.
- Differential FFI calls for each additional workload iteration.
- Unresolved symbols that require more debug information.
- An activity matrix for all profile cases.

Use `summary.json` for additional analysis. The JSON file includes decoded perf
reports, full Heaptrack reports, raw FFI counters, and decompressed Samply JSON.
It also includes calibration data, tool paths, and paths to binary trace files.

Run selected benchmark files during harness development.

```text
python3 benchmarks/profile_suite.py --bench bench_vector --bench bench_map
```

Use `--skip-arrow` when the optional Arrow stack is intentionally absent.
Use `--target-seconds` to change the perf and Samply sample duration.

Resume an interrupted run and keep all successful cases.

```text
python3 benchmarks/profile_suite.py \
  --output profiles/full-activity \
  --resume
```

## 13. Write a Matched Comparison Report

Use a matched comparison when you need a before-and-after performance report.
Build the baseline and candidate with the same compiler, flags, dependencies,
workload, machine, and benchmark command.

### 13.1 Match the Conditions

Record these values before you run the comparison:

| Setting | Baseline | Candidate |
|---|---|---|
| Revision | `BASELINE_REVISION` | `CANDIDATE_REVISION` |
| Machine | `HOST` | `HOST` |
| Nim version | `NIM_VERSION` | `NIM_VERSION` |
| DuckDB version | `DUCKDB_VERSION` | `DUCKDB_VERSION` |
| Build flags | `BUILD_FLAGS` | `BUILD_FLAGS` |
| Benchmark file | `BENCHMARK_FILE` | `BENCHMARK_FILE` |
| Profile case | `CASE_NAME` | `CASE_NAME` |
| Workload iterations | `N` | `N` |
| Heaptrack iterations | `N` | `N` |
| FFI iterations | `N` | `N` |

Do not compare a full profile with a selected profile as one result.
Do not compare Criterion timing with profile-mode timing as one result.
Do not change the workload size between the baseline and candidate runs.
Do not use different Heaptrack or FFI iteration counts.

Build each revision into a different directory. Keep both binaries available
until the report is complete.

### 13.2 Measure Timing

Use a fixed profile case and a fixed iteration count for both binaries.
Run one iteration to measure startup cost. Then run `N` iterations.
Calculate the workload time with this formula:

```text
workload_time = (time_N - time_one) / (N - 1)
```

Repeat the pair at least seven times. Use the median of the adjusted values.
Use the same sample count for the baseline and candidate.

The profile command has this form:

```text
BINARY --profile-case CASE_NAME --iterations 1
BINARY --profile-case CASE_NAME --iterations N
```

Run the commands once before you collect samples. This warm-up run removes
first-run effects from compilation caches and shared-library loading.

Calculate the timing change with this formula:

```text
timing_change_percent = (before - after) / before * 100
```

A positive timing change means that the candidate is faster.
A negative timing change means that the candidate is slower.

Report a change below five percent as `within measurement noise` unless the
repeated samples show a clear and stable difference.

### 13.3 Measure Allocations

Run Heaptrack once with one iteration and once with `N` iterations for each
binary.

```text
just benchmark-heaptrack benchmarks/bench_map.nim CASE_NAME 10
```

Subtract the one-iteration allocation count from the `N`-iteration count.
Divide the result by `N - 1`.

```text
allocations_per_workload = (allocations_N - allocations_one) / (N - 1)
```

Use the same Heaptrack version for both revisions.
Report total allocations and temporary allocations in separate tables.

Do not report a small negative differential as a real negative allocation
count. Treat it as zero and record that measurement noise affected the result.

### 13.4 Measure FFI Calls

Run the FFI counter with one iteration and with `N` iterations for each binary.

```text
just benchmark-ffi benchmarks/bench_map.nim CASE_NAME 100
```

Normalize each counter with this formula:

```text
ffi_calls_per_workload = (ffi_N - ffi_one) / (N - 1)
```

Report only counters that relate to the optimization. Include all counters
when the change affects general binding or ownership behavior.

FFI counts are structural evidence. They can prove that a code path performs
fewer DuckDB calls even when total elapsed time does not change.

### 13.5 Group the Report

Group the result into four sections. Keep timing, allocation, and FFI evidence
separate because each measure answers a different question.

#### Timing

Use one row for each measured workload:

| Workload | Before | After | Change |
|---|---:|---:|---:|
| `WORKLOAD_NAME` | `X.XXX ms` | `Y.YYY ms` | `Z.Z% faster` |

Use `slower` when the candidate time is higher. Use `unchanged` when the
difference is within measurement noise.

#### Allocations

Use one row for total allocations and one row for temporary allocations when
both values help explain the change:

| Workload | Before | After | Change |
|---|---:|---:|---:|
| `WORKLOAD_NAME` allocations | `X.X/workload` | `Y.Y/workload` | `Z.Z% fewer` |
| `WORKLOAD_NAME` temporary allocations | `X.X/workload` | `Y.Y/workload` | `Z.Z% fewer` |

#### FFI Calls

Use one row for each relevant FFI counter:

| Workload | Before | After | Change |
|---|---:|---:|---:|
| `duckdb_data_chunk_get_vector` | `X.X/workload` | `Y.Y/workload` | `Z.Z% fewer` |

#### Conclusion

State the largest measured gain first. State allocation changes next. State
structural FFI changes that do not change elapsed time. State paths that remain
unchanged because their ownership contract requires allocation.

Use this report order:

```text
Matched Conditions
Timing
Allocations
FFI Calls
Conclusion
```

### 13.6 Example Report

The following example shows the required format. The values are examples only.

**Timing**

| Workload | Before | After | Change |
|---|---:|---:|---:|
| TableVector random access | 12.759 ms | 3.028 ms | 76.3% faster, about 4.2x |
| Nullable bulk `toSeqOpt` | 0.465 ms | 0.480 ms | 3.3% slower, within noise |
| Projected table function | 3.502 ms | 3.504 ms | Unchanged |

**Allocations**

| Workload | Before | After | Change |
|---|---:|---:|---:|
| Nullable bulk `toSeqOpt` | 130.0/workload | 64.3/workload | 50.5% fewer |
| Projected table function | 1,311.7/workload | 1,053.0/workload | 19.7% fewer |
| MAP owning materialization | 110,484.4/workload | 110,482.6/workload | Unchanged |

**FFI Calls**

| Workload | Before | After | Change |
|---|---:|---:|---:|
| Projected table function vector setup | 1,033/workload | 130/workload | 87.4% fewer, about 8x |
| All-column table function vector setup | 1,033/workload | 1,033/workload | Unchanged |

**Conclusion**

Regular table indexing provides the largest timing gain. Nullable bulk copying
cuts allocation activity but does not show a stable timing gain in this run.
Projection reduces vector setup calls by about 8x, while DuckDB work keeps total
table-function time nearly unchanged. MAP owning materialization remains
allocation-heavy because it returns fully owned tables.
