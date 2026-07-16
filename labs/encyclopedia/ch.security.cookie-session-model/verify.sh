#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"

case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/CookieSessionLab.java"
java -cp "$BUILD_DIR/classes" CookieSessionLab > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"

run_expected_failure() {
    local mode="$1"
    local marker="$2"
    local output="$BUILD_DIR/$mode.out"
    if java -cp "$BUILD_DIR/classes" CookieSessionLab "$mode" > "$output" 2>&1; then
        echo "EXPECTED FAILURE: $mode" >&2
        exit 1
    fi
    grep -Fq "$marker" "$output"
}

run_expected_failure WIDE_COOKIE_SCOPE COOKIE_SCOPE_TOO_WIDE
run_expected_failure FIXATION_REUSE SESSION_ID_NOT_ROTATED
run_expected_failure LOGOUT_CLIENT_ONLY LOGOUT_SERVER_STATE_NOT_INVALIDATED
run_expected_failure EXPIRED_ACCEPTED EXPIRED_SESSION_ACCEPTED

if rg -n 'SYNTHETIC-.*ID' "$BUILD_DIR/actual.out" >/dev/null; then
    echo "SYNTHETIC_SESSION_LEAKED_TO_OUTPUT" >&2
    exit 1
fi
cat "$BUILD_DIR/actual.out"
echo "fault_oracles=4"
