# ASan and leak detection on/off (overridable with `just --set asan 0 --set leaks false test`).
asan := "1"
leaks := "1"
bench_root := "benchmarks"
bench_out := "nimcache/benchmarks"
profile_out := "profiles"

# Run all tests. Sequential by default, parallel with `just test 8`.
# Pass --features=arrow to also run narrow/Arrow tests.
[arg('features', long='features', help='Pass arrow to also run narrow/Arrow tests')]
test cores="1" features="":
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ ! "{{cores}}" =~ ^[0-9]+$ ]]; then
        echo "error: cores must be a positive integer, got '{{cores}}'" >&2
        echo "hint: just test 8 --features=arrow" >&2
        exit 2
    fi

    OUT="nimcache/tests"; mkdir -p "$OUT"
    FLAG=""
    if [[ "{{features}}" == "arrow" ]]; then
        FLAG="-d:features.nimdrake.arrow"
        FILES=(); while IFS= read -r f; do FILES+=("$f"); done < <(find tests -name 'test_*.nim' | sort)
    else
        FILES=(); while IFS= read -r f; do FILES+=("$f"); done < <(find tests -name 'test_*.nim' -not -path 'tests/narrow/*' | sort)
    fi

    ASAN="detect_leaks=1"; LSAN="suppressions=lsan.supp:print_suppressions=0"
    EXEEXT=""
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*) EXEEXT=".exe";;
        Darwin) ASAN="detect_leaks=0"; LSAN="";;
    esac
    [[ "{{leaks}}" == "0" || "{{leaks}}" == "false" ]] && ASAN="detect_leaks=0" && LSAN=""

    run() {
        local f="$1" n; n="$(basename "$f" .nim)"; mkdir -p "$OUT/$n"
        local SAN=""
        if [[ "{{asan}}" == "1" || "{{asan}}" == "true" ]]; then
            SAN="--passC:-fsanitize=address --passL:-fsanitize=address"
        fi
        ASAN_OPTIONS="$ASAN" LSAN_OPTIONS="$LSAN" \
            nim c -r --verbosity:0 --hints:off --mm:orc --excessiveStackTrace:on \
            -d:debug -d:nimDebugDlOpen --opt:none --debuginfo:on --debugger:native \
            -d:useMalloc -d:noSignalHandler $FLAG \
            --passC:-O0 --passC:-g3 \
            $SAN \
            -o:"$OUT/$n/$n$EXEEXT" "$f"
    }
    export -f run
    export OUT ASAN LSAN EXEEXT

    if [[ "{{cores}}" == "1" ]]; then
        for f in "${FILES[@]}"; do run "$f"; done
    else
        printf '%s\n' "${FILES[@]}" | xargs -P "{{cores}}" -I {} bash -c 'run "$1"' _ {}
    fi

# Run release Criterion benchmarks. Set `output` to a result directory.
# Examples: `just benchmark`, `just benchmark benchmarks/bench_map.nim`,
# `just benchmark benchmarks/bench_map.nim benchmarks/results/baseline`.
benchmark target="" output="":
    #!/usr/bin/env bash
    set -euo pipefail

    root="{{bench_root}}"
    out="{{output}}"
    [[ -n "$out" ]] || out="$root/results/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$out" "{{bench_out}}"

    target="{{target}}"
    files=()
    if [[ -z "$target" ]]; then
        for file in "$root"/bench_*.nim; do [[ -f "$file" ]] && files+=("$file"); done
    elif [[ -f "$target" ]]; then
        files=("$target")
    elif [[ -d "$target" ]]; then
        for file in "$target"/bench_*.nim; do [[ -f "$file" ]] && files+=("$file"); done
    else
        printf 'benchmark target not found: %s\n' "$target" >&2
        exit 2
    fi
    [[ ${#files[@]} -gt 0 ]] || { printf 'no benchmark files found\n' >&2; exit 2; }

    for file in "${files[@]}"; do
        [[ "$file" == "$root/bench_arrow.nim" ]] && continue
        name="$(basename "$file" .nim)"
        binary="{{bench_out}}/$name"
        echo "==> $file"
        nim c --verbosity:0 --hints:off -d:release --opt:speed --mm:orc \
            -o:"$binary" "$file"
        NIMDRAKE_BENCH_OUTPUT="$out/$name.json" "$binary"
    done
    echo "Benchmark results: $out"

# Run the optional Narrow/Arrow benchmark with the Arrow feature enabled.
benchmark-arrow target="benchmarks/bench_arrow.nim" output="":
    #!/usr/bin/env bash
    set -euo pipefail
    file="{{target}}"
    [[ -f "$file" ]] || { echo "benchmark file not found: $file" >&2; exit 2; }
    out="{{output}}"
    [[ -n "$out" ]] || out="{{bench_root}}/results/arrow-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$out" "{{bench_out}}"
    name="$(basename "$file" .nim)"
    binary="{{bench_out}}/$name"
    nim c --verbosity:0 --hints:off -d:release --opt:speed --mm:orc \
        -d:features.nimdrake.arrow -o:"$binary" "$file"
    NIMDRAKE_BENCH_OUTPUT="$out/$name.json" "$binary"

# Compare matching Criterion JSON files or two JSON files.
benchmark-compare baseline candidate threshold="0":
    python3 "{{bench_root}}/compare.py" "{{baseline}}" "{{candidate}}" --threshold "{{threshold}}"

# Record one deterministic heaptrack profile. `target` is a benchmark file.
# Example: `just benchmark-heaptrack benchmarks/bench_map.nim borrowed_lookup 100`.
benchmark-heaptrack target case iterations="100":
    #!/usr/bin/env bash
    set -euo pipefail
    command -v heaptrack >/dev/null || { echo "heaptrack is required" >&2; exit 127; }
    command -v heaptrack_print >/dev/null || { echo "heaptrack_print is required" >&2; exit 127; }
    file="{{target}}"
    [[ -f "$file" ]] || { echo "benchmark file not found: $file" >&2; exit 2; }
    mkdir -p "{{bench_out}}" "{{profile_out}}"
    name="$(basename "$file" .nim)"
    binary="{{bench_out}}/$name"
    nim c --verbosity:0 --hints:off -d:release --opt:speed --mm:orc -d:useMalloc \
        --debuginfo:on --passC:-g --passC:-fno-omit-frame-pointer \
        --passL:-g -o:"$binary" "$file"
    base="{{profile_out}}/${name}-{{case}}-$(date +%Y%m%d_%H%M%S)"
    heaptrack --record-only -o "$base" "$binary" --profile-case "{{case}}" --iterations "{{iterations}}"
    trace=""
    for candidate in "$base"*.zst "$base"*.gz; do [[ -f "$candidate" ]] && trace="$candidate"; done
    [[ -n "$trace" ]] || { echo "heaptrack trace not found for $base" >&2; exit 1; }
    heaptrack_print --print-allocators --print-peaks --print-temporary --print-leaks \
        -f "$trace" | tee "$trace.txt"
    python3 "{{bench_root}}/heaptrack_summary.py" "$trace.txt" --output "$trace.json"
    echo "Heaptrack trace: $trace"

# Count selected DuckDB FFI calls for one deterministic profile case.
benchmark-ffi target case iterations="100":
    #!/usr/bin/env bash
    set -euo pipefail
    command -v cc >/dev/null || { echo "a C compiler is required" >&2; exit 127; }
    file="{{target}}"
    [[ -f "$file" ]] || { echo "benchmark file not found: $file" >&2; exit 2; }
    mkdir -p "{{bench_out}}" "{{profile_out}}"
    cc -shared -fPIC -O2 -Wall -Wextra -o "{{bench_out}}/ffi_counter.so" \
        "{{bench_root}}/ffi_counter.c" -ldl
    name="$(basename "$file" .nim)"
    binary="{{bench_out}}/$name"
    nim c --verbosity:0 --hints:off -d:release --opt:speed --mm:orc \
        -o:"$binary" "$file"
    output="{{profile_out}}/${name}-{{case}}-$(date +%Y%m%d_%H%M%S).json"
    LD_PRELOAD="$(pwd)/{{bench_out}}/ffi_counter.so" \
    NIMDRAKE_FFI_OUTPUT="$output" \
        "$binary" --profile-case "{{case}}" --iterations "{{iterations}}"
    python3 -m json.tool "$output"

# Regenerate FFI bindings from duckdb.h via Futhark.
generate:
    nim c -r -d:useFuthark -d:nodeclguards:true -d:exportall:true src/nimdrake.nim

# Vendor libduckdb.so + duckdb.h into src/include/ (linux amd64, glibc).
fetch-lib:
    #!/usr/bin/env bash
    set -euo pipefail
    D="src/include"; V="v1.5.4"; A="libduckdb-linux-amd64.zip"
    T="$(mktemp -d)"; mkdir -p "$D"
    wget -q "https://github.com/duckdb/duckdb/releases/download/$V/$A" -O "$T/$A"
    unzip -o "$T/$A" -d "$T/x"; cp "$T/x/libduckdb.so" "$D/"; cp "$T/x/duckdb.h" "$D/"
    rm -rf "$T"; echo "Vendored libduckdb to $D/"; ls -la "$D/"

# Build the cookbook with nimibook; every snippet is executed and its output
# embedded in the book. Fails if any snippet breaks. Requires nimibook
# (`nimble install -y nimibook`) and libpcre on Linux (Ubuntu: libpcre3).
# When pcre is only available in the user's home (e.g. ~/.local/lib), it is
# picked up via LD_LIBRARY_PATH below. A missing directory is harmless.
cookbook:
    #!/usr/bin/env bash
    set -euo pipefail
    export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$HOME/.local/lib"
    cd docs/cookbook
    nim r nbook.nim init
    nim r nbook.nim build --mm:arc

# Render the cookbook book (same as `cookbook`; kept for compatibility).
docs:
    just cookbook

# Enforce that every exported symbol has a doc comment (CI gate; see
# .github/workflows/docs.yml).
checkdocs:
    nim r --hints:off tools/checkdocs.nim

# Remove all build artifacts.
clean:
    rm -rf nimcache coverage coverage.info

# Remove benchmark-only output without touching source or test artifacts.
benchmark-clean:
    rm -rf "{{bench_out}}" "{{profile_out}}" "{{bench_root}}/results"

# List all available commands.
default:
    @just --choose --justfile {{justfile()}}
