# =============================================================================
# Configuration
# =============================================================================

# Directories
test_root    := "tests"
bench_root   := "benchmarks"
out_root     := "nimcache"
profile_dir  := "profiles"
coverage_dir := "coverage"

# Test defaults
parallel := "false"
cores    := "4"
mm       := "orc"      # orc | arc
mode     := "debug"    # debug | release
leaks    := "true"     # true | false
cc       := "gcc"

# =============================================================================
# Flag sets (shell variable fragments, spliced into recipes)
# =============================================================================

_base_flags := "--verbosity:0 --hints:off --lineDir:on"

_debug_flags := "-d:debug -d:nimDebugDlOpen --opt:none --stacktrace:on --debuginfo:on --debugger:native -d:useMalloc --passC:-O0 --passC:-g3"

_sanitizer_flags := "--passC:-fsanitize=address --passL:-fsanitize=address"

_release_flags := "-d:release --opt:speed"

# =============================================================================
# Public targets
# =============================================================================

# List all available commands
default:
    @just --choose --justfile {{justfile()}}

# Run tests with current settings
test: (_run-tests parallel cores mm mode leaks)

# Convenience presets
test-debug: (_run-tests "false" "4" "orc" "debug" "true")
test-debug-par: (_run-tests "true" "8" "orc" "debug" "true")
test-release: (_run-tests "false" "4" "orc" "release" "false")
test-arc: (_run-tests "false" "4" "arc" "debug" "true")

# Run narrow/Arrow tests (requires -d:features.nimdrake.arrow)
test-arrow: (_run-tests-arrow parallel cores mm mode leaks)

# Generate lcov coverage report
coverage: (_run-tests-gcov)
    #!/usr/bin/env bash
    set -euo pipefail

    OUT_ROOT="{{out_root}}/tests"
    COV_DIR="{{coverage_dir}}"
    LCOV_FILE="coverage.info"

    GCDA_COUNT=$(find "$OUT_ROOT" -name "*.gcda" | wc -l)
    if [[ "$GCDA_COUNT" -eq 0 ]]; then
        echo "No coverage data (.gcda files) found."; exit 1
    fi
    echo "Found $GCDA_COUNT .gcda files"

    rm -rf "$COV_DIR"
    mkdir -p "$COV_DIR"

    lcov --capture \
        --directory "$OUT_ROOT" \
        --output-file "$LCOV_FILE" \
        --rc lcov_branch_coverage=1 \
        --ignore-errors inconsistent,unused,gcov

    lcov --extract "$LCOV_FILE" "*/src/*.nim" \
        --output-file "$LCOV_FILE" \
        --rc lcov_branch_coverage=1 \
        --ignore-errors inconsistent

    lcov --remove "$LCOV_FILE" "*/generated.nim" \
        --output-file "$LCOV_FILE" \
        --rc lcov_branch_coverage=1 \
        --ignore-errors inconsistent

    genhtml "$LCOV_FILE" \
        --output-directory "$COV_DIR" \
        --branch-coverage --legend \
        --ignore-errors inconsistent,missing,corrupt,range

    echo ""
    echo "Coverage Summary:"
    lcov --summary "$LCOV_FILE" --rc lcov_branch_coverage=1 \
        --ignore-errors corrupt,inconsistent 2>&1 \
        | grep -E "(lines|functions|branches)" || true
    echo ""
    echo "Report: $COV_DIR/index.html"

# Recursively format all Nim files in a specific directory
format directory="src":
    #!/usr/bin/env bash
    find "{{directory}}" -type f -name "*.nim" -print0 | while IFS= read -r -d '' file; do
        echo "Formatting $file..."
        nph "$file"
    done

# Build and debug a single file with lldb
dbg file:
    #!/usr/bin/env bash
    set -euo pipefail

    name="$(basename "{{file}}" .nim)"
    outdir="{{out_root}}/dbg"
    mkdir -p "$outdir"

    nim c \
        {{_base_flags}} \
        --cc:{{cc}} \
        --mm:{{mm}} \
        {{_debug_flags}} \
        --excessiveStackTrace:on \
        -o:"$outdir/$name" \
        "{{file}}"

    lldb "$outdir/$name"

# Debug with rr and connect lldb to the specific target
debug nim_file="tests/results/test_result_type.nim":
    #!/usr/bin/env bash
    set -euo pipefail

    BASENAME=$(basename "{{nim_file}}" .nim)
    DIRNAME=$(dirname "{{nim_file}}")
    OUTPUT_PATH="${DIRNAME}/${BASENAME}"

    nim c \
        -d:debug \
        -d:nimDebugDlOpen \
        --opt:none \
        --debugger:native \
        --stacktrace:on \
        -d:useMalloc \
        --mm:orc \
        --passC:-O0 \
        --passC:-g3 \
        --passC:-fno-omit-frame-pointer \
        --passC:-gdwarf-4 \
        --linedir:on \
        --debuginfo:on \
        --threads:off \
        --excessiveStackTrace:on \
        "{{nim_file}}"

# Debug with rr and connect lldb to the specific target
debug-run nim_file="src/duckdb" name="":
    #!/usr/bin/env bash
    set -euo pipefail

    BASENAME=$(basename "{{nim_file}}" .nim)
    DIRNAME=$(dirname "{{nim_file}}")
    OUTPUT_PATH="${DIRNAME}/${BASENAME}"

    nim c \
        -r \
        -d:debug \
        -d:nimDebugDlOpen \
        --cc:clang \
        --opt:none \
        --panics:on \
        --debugger:native \
        --passc:-fsanitize=address \
        --passl:-fsanitize=address \
        --stacktrace:on \
        -d:useMalloc \
        --mm:orc \
        --passC:-O1 \
        --passC:-ggdb3 \
        --passC:-fno-omit-frame-pointer \
        --passC:-gdwarf-4 \
        --passC:-Wno-implicit-function-declaration \
        --lineDir:on \
        --debuginfo:on \
        --threads:off \
        --excessiveStackTrace:on \
        "{{nim_file}}" \
        "{{name}}"

# Run Valgrind on a Nim file to analyze memory usage
valgrind nim_file="tests/results/test_result_type.nim" name="":
    #!/usr/bin/env bash
    set -euo pipefail

    BASENAME=$(basename "{{nim_file}}" .nim)
    DIRNAME=$(dirname "{{nim_file}}")
    OUTPUT_PATH="${DIRNAME}/${BASENAME}"

    nim c \
        -d:debug \
        -d:nimDebugDlOpen \
        --opt:none \
        --debugger:native \
        --stacktrace:on \
        -d:useMalloc \
        --mm:orc \
        --passC:-O0 \
        --passC:-g3 \
        --passC:-gdwarf-4 \
        --linedir:on \
        --lineDir:on \
        --debuginfo:on \
        --threads:off \
        --excessiveStackTrace:on \
        "{{nim_file}}"

    valgrind \
        --leak-check=full \
        --show-leak-kinds=definite,possible \
        --track-origins=yes \
        --verbose \
        "${OUTPUT_PATH}"

# Run with maximum performance compiler flags for benchmarking
benchmark name="":
    #!/usr/bin/env bash
    set -euo pipefail

    NIMCACHE_DIR="{{out_root}}/benchmarks"
    mkdir -p "$NIMCACHE_DIR"

    find ./benchmarks -name "benchmark_*{{name}}*.nim" | while read -r file; do
        echo "Processing file: $file"
        filename=$(basename "$file")
        filename_no_ext="${filename%.nim}"

        nim c \
            -r \
            -d:release \
            -d:danger \
            --verbosity:0 \
            --hints:off \
            --opt:speed \
            --panics:on \
            --passC:"-flto -march=native -ffast-math -funroll-loops -fopt-info-vec" \
            --passL:"-flto" \
            -o:"${NIMCACHE_DIR}/${filename_no_ext}" \
            "$file"

        "${NIMCACHE_DIR}/${filename_no_ext}"
        echo "Running file: $file"
    done

# Generate new duckdb.h wrappers
generate:
    #!/usr/bin/env bash
    set -euo pipefail
    nim c \
        -r \
        -d:useFuthark \
        -d:nodeclguards:true \
        -d:exportall:true \
        src/nimdrake.nim

# Build a statically linked version
build-static:
    #!/usr/bin/env bash
    set -euo pipefail
    nim cpp \
        -d:release \
        --passL:"-static" \
        --passL:"-L$(pwd)" \
        --passL:"-l:src/include/libduckdb_bundle.a" \
        --passL:"-lstdc++" \
        src/nimdrake

# Vendor libduckdb.so + duckdb.h into src/include/ (linux amd64, glibc).
fetch-lib:
    #!/usr/bin/env bash
    set -euo pipefail

    INCLUDE_DIR="{{justfile_directory()}}/src/include"
    DUCKDB_VERSION="v1.5.4"
    ASSET="libduckdb-linux-amd64.zip"
    URL="https://github.com/duckdb/duckdb/releases/download/${DUCKDB_VERSION}/${ASSET}"
    TMP_DIR="$(mktemp -d)"

    mkdir -p "${INCLUDE_DIR}"

    echo "Downloading ${ASSET} (${DUCKDB_VERSION})..."
    wget -q "${URL}" -O "${TMP_DIR}/${ASSET}"

    if command -v unzip &>/dev/null; then
      unzip -o "${TMP_DIR}/${ASSET}" -d "${TMP_DIR}/extract"
    else
      mkdir -p "${TMP_DIR}/extract"
      bsdtar -xf "${TMP_DIR}/${ASSET}" -C "${TMP_DIR}/extract"
    fi

    cp "${TMP_DIR}/extract/libduckdb.so" "${INCLUDE_DIR}/"
    cp "${TMP_DIR}/extract/duckdb.h"     "${INCLUDE_DIR}/"

    rm -rf "${TMP_DIR}"
    echo "Vendored libduckdb to ${INCLUDE_DIR}/"
    ls -la "${INCLUDE_DIR}/"

# Remove all build artifacts
clean:
    rm -rf {{out_root}} {{coverage_dir}} coverage.info {{profile_dir}}

# =============================================================================
# Internal targets
# =============================================================================

_run-tests parallel cores mm mode leaks:
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ROOT="{{test_root}}"
    OUT_ROOT="{{out_root}}/tests"
    PARALLEL="{{parallel}}"
    CORES="{{cores}}"
    MM="{{mm}}"
    MODE="{{mode}}"
    CC="{{cc}}"

    BASE_FLAGS="{{_base_flags}}"
    DEBUG_FLAGS="{{_debug_flags}}"
    SANITIZER_FLAGS="{{_sanitizer_flags}}"
    RELEASE_FLAGS="{{_release_flags}}"

    mkdir -p "$OUT_ROOT"
    mapfile -t TEST_FILES < <(\
        find "$TEST_ROOT" -name 'test_*.nim' -not -path "$TEST_ROOT/narrow/*" | sort \
    )

    if [[ "{{leaks}}" == "true" ]]; then
        ASAN_OPTIONS="detect_leaks=1"
        LSAN_OPTIONS="suppressions=lsan.supp:print_suppressions=0"
    else
        ASAN_OPTIONS="detect_leaks=0"
        LSAN_OPTIONS=""
    fi

    run_test() {
        local file="$1"
        local name outdir binary
        name="$(basename "$file" .nim)"
        outdir="$OUT_ROOT/$name"
        binary="$outdir/$name"
        mkdir -p "$outdir"

        local flags="$BASE_FLAGS --cc:$CC --mm:$MM --excessiveStackTrace:on"

        if [[ "$MODE" == "debug" ]]; then
            flags="$flags $DEBUG_FLAGS $SANITIZER_FLAGS -d:noSignalHandler"
        else
            flags="$flags $RELEASE_FLAGS"
        fi

        echo "==> $file"
        eval nim c $flags -o:"$binary" "$file"

        ASAN_OPTIONS="$ASAN_OPTIONS" \
        LSAN_OPTIONS="$LSAN_OPTIONS" \
            "$binary"
    }

    export -f run_test
    export OUT_ROOT MM MODE CC ASAN_OPTIONS LSAN_OPTIONS
    export BASE_FLAGS DEBUG_FLAGS SANITIZER_FLAGS RELEASE_FLAGS

    if [[ "$PARALLEL" == "true" ]]; then
        printf '%s\n' "${TEST_FILES[@]}" \
            | xargs -P "$CORES" -I {} bash -c 'run_test "$1"' _ {}
    else
        for file in "${TEST_FILES[@]}"; do
            run_test "$file"
        done
    fi

_run-tests-arrow parallel cores mm mode leaks:
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ROOT="{{test_root}}/narrow"
    OUT_ROOT="{{out_root}}/narrow-tests"
    PARALLEL="{{parallel}}"
    CORES="{{cores}}"
    MM="{{mm}}"
    MODE="{{mode}}"
    CC="{{cc}}"

    BASE_FLAGS="{{_base_flags}}"
    DEBUG_FLAGS="{{_debug_flags}}"
    SANITIZER_FLAGS="{{_sanitizer_flags}}"
    RELEASE_FLAGS="{{_release_flags}}"

    mkdir -p "$OUT_ROOT"
    mapfile -t TEST_FILES < <(find "$TEST_ROOT" -name 'test_*.nim' | sort)

    if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
        echo "No Arrow tests found in $TEST_ROOT/"
        exit 0
    fi

    if [[ "{{leaks}}" == "true" ]]; then
        ASAN_OPTIONS="detect_leaks=1"
        LSAN_OPTIONS="suppressions=lsan.supp:print_suppressions=0"
    else
        ASAN_OPTIONS="detect_leaks=0"
        LSAN_OPTIONS=""
    fi

    run_test() {
        local file="$1"
        local name outdir binary
        name="$(basename "$file" .nim)"
        outdir="$OUT_ROOT/$name"
        binary="$outdir/$name"
        mkdir -p "$outdir"

        local flags="$BASE_FLAGS --cc:$CC --mm:$MM --excessiveStackTrace:on -d:features.nimdrake.arrow"

        if [[ "$MODE" == "debug" ]]; then
            flags="$flags $DEBUG_FLAGS $SANITIZER_FLAGS -d:noSignalHandler"
        else
            flags="$flags $RELEASE_FLAGS"
        fi

        echo "==> $file"
        eval nim c $flags -o:"$binary" "$file"

        ASAN_OPTIONS="$ASAN_OPTIONS" \
        LSAN_OPTIONS="$LSAN_OPTIONS" \
            "$binary"
    }

    export -f run_test
    export OUT_ROOT MM MODE CC ASAN_OPTIONS LSAN_OPTIONS
    export BASE_FLAGS DEBUG_FLAGS SANITIZER_FLAGS RELEASE_FLAGS

    if [[ "$PARALLEL" == "true" ]]; then
        printf '%s\n' "${TEST_FILES[@]}" \
            | xargs -P "$CORES" -I {} bash -c 'run_test "$1"' _ {}
    else
        for file in "${TEST_FILES[@]}"; do
            run_test "$file"
        done
    fi

_run-tests-gcov:
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ROOT="{{test_root}}"
    OUT_ROOT="{{out_root}}/tests"

    find "$OUT_ROOT" -name "*.gcda" -delete 2>/dev/null || true
    rm -f coverage.info

    mkdir -p "$OUT_ROOT"
    mapfile -t TEST_FILES < <(\
        find "$TEST_ROOT" -name 'test_*.nim' -not -path "$TEST_ROOT/narrow/*" | sort \
    )

    for file in "${TEST_FILES[@]}"; do
        name="$(basename "$file" .nim)"
        outdir="$OUT_ROOT/$name"
        cache_dir="$outdir/cache"
        mkdir -p "$outdir"

        echo "==> Compiling: $file"
        nim c \
            --cc:gcc \
            {{_base_flags}} \
            --mm:orc \
            --debugger:native \
            -d:debug --opt:none \
            --passC:--coverage --passL:--coverage \
            --nimcache:"$cache_dir" \
            -o:"$outdir/$name" \
            "$file"

        echo "==> Running: $name"
        "$outdir/$name" || true
    done
