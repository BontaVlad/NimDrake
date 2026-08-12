# ASan and leak detection on/off (overridable with `just --set asan 0 --set leaks false test`).
asan := "1"
leaks := "1"

# Run all tests. Sequential by default, parallel with `just test 8`.
# Pass features="arrow" to also run narrow/Arrow tests.
test cores="1" features="":
    #!/usr/bin/env bash
    set -euo pipefail

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

# Run cookbook snippets; fail if any snippet fails to compile/run.
cookbook:
    nim c -r docs/cookbook/cookbook_runner.nim

# Render cookbook markdown to HTML via nim md2html (skips compiling snippets).
docs:
    #!/usr/bin/env bash
    set -euo pipefail
    for f in docs/cookbook/*.md; do
        nim md2html --docCmd:skip --outdir:docs/cookbook "$f"
    done
    echo "Rendered cookbook HTML in docs/cookbook/"

# Remove all build artifacts.
clean:
    rm -rf nimcache coverage coverage.info

# List all available commands.
default:
    @just --choose --justfile {{justfile()}}