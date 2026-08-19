#!/usr/bin/env python3
"""Profile every NimDrake benchmark case and write an activity report."""

from __future__ import annotations

import argparse
import gzip
import json
import math
import os
import platform
import re
import shutil
import subprocess
import sys
import time
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
BENCHMARKS = ROOT / "benchmarks"

CASES = {
    "bench_callbacks": {
        "scalar_owning": "Call an owning-string scalar UDF for 262,144 rows",
        "scalar_borrowed": "Call a borrowed-string scalar UDF for 262,144 rows",
        "aggregate_builtin": "Group 262,144 rows with a built-in aggregate",
        "aggregate_row": "Group 262,144 rows with a per-row Nim aggregate callback",
        "aggregate_vector": "Group 262,144 rows with a vector Nim aggregate callback",
        "table_all_columns": "Produce eight columns from an iterator-backed table function",
        "table_projected": "Project one column from an iterator-backed table function",
    },
    "bench_data_paths": {
        "streaming_scan": "Consume 1,048,577 rows from a streaming result",
        "nullable_items": "Iterate 131,073 nullable integers as Option values",
        "nullable_bulk": "Bulk-copy 131,073 nullable integers as Option values",
        "nested_borrowed": "Traverse 131,073 borrowed eight-item LIST rows",
        "nested_owning": "Materialize 131,073 eight-item LIST rows",
        "table_random_access": "Perform 500,000 cross-chunk random reads",
    },
    "bench_pass1": {
        "integer_scan": "Execute and read a 20,000-row BIGINT query",
        "string_scan": "Execute and materialize 20,000 VARCHAR values",
        "chunk_build": "Build and read a 20,000-row integer chunk",
    },
    "bench_map": {
        "owning_lookup": "Materialize 5,000 maps and perform owning lookups",
        "borrowed_lookup": "Perform 5,000 borrowed map lookups",
        "borrowed_iteration": "Iterate borrowed keys from 5,000 maps",
    },
    "bench_nimvalue": {
        "scalar_materialization": "Materialize 2,000 scalar NimValue objects",
        "nested_materialization": "Materialize 2,000 nested NimValue lists",
        "nested_format": "Format one nested NimValue",
    },
    "bench_projection": {
        "one_column": "Read one projected column from 10,000 wide rows",
        "reordered": "Read reordered projected columns from 10,000 rows",
        "all_columns": "Bind all 16 columns from 10,000 rows",
        "registered_one_column": "Read one column through a registered result",
    },
    "bench_decimal": {
        "materialize": "Materialize 2,000 decimals as NimValue objects",
        "read_format": "Read and format 2,000 decimal values",
    },
    "bench_binding": {
        "list": "Bind and read a three-item list",
        "struct": "Bind and read a two-field struct",
        "empty_list": "Bind and read an empty list",
        "null_first_list": "Bind and read a list with a leading NULL",
    },
    "bench_ingestion": {
        "column_build": "Build a 2,000-row chunk from columns",
        "builder": "Append 2,000 rows with ChunkBuilder",
        "tuple_rows": "Append 2,000 tuple rows with Appender",
    },
    "bench_type_paths": {
        "scalar_udf": "Call a Nim scalar UDF for 5,000 rows",
        "appender": "Append 5,000 nested-sequence rows",
    },
    "bench_vector": {
        "column_view": "Create and inspect 1,000 column views",
        "bind_typed": "Bind one typed vector 1,000 times",
        "bind_from_chunk": "Bind from a chunk 1,000 times",
        "indexed_read": "Read 2,048 integers by index",
        "iterator_read": "Read 2,048 integers with an iterator",
        "bulk_read": "Copy and read 2,048 integers",
        "string_read": "Materialize 2,048 strings",
        "string_borrow": "Read 2,048 borrowed strings",
    },
    "bench_arrow": {
        "one_window": "Convert and traverse one Arrow window",
        "many_windows": "Convert and traverse multiple Arrow windows",
        "many_windows_wide": "Convert and traverse a wide Arrow batch",
        "traverse_prebuilt": "Traverse a prebuilt Arrow result",
    },
}

PERF_LINE = re.compile(
    r"^\s*([0-9.]+)%\s+(\d+)\s+(\S+)\s+(\S+)\s+\[.\]\s+(.*)$"
)
HEAPTRACK_ALLOCATOR = re.compile(
    r"^(\d+) calls to allocation functions with (\S+) peak consumption from$"
)
HEAPTRACK_PEAK = re.compile(
    r"^(\S+) peak memory consumed over (\d+) calls from$"
)
HEAPTRACK_LEAK = re.compile(r"^(\S+) leaked over (\d+) calls from$")
HEAPTRACK_TEMPORARY = re.compile(
    r"^(\d+) temporary allocations of (\d+) allocations in total .* from$"
)


def run_command(
    args: list[str],
    *,
    env: dict[str, str] | None = None,
    timeout: float | None = None,
    output: Path | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    started = time.monotonic()
    process = subprocess.run(
        args,
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
    )
    process.elapsed = time.monotonic() - started  # type: ignore[attr-defined]
    if output is not None:
        output.write_text(process.stdout)
    if check and process.returncode != 0:
        command = " ".join(args)
        raise RuntimeError(
            f"command failed ({process.returncode}): {command}\n{process.stdout[-4000:]}"
        )
    return process


def require_tool(name: str, fallback: Path | None = None) -> str:
    path = shutil.which(name)
    if path:
        return path
    if fallback is not None and fallback.is_file():
        return str(fallback)
    raise RuntimeError(f"required tool is not available: {name}")


def classify_dso(dso: str, benchmark: str) -> str:
    lower = dso.lower()
    if dso == benchmark or lower.endswith("/" + benchmark):
        return "nim"
    if "libduckdb" in lower or "duckdb_extension" in lower:
        return "duckdb"
    if "arrow" in lower or "glib" in lower or "gobject" in lower:
        return "arrow"
    if "kernel" in lower or "kallsyms" in lower or dso == "[k]":
        return "kernel"
    if dso == "[unknown]" or "unknown" in lower:
        return "unknown"
    if any(
        name in lower
        for name in ("libc", "libm.", "libstdc++", "libgcc", "ld-linux", "libpthread")
    ):
        return "runtime"
    return "other"


def unresolved_symbol(symbol: str, dso: str) -> bool:
    return (
        symbol.startswith("0x")
        or symbol == "[unknown]"
        or dso == "[unknown]"
        or "unknown" in symbol.lower()
    )


def compile_benchmark(
    nim: str, benchmark: str, output_dir: Path
) -> tuple[Path | None, str | None]:
    source = BENCHMARKS / f"{benchmark}.nim"
    binary = output_dir / "bin" / benchmark
    cache = output_dir / "nimcache" / benchmark
    binary.parent.mkdir(parents=True, exist_ok=True)
    cache.mkdir(parents=True, exist_ok=True)
    command = [
        nim,
        "c",
        "--verbosity:0",
        "--hints:off",
        "-d:release",
        "--opt:speed",
        "--mm:orc",
        "-d:useMalloc",
        "--debuginfo:on",
        "--passC:-g",
        "--passC:-fno-omit-frame-pointer",
        "--passL:-g",
        f"--nimcache:{cache}",
        f"-o:{binary}",
    ]
    if benchmark == "bench_arrow":
        command.append("-d:features.nimdrake.arrow")
    command.append(str(source))
    result = run_command(
        command,
        check=False,
        timeout=600,
        output=output_dir / "logs" / f"{benchmark}-compile.log",
    )
    if result.returncode != 0:
        return None, result.stdout[-2000:]
    return binary, None


def benchmark_command(binary: Path, case_name: str, iterations: int) -> list[str]:
    return [
        str(binary),
        "--profile-case",
        case_name,
        "--iterations",
        str(iterations),
    ]


def calibrate(binary: Path, case_name: str, target_seconds: float) -> dict:
    one = run_command(benchmark_command(binary, case_name, 1), timeout=300)
    one_elapsed = one.elapsed  # type: ignore[attr-defined]
    iterations = 4
    elapsed = one_elapsed
    while True:
        result = run_command(
            benchmark_command(binary, case_name, iterations), timeout=300
        )
        elapsed = result.elapsed  # type: ignore[attr-defined]
        incremental = elapsed - one_elapsed
        if incremental >= min(0.25, target_seconds / 3) or iterations >= 1_000_000:
            break
        iterations *= 4
    per_iteration = max((elapsed - one_elapsed) / (iterations - 1), 0.000001)
    target_iterations = max(1, math.ceil(target_seconds / per_iteration))
    target_iterations = min(target_iterations, 1_000_000)
    return {
        "one_iteration_seconds": round(one_elapsed, 6),
        "probe_iterations": iterations,
        "probe_seconds": round(elapsed, 6),
        "estimated_iteration_seconds": round(per_iteration, 9),
        "iterations": target_iterations,
    }


def parse_perf_report(text: str, benchmark: str) -> dict:
    symbols = []
    categories: defaultdict[str, float] = defaultdict(float)
    total_samples = 0
    unknown_percent = 0.0
    sample_match = re.search(r"^# Samples:\s+(\d+)", text, re.MULTILINE)
    if sample_match:
        total_samples = int(sample_match.group(1))
    for line in text.splitlines():
        match = PERF_LINE.match(line)
        if not match:
            continue
        percent, samples, _command, dso, symbol = match.groups()
        sample_count = int(samples)
        category = classify_dso(dso, benchmark)
        unknown = unresolved_symbol(symbol, dso)
        entry = {
            "percent": float(percent),
            "samples": sample_count,
            "dso": dso,
            "category": category,
            "symbol": symbol,
            "unresolved": unknown,
        }
        symbols.append(entry)
        categories[category] += float(percent)
        if unknown:
            unknown_percent += float(percent)
    return {
        "samples": total_samples,
        "category_percent": dict(categories),
        "unknown_percent": unknown_percent,
        "top_symbols": sorted(symbols, key=lambda item: item["percent"], reverse=True)[:30],
        "top_unknown_symbols": sorted(
            (entry for entry in symbols if entry["unresolved"]),
            key=lambda item: item["percent"],
            reverse=True,
        )[:30],
    }


def run_perf(
    perf: str,
    binary: Path,
    benchmark: str,
    case_name: str,
    iterations: int,
    case_dir: Path,
) -> dict:
    data = case_dir / "perf.data"
    record = run_command(
        [
            perf,
            "record",
            "-F",
            "499",
            "-g",
            "--call-graph",
            "dwarf",
            "-o",
            str(data),
            "--",
            *benchmark_command(binary, case_name, iterations),
        ],
        timeout=600,
        output=case_dir / "perf-record.log",
    )
    report = run_command(
        [
            perf,
            "report",
            "-i",
            str(data),
            "--stdio",
            "--no-children",
            "-g",
            "none",
            "-n",
            "--percent-limit",
            "0",
        ],
        timeout=300,
        output=case_dir / "perf-report.txt",
    )
    parsed = parse_perf_report(report.stdout, benchmark)
    parsed.update(
        {
            "iterations": iterations,
            "seconds": round(record.elapsed, 6),  # type: ignore[attr-defined]
            "data": str(data.relative_to(case_dir.parent.parent)),
            "record_dump": record.stdout,
            "report_dump": report.stdout,
        }
    )
    return parsed


def parse_heaptrack_sections(text: str) -> dict:
    section = ""
    result = {
        "top_allocators": [],
        "peak_consumers": [],
        "leaks": [],
        "temporary_sources": [],
    }
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if line == "MOST CALLS TO ALLOCATION FUNCTIONS":
            section = "top_allocators"
            continue
        if line == "PEAK MEMORY CONSUMERS":
            section = "peak_consumers"
            continue
        if line == "MEMORY LEAKS":
            section = "leaks"
            continue
        if line == "MOST TEMPORARY ALLOCATIONS":
            section = "temporary_sources"
            continue
        if not section or index + 1 >= len(lines):
            continue
        match = None
        entry = None
        if section == "top_allocators":
            match = HEAPTRACK_ALLOCATOR.match(line)
            if match:
                entry = {
                    "calls": int(match.group(1)),
                    "peak": match.group(2),
                }
        elif section == "peak_consumers":
            match = HEAPTRACK_PEAK.match(line)
            if match:
                entry = {"peak": match.group(1), "calls": int(match.group(2))}
        elif section == "leaks":
            match = HEAPTRACK_LEAK.match(line)
            if match:
                entry = {"leaked": match.group(1), "calls": int(match.group(2))}
        elif section == "temporary_sources":
            match = HEAPTRACK_TEMPORARY.match(line)
            if match:
                entry = {"temporary": int(match.group(1)), "calls": int(match.group(2))}
        if entry is not None:
            entry["symbol"] = lines[index + 1].strip()
            result[section].append(entry)
    for name in result:
        result[name] = result[name][:15]
    return result


def run_heaptrack_once(
    heaptrack: str,
    heaptrack_print: str,
    binary: Path,
    case_name: str,
    iterations: int,
    case_dir: Path,
    prefix: str,
) -> dict:
    base = case_dir / prefix
    record = run_command(
        [
            heaptrack,
            "--record-only",
            "-o",
            str(base),
            *benchmark_command(binary, case_name, iterations),
        ],
        timeout=1200,
        output=case_dir / f"{prefix}-record.log",
    )
    traces = sorted(case_dir.glob(f"{prefix}*.zst")) + sorted(case_dir.glob(f"{prefix}*.gz"))
    if not traces:
        raise RuntimeError(f"heaptrack did not create a trace for {case_name}")
    trace = traces[-1]
    printed = run_command(
        [
            heaptrack_print,
            "--print-allocators",
            "--print-peaks",
            "--print-temporary",
            "--print-leaks",
            "-f",
            str(trace),
        ],
        timeout=1200,
        output=case_dir / f"{prefix}-report.txt",
    )
    stats = {}
    patterns = {
        "allocations": r"allocations:\s+(\d+)",
        "leaked_allocations": r"leaked allocations:\s+(\d+)",
        "temporary_allocations": r"temporary allocations:\s+(\d+)",
    }
    for name, pattern in patterns.items():
        match = re.search(pattern, record.stdout)
        if match:
            stats[name] = int(match.group(1))
    stats.update(parse_heaptrack_sections(printed.stdout))
    stats.update(
        {
            "iterations": iterations,
            "seconds": round(record.elapsed, 6),  # type: ignore[attr-defined]
            "trace": str(trace.relative_to(case_dir.parent.parent)),
            "record_dump": record.stdout,
            "report_dump": printed.stdout,
        }
    )
    return stats


def run_heaptrack(
    heaptrack: str,
    heaptrack_print: str,
    binary: Path,
    case_name: str,
    iterations: int,
    case_dir: Path,
) -> dict:
    one = run_heaptrack_once(
        heaptrack, heaptrack_print, binary, case_name, 1, case_dir, "heaptrack-one"
    )
    if iterations > 1:
        many = run_heaptrack_once(
            heaptrack,
            heaptrack_print,
            binary,
            case_name,
            iterations,
            case_dir,
            "heaptrack-many",
        )
        divisor = iterations - 1
        for name in ("allocations", "leaked_allocations", "temporary_allocations"):
            many[f"{name}_per_iteration"] = (
                many.get(name, 0) - one.get(name, 0)
            ) / divisor
        one_allocators = {
            entry["symbol"]: entry["calls"] for entry in one["top_allocators"]
        }
        for entry in many["top_allocators"]:
            entry["calls_per_iteration"] = (
                entry["calls"] - one_allocators.get(entry["symbol"], 0)
            ) / divisor
        many["baseline_trace"] = one["trace"]
        many["baseline_record_dump"] = one["record_dump"]
        many["baseline_report_dump"] = one["report_dump"]
        return many
    for name in ("allocations", "leaked_allocations", "temporary_allocations"):
        one[f"{name}_per_iteration"] = float(one.get(name, 0))
    for entry in one["top_allocators"]:
        entry["calls_per_iteration"] = float(entry["calls"])
    return one


def run_ffi_once(
    binary: Path,
    case_name: str,
    iterations: int,
    library: Path,
    output: Path,
) -> tuple[dict[str, int], float]:
    env = os.environ.copy()
    env["LD_PRELOAD"] = str(library)
    env["NIMDRAKE_FFI_OUTPUT"] = str(output)
    result = run_command(
        benchmark_command(binary, case_name, iterations), env=env, timeout=600
    )
    return json.loads(output.read_text()), result.elapsed  # type: ignore[attr-defined]


def run_ffi(
    binary: Path,
    case_name: str,
    iterations: int,
    library: Path,
    case_dir: Path,
) -> dict:
    one, one_seconds = run_ffi_once(
        binary, case_name, 1, library, case_dir / "ffi-one.json"
    )
    if iterations > 1:
        many, many_seconds = run_ffi_once(
            binary, case_name, iterations, library, case_dir / "ffi-many.json"
        )
        per_iteration = {
            key: (many.get(key, 0) - one.get(key, 0)) / (iterations - 1)
            for key in set(one) | set(many)
        }
    else:
        many = one
        many_seconds = one_seconds
        per_iteration = {key: float(value) for key, value in one.items()}
    return {
        "iterations": iterations,
        "seconds": round(many_seconds, 6),
        "one": one,
        "many": many,
        "per_iteration": per_iteration,
    }


def run_samply(
    samply: str,
    binary: Path,
    case_name: str,
    iterations: int,
    case_dir: Path,
) -> dict:
    output = case_dir / "samply.json.gz"
    result = run_command(
        [
            samply,
            "record",
            "--save-only",
            "--no-open",
            "-o",
            str(output),
            "--",
            *benchmark_command(binary, case_name, iterations),
        ],
        timeout=600,
        output=case_dir / "samply.log",
    )
    with gzip.open(output, "rt") as profile_file:
        profile_dump = json.load(profile_file)
    return {
        "iterations": iterations,
        "seconds": round(result.elapsed, 6),  # type: ignore[attr-defined]
        "profile": str(output.relative_to(case_dir.parent.parent)),
        "record_dump": result.stdout,
        "profile_dump": profile_dump,
    }


def percent(part: float, whole: float) -> float:
    if whole == 0:
        return 0.0
    return part * 100.0 / whole


def short_symbol(symbol: str, limit: int = 90) -> str:
    symbol = symbol.replace("|", "\\|")
    if len(symbol) <= limit:
        return symbol
    return symbol[: limit - 3] + "..."


def refresh_case_dumps(summary: dict, output: Path) -> None:
    """Load persisted profiler reports into summary.json for offline analysis."""
    for case in summary["cases"]:
        if case.get("status") != "ok":
            continue
        case_dir = output / "cases" / case["benchmark"] / case["case"]

        perf_report = case_dir / "perf-report.txt"
        perf_record = case_dir / "perf-record.log"
        if perf_report.is_file():
            report_text = perf_report.read_text()
            case.setdefault("perf", {}).update(
                parse_perf_report(report_text, case["benchmark"])
            )
            case["perf"]["report_dump"] = report_text
        if perf_record.is_file():
            case.setdefault("perf", {})["record_dump"] = perf_record.read_text()

        heap_prefix = "heaptrack-many" if (
            case_dir / "heaptrack-many-report.txt"
        ).is_file() else "heaptrack-one"
        heap_report = case_dir / f"{heap_prefix}-report.txt"
        heap_record = case_dir / f"{heap_prefix}-record.log"
        if heap_report.is_file():
            case.setdefault("heaptrack", {})["report_dump"] = heap_report.read_text()
        if heap_record.is_file():
            case.setdefault("heaptrack", {})["record_dump"] = heap_record.read_text()
        baseline_report = case_dir / "heaptrack-one-report.txt"
        baseline_record = case_dir / "heaptrack-one-record.log"
        if heap_prefix == "heaptrack-many" and baseline_report.is_file():
            case.setdefault("heaptrack", {})[
                "baseline_report_dump"
            ] = baseline_report.read_text()
        if heap_prefix == "heaptrack-many" and baseline_record.is_file():
            case.setdefault("heaptrack", {})[
                "baseline_record_dump"
            ] = baseline_record.read_text()

        samply_profile = case_dir / "samply.json.gz"
        samply_log = case_dir / "samply.log"
        if samply_profile.is_file():
            with gzip.open(samply_profile, "rt") as profile_file:
                case.setdefault("samply", {})["profile_dump"] = json.load(profile_file)
        if samply_log.is_file():
            case.setdefault("samply", {})["record_dump"] = samply_log.read_text()

        ffi_one = case_dir / "ffi-one.json"
        ffi_many = case_dir / "ffi-many.json"
        if ffi_one.is_file():
            case.setdefault("ffi", {})["one"] = json.loads(ffi_one.read_text())
        if ffi_many.is_file():
            case.setdefault("ffi", {})["many"] = json.loads(ffi_many.read_text())


def write_summary(summary: dict, path: Path) -> None:
    path.write_text(json.dumps(summary, separators=(",", ":")) + "\n")


def write_report(summary: dict, output: Path) -> None:
    cases = [case for case in summary["cases"] if case.get("status") == "ok"]
    failed = [case for case in summary["cases"] if case.get("status") != "ok"]
    category_points: Counter[str] = Counter()
    nim_symbols: Counter[str] = Counter()
    unknown_symbols: Counter[str] = Counter()
    allocators: defaultdict[tuple[str, str], list[float]] = defaultdict(list)
    ffi_activity: defaultdict[str, list[float]] = defaultdict(list)
    total_samples = 0
    unknown_points = 0.0

    for case in cases:
        perf = case.get("perf", {})
        total_samples += perf.get("samples", 0)
        unknown_points += perf.get("unknown_percent", 0.0)
        category_points.update(perf.get("category_percent", {}))
        for entry in perf.get("top_symbols", []):
            key = f"{entry['dso']} :: {entry['symbol']}"
            if entry["category"] == "nim":
                nim_symbols[entry["symbol"]] += entry["percent"]
        for entry in perf.get("top_unknown_symbols", []):
            key = f"{entry['dso']} :: {entry['symbol']}"
            if entry["unresolved"]:
                unknown_symbols[key] += entry["percent"]
        heap = case.get("heaptrack", {})
        for entry in heap.get("top_allocators", []):
            calls = entry.get("calls_per_iteration", 0.0)
            if calls > 0:
                allocators[(case["id"], entry["symbol"])].append(calls)
        for key, value in case.get("ffi", {}).get("per_iteration", {}).items():
            if value:
                ffi_activity[key].append(value)

    lines = [
        "# NimDrake Profiling Activity Report",
        "",
        f"Generated: `{summary['metadata']['generated_at']}`",
        "",
        "This report uses one calibrated run for each profile case. It reports self CPU time, allocation activity, and selected FFI calls.",
        "",
        "## Coverage",
        "",
        f"- Successful cases: **{len(cases)}**",
        f"- Skipped or failed cases: **{len(failed)}**",
        f"- Perf samples: **{total_samples:,}**",
        f"- Mean unresolved self time: **{unknown_points / max(len(cases), 1):.2f}%**",
        "",
    ]
    if failed:
        lines.extend(["### Skipped Or Failed", "", "| Case | Status | Reason |", "|---|---|---|"])
        for case in failed:
            lines.append(
                f"| `{case['id']}` | {case['status']} | {short_symbol(case.get('error', ''))} |"
            )
        lines.append("")

    lines.extend(
        [
            "## CPU Activity",
            "",
            "The percentages use self samples. Parent frames do not receive time from child frames.",
            "",
            "| Category | Mean case share |",
            "|---|---:|",
        ]
    )
    for category, points in category_points.most_common():
        lines.append(f"| {category} | {points / max(len(cases), 1):.2f}% |")

    lines.extend(
        [
            "",
            "### Top Nim Hotspots",
            "",
            "| Symbol | Mean share across all cases |",
            "|---|---:|",
        ]
    )
    for symbol, points in nim_symbols.most_common(25):
        lines.append(f"| `{short_symbol(symbol)}` | {points / max(len(cases), 1):.2f}% |")

    case_index = {case["id"]: case for case in cases}
    comparisons = [
        ("Scalar string input", "bench_callbacks/scalar_borrowed", "bench_callbacks/scalar_owning"),
        ("Aggregate callback", "bench_callbacks/aggregate_builtin", "bench_callbacks/aggregate_row"),
        ("Aggregate vector callback", "bench_callbacks/aggregate_builtin", "bench_callbacks/aggregate_vector"),
        ("Nested LIST access", "bench_data_paths/nested_borrowed", "bench_data_paths/nested_owning"),
        ("Nullable read", "bench_data_paths/nullable_items", "bench_data_paths/nullable_bulk"),
        ("MAP lookup", "bench_map/borrowed_lookup", "bench_map/owning_lookup"),
        ("String vector read", "bench_vector/string_borrow", "bench_vector/string_read"),
        ("Integer vector read", "bench_vector/indexed_read", "bench_vector/bulk_read"),
    ]
    lines.extend(
        [
            "",
            "## Paired Activity",
            "",
            "Time comes from startup-adjusted calibration. Ratios compare case B with case A on this machine.",
            "",
            "| Comparison | Case A | Case B | Time B/A | Allocations B/A |",
            "|---|---|---|---:|---:|",
        ]
    )
    for label, left_id, right_id in comparisons:
        left = case_index.get(left_id)
        right = case_index.get(right_id)
        if left is None or right is None:
            continue
        left_time = left.get("calibration", {}).get("estimated_iteration_seconds", 0.0)
        right_time = right.get("calibration", {}).get("estimated_iteration_seconds", 0.0)
        left_alloc = max(
            left.get("heaptrack", {}).get("allocations_per_iteration", 0.0), 0.0
        )
        right_alloc = max(
            right.get("heaptrack", {}).get("allocations_per_iteration", 0.0), 0.0
        )
        time_ratio = right_time / left_time if left_time else 0.0
        if left_alloc:
            allocation_ratio = f"{right_alloc / left_alloc:.2f}x"
        elif right_alloc:
            allocation_ratio = "new allocations"
        else:
            allocation_ratio = "1.00x"
        lines.append(
            f"| {label} | `{left_id}` | `{right_id}` | {time_ratio:.2f}x | {allocation_ratio} |"
        )

    lines.extend(
        [
            "",
            "## Allocation Activity",
            "",
            "The harness subtracts a one-iteration trace from a repeated trace. Values show allocations for each additional workload iteration.",
            "",
            "| Case | Top allocator | Calls per iteration |",
            "|---|---|---:|",
        ]
    )
    ranked_allocators = sorted(
        (
            (sum(values) / len(values), case_id, symbol)
            for (case_id, symbol), values in allocators.items()
        ),
        reverse=True,
    )
    for calls, case_id, symbol in ranked_allocators[:30]:
        lines.append(f"| `{case_id}` | `{short_symbol(symbol)}` | {calls:,.1f} |")

    lines.extend(
        [
            "",
            "## FFI Activity",
            "",
            "The harness subtracts a one-iteration run from a repeated run. Values show the mean calls for each additional iteration.",
            "",
            "| Counter | Maximum calls per iteration | Mean active rate | Active cases |",
            "|---|---:|---:|---:|",
        ]
    )
    for key, values in sorted(
        ffi_activity.items(), key=lambda item: max(item[1]), reverse=True
    ):
        lines.append(
            f"| `{key}` | {max(values):,.1f} | {sum(values) / len(values):,.1f} | {len(values)} |"
        )

    lines.extend(
        [
            "",
            "## Unknown Attribution",
            "",
            "Unresolved symbols can hide actionable work. A high value requires a build with debug symbols for the responsible library.",
            "Unknown time is an overlay. It can overlap the runtime, Arrow, DuckDB, or kernel categories.",
            "",
            "| DSO and symbol | Mean share across all cases |",
            "|---|---:|",
        ]
    )
    if unknown_symbols:
        for symbol, points in unknown_symbols.most_common(20):
            lines.append(f"| `{short_symbol(symbol)}` | {points / max(len(cases), 1):.2f}% |")
    else:
        lines.append("| None | 0.00% |")

    lines.extend(
        [
            "",
            "## Case Activity Matrix",
            "",
            "| Case | Time/iteration | Nim | DuckDB | Arrow | Runtime | Kernel | Unknown | Allocations/iteration | Temporary/iteration |",
            "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for case in cases:
        perf = case.get("perf", {})
        categories = perf.get("category_percent", {})
        heap = case.get("heaptrack", {})
        allocations = max(heap.get("allocations_per_iteration", 0.0), 0.0)
        temporary = max(heap.get("temporary_allocations_per_iteration", 0.0), 0.0)
        duration_ms = case.get("calibration", {}).get(
            "estimated_iteration_seconds", 0.0
        ) * 1000
        lines.append(
            f"| `{case['id']}` | {duration_ms:.3f} ms | "
            f"{categories.get('nim', 0):.1f}% | "
            f"{categories.get('duckdb', 0):.1f}% | "
            f"{categories.get('arrow', 0):.1f}% | "
            f"{categories.get('runtime', 0):.1f}% | "
            f"{categories.get('kernel', 0):.1f}% | "
            f"{perf.get('unknown_percent', 0):.1f}% | "
            f"{allocations:,.1f} | {temporary:,.1f} |"
        )

    lines.extend(
        [
            "",
            "## Profile Files",
            "",
            "Each case directory contains `perf.data`, a Heaptrack trace, and `samply.json.gz`.",
            "Use these files to inspect call graphs before an optimization change.",
            "",
            f"Run directory: `{output}`",
            "",
        ]
    )
    (output / "ACTIVITY_REPORT.md").write_text("\n".join(lines))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--target-seconds", type=float, default=1.0)
    parser.add_argument("--heaptrack-max-iterations", type=int, default=10)
    parser.add_argument("--ffi-max-iterations", type=int, default=100)
    parser.add_argument("--skip-arrow", action="store_true")
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Keep successful cases in an existing output and retry other cases.",
    )
    parser.add_argument(
        "--bench",
        action="append",
        choices=sorted(CASES),
        help="Profile one benchmark. Repeat this option to select more benchmarks.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.target_seconds <= 0:
        raise ValueError("--target-seconds must be positive")
    if args.heaptrack_max_iterations < 1 or args.ffi_max_iterations < 1:
        raise ValueError("iteration limits must be positive")

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output = (args.output or ROOT / "profiles" / f"suite-{stamp}").resolve()
    if args.resume and args.output is None:
        raise ValueError("--resume requires --output")
    (output / "logs").mkdir(parents=True, exist_ok=True)
    (output / "cases").mkdir(parents=True, exist_ok=True)

    tools = {
        "nim": require_tool("nim"),
        "cc": require_tool("cc"),
        "perf": require_tool("perf"),
        "heaptrack": require_tool("heaptrack"),
        "heaptrack_print": require_tool("heaptrack_print"),
        "samply": require_tool("samply", Path.home() / ".cargo" / "bin" / "samply"),
    }
    ffi_library = output / "bin" / "ffi_counter.so"
    ffi_library.parent.mkdir(parents=True, exist_ok=True)
    run_command(
        [
            tools["cc"],
            "-shared",
            "-fPIC",
            "-O2",
            "-Wall",
            "-Wextra",
            "-o",
            str(ffi_library),
            str(BENCHMARKS / "ffi_counter.c"),
            "-ldl",
        ],
        output=output / "logs" / "ffi-counter-compile.log",
    )

    selected = args.bench or list(CASES)
    if args.skip_arrow:
        selected = [name for name in selected if name != "bench_arrow"]

    summary_path = output / "summary.json"
    if args.resume and summary_path.is_file():
        summary = json.loads(summary_path.read_text())
        summary["metadata"]["resumed_at"] = datetime.now(timezone.utc).isoformat()
    else:
        summary = {
            "metadata": {
                "generated_at": datetime.now(timezone.utc).isoformat(),
                "host": platform.node(),
                "platform": platform.platform(),
                "python": platform.python_version(),
                "target_seconds": args.target_seconds,
                "heaptrack_max_iterations": args.heaptrack_max_iterations,
                "ffi_max_iterations": args.ffi_max_iterations,
                "tools": tools,
            },
            "cases": [],
        }

    for benchmark in selected:
        print(f"==> compile {benchmark}", flush=True)
        binary, compile_error = compile_benchmark(tools["nim"], benchmark, output)
        if binary is None:
            reason = compile_error or "compile failed"
            print(f"    skip: {reason.splitlines()[-1]}", flush=True)
            for case_name, description in CASES[benchmark].items():
                case_id = f"{benchmark}/{case_name}"
                summary["cases"] = [
                    case for case in summary["cases"] if case["id"] != case_id
                ]
                summary["cases"].append(
                    {
                        "id": case_id,
                        "benchmark": benchmark,
                        "case": case_name,
                        "description": description,
                        "status": "skipped",
                        "error": reason,
                    }
                )
            continue

        for case_name, description in CASES[benchmark].items():
            case_id = f"{benchmark}/{case_name}"
            previous = next(
                (case for case in summary["cases"] if case["id"] == case_id), None
            )
            if args.resume and previous is not None and previous.get("status") == "ok":
                print(f"==> {case_id}: keep existing result", flush=True)
                continue
            summary["cases"] = [
                case for case in summary["cases"] if case["id"] != case_id
            ]
            case_dir = output / "cases" / benchmark / case_name
            case_dir.mkdir(parents=True, exist_ok=True)
            case = {
                "id": case_id,
                "benchmark": benchmark,
                "case": case_name,
                "description": description,
                "status": "running",
            }
            summary["cases"].append(case)
            print(f"==> {case_id}: calibrate", flush=True)
            try:
                calibration = calibrate(binary, case_name, args.target_seconds)
                case["calibration"] = calibration
                iterations = calibration["iterations"]
                print(f"    perf/samply iterations: {iterations}", flush=True)
                case["perf"] = run_perf(
                    tools["perf"], binary, benchmark, case_name, iterations, case_dir
                )
                heap_iterations = min(iterations, args.heaptrack_max_iterations)
                print(f"    heaptrack iterations: {heap_iterations}", flush=True)
                case["heaptrack"] = run_heaptrack(
                    tools["heaptrack"],
                    tools["heaptrack_print"],
                    binary,
                    case_name,
                    heap_iterations,
                    case_dir,
                )
                ffi_iterations = min(max(iterations, 2), args.ffi_max_iterations)
                print(f"    FFI iterations: {ffi_iterations}", flush=True)
                case["ffi"] = run_ffi(
                    binary, case_name, ffi_iterations, ffi_library, case_dir
                )
                case["samply"] = run_samply(
                    tools["samply"], binary, case_name, iterations, case_dir
                )
                case["status"] = "ok"
            except Exception as error:
                case["status"] = "failed"
                case["error"] = str(error)
                print(f"    failed: {error}", file=sys.stderr, flush=True)
            write_summary(summary, output / "summary.json")
            write_report(summary, output)

    refresh_case_dumps(summary, output)
    summary["metadata"]["completed_at"] = datetime.now(timezone.utc).isoformat()
    write_summary(summary, output / "summary.json")
    write_report(summary, output)
    print(f"Activity report: {output / 'ACTIVITY_REPORT.md'}")
    return 1 if any(case["status"] == "failed" for case in summary["cases"]) else 0


if __name__ == "__main__":
    raise SystemExit(main())
