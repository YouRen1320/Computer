#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"

case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/SessionAuthenticationLab.java"
java -cp "$BUILD_DIR/classes" SessionAuthenticationLab > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"

run_expected_failure() {
    local mode="$1"
    local marker="$2"
    local output="$BUILD_DIR/$mode.out"
    if java -cp "$BUILD_DIR/classes" SessionAuthenticationLab "$mode" > "$output" 2>&1; then
        echo "EXPECTED FAILURE: $mode" >&2
        exit 1
    fi
    grep -Fq "$marker" "$output"
}

run_expected_failure NOOP_PASSWORD NOOP_PASSWORD_ACCEPTED
run_expected_failure RESET_REPLAY RESET_TOKEN_REPLAYED
run_expected_failure OLD_SESSION_AFTER_PASSWORD_CHANGE OLD_SESSION_AFTER_PASSWORD_CHANGE
run_expected_failure FIXATION_REUSE SESSION_FIXATION_REUSED_ID
run_expected_failure ACCOUNT_ENUMERATION ACCOUNT_ENUMERATION_VISIBLE
run_expected_failure LOGOUT_CLIENT_ONLY LOGOUT_SERVER_STATE_STILL_VALID
run_expected_failure CONCURRENT_LIMIT_BROKEN CONCURRENT_SESSION_LIMIT_BROKEN

if rg -n 'SYNTHETIC-.*SESSION|SALT-A' "$BUILD_DIR/actual.out" >/dev/null; then
    echo "AUTHENTICATION_MATERIAL_LEAKED_TO_OUTPUT" >&2
    exit 1
fi
cat "$BUILD_DIR/actual.out"
echo "fault_oracles=7"
