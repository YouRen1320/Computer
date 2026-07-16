#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"

case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/IdentityLifecycleLab.java"
java -cp "$BUILD_DIR/classes" IdentityLifecycleLab > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"

run_expected_failure() {
    local fault_mode="$1"
    local marker="$2"
    local output="$BUILD_DIR/$fault_mode.out"
    if java -cp "$BUILD_DIR/classes" IdentityLifecycleLab "$fault_mode" > "$output" 2>&1; then
        echo "EXPECTED FAILURE: $fault_mode" >&2
        exit 1
    fi
    grep -Fq "$marker" "$output"
}

run_expected_failure UNSAFE_STORAGE PASSWORD_STORAGE_UNSAFE
run_expected_failure FIXED_SALT SALT_REUSE_DETECTED
run_expected_failure REPLAY_RESET RESET_TOKEN_REPLAY_ACCEPTED
run_expected_failure OLD_SESSION_SURVIVES OLD_SESSION_STILL_VALID

if rg -n 'SYNTHETIC-(OLD|NEW|WRONG)-PASSPHRASE|SYNTHETIC-ONE-TIME-TOKEN|SYNTHETIC_TRAINING_PEPPER' "$BUILD_DIR/actual.out" >/dev/null; then
    echo "SYNTHETIC_SECRET_LEAKED_TO_OUTPUT" >&2
    exit 1
fi
cat "$BUILD_DIR/actual.out"
echo "fault_oracles=4"
