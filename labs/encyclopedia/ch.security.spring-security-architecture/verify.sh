#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"

case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/SecurityChainLab.java"
java -cp "$BUILD_DIR/classes" SecurityChainLab > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"

run_expected_failure() {
    local mode="$1"
    local marker="$2"
    local output="$BUILD_DIR/$mode.out"
    if java -cp "$BUILD_DIR/classes" SecurityChainLab "$mode" > "$output" 2>&1; then
        echo "EXPECTED FAILURE: $mode" >&2
        exit 1
    fi
    grep -Fq "$marker" "$output"
}

run_expected_failure WIDE_MATCHER_FIRST PROTECTED_ENDPOINT_BYPASSED
run_expected_failure ANONYMOUS_DEFAULT_ALLOW ANONYMOUS_DEFAULT_ALLOWED
run_expected_failure FILTER_ORDER AUTHENTICATION_NOT_VISIBLE_AT_AUTHORIZATION
run_expected_failure NO_CATCH_ALL UNMATCHED_REQUEST_UNPROTECTED
run_expected_failure CONTEXT_NOT_CLEARED SECURITY_CONTEXT_NOT_CLEARED
run_expected_failure WRONG_EXCEPTION_MAPPING UNAUTHENTICATED_NOT_401

if rg -n 'SYNTHETIC|Authorization|Bearer' "$BUILD_DIR/actual.out" >/dev/null; then
    echo "SECURITY_CONTEXT_MATERIAL_LEAKED_TO_OUTPUT" >&2
    exit 1
fi
cat "$BUILD_DIR/actual.out"
echo "fault_oracles=6"
