#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"

case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/InputBoundaryLab.java"
java -cp "$BUILD_DIR/classes" InputBoundaryLab > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"

run_expected_failure() {
    local mode="$1"
    local marker="$2"
    local output="$BUILD_DIR/$mode.out"
    if java -cp "$BUILD_DIR/classes" InputBoundaryLab "$mode" > "$output" 2>&1; then
        echo "EXPECTED FAILURE: $mode" >&2
        exit 1
    fi
    grep -Fq "$marker" "$output"
}

run_expected_failure CSRF_DISABLED CROSS_SITE_WRITE_ACCEPTED
run_expected_failure RAW_HTML ACTIVE_MARKUP_REACHED_SINK
run_expected_failure EVENT_ATTRIBUTE DANGEROUS_ATTRIBUTE_ACCEPTED
run_expected_failure LOOPBACK_ALLOWED LOOPBACK_DESTINATION_ACCEPTED
run_expected_failure REDIRECT_UNCHECKED REDIRECT_BOUNDARY_BYPASSED
run_expected_failure DNS_REBINDING DNS_REBINDING_ACCEPTED

if rg -n '<img|onerror=|SYNTHETIC-CSRF' "$BUILD_DIR/actual.out" >/dev/null; then
    echo "UNTRUSTED_OR_SECRET_MARKER_LEAKED_TO_OUTPUT" >&2
    exit 1
fi
cat "$BUILD_DIR/actual.out"
echo "fault_oracles=6"
