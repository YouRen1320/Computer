#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/program-structure-faults.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

JAVAC=${JAVAC:-javac}
PASSED=0

case "$("$JAVAC" -version 2>&1 | head -n 1)" in
    "javac 25"*) ;;
    *) echo "FAIL: this lab requires javac 25.x" >&2; exit 2 ;;
esac

expect_compile_failure() {
    name=$1
    source=$2
    expected_message=$3
    mode=${4:-direct}
    case_root="$ROOT/faults/$name"
    output_dir="$WORK/$name/classes"
    log_file="$WORK/$name/javac.log"
    mkdir -p "$output_dir"

    set +e
    if [ "$mode" = "sourcepath" ]; then
        "$JAVAC" -J-Duser.language=en -J-Duser.country=US -J-Dfile.encoding=UTF-8 \
            --release 25 -encoding UTF-8 \
            -d "$output_dir" \
            -sourcepath "$case_root/src" \
            "$source" >"$log_file" 2>&1
    else
        "$JAVAC" -J-Duser.language=en -J-Duser.country=US -J-Dfile.encoding=UTF-8 \
            --release 25 -encoding UTF-8 \
            -d "$output_dir" \
            "$source" >"$log_file" 2>&1
    fi
    status=$?
    set -e

    if [ "$status" -eq 0 ]; then
        echo "FAIL: $name unexpectedly compiled" >&2
        exit 1
    fi
    if ! grep -Fq '.java:' "$log_file"; then
        echo "FAIL: $name did not produce a source location" >&2
        sed -n '1,12p' "$log_file" >&2
        exit 1
    fi
    if ! grep -Fq "$expected_message" "$log_file"; then
        echo "FAIL: $name failed for an unexpected reason; missing: $expected_message" >&2
        sed -n '1,12p' "$log_file" >&2
        exit 1
    fi

    PASSED=$((PASSED + 1))
    echo "=== $name: expected compile failure (exit $status) ==="
    sed -n '1,8p' "$log_file"
}

expect_compile_failure \
    illegal-identifier \
    "$ROOT/faults/illegal-identifier/src/com/factorycare/learning/IllegalIdentifier.java" \
    '<identifier> expected'

expect_compile_failure \
    missing-semicolon \
    "$ROOT/faults/missing-semicolon/src/com/factorycare/learning/MissingSemicolon.java" \
    "';' expected"

expect_compile_failure \
    bracket-mismatch \
    "$ROOT/faults/bracket-mismatch/src/com/factorycare/learning/BracketMismatch.java" \
    'reached end of file while parsing'

expect_compile_failure \
    package-path \
    "$ROOT/faults/package-path/src/com/factorycare/learning/Launcher.java" \
    'bad source file:' \
    sourcepath

if [ "$PASSED" -ne 4 ]; then
    echo "FAIL: expected four compile failures, observed $PASSED" >&2
    exit 1
fi

echo "PASS: 4/4 faults failed during compilation and exposed source locations."
