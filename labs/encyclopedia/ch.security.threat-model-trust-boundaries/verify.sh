#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
MODEL="$ROOT_DIR/fixtures/model.tsv"
FAULTS="$ROOT_DIR/fixtures/faults.tsv"

case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/ThreatModelLab.java"
java -cp "$BUILD_DIR/classes" ThreatModelLab "$MODEL" "$FAULTS" none > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"

run_expected_failure() {
    local fault_id="$1"
    local marker="$2"
    local output="$BUILD_DIR/$fault_id.out"
    if java -cp "$BUILD_DIR/classes" ThreatModelLab "$MODEL" "$FAULTS" "$fault_id" > "$output" 2>&1; then
        echo "EXPECTED FAILURE: $fault_id" >&2
        exit 1
    fi
    grep -Fq "$marker" "$output"
}

run_expected_failure missing-admin 'first=ACTOR_MISSING:ADMIN'
run_expected_failure missing-boundary 'first=BOUNDARY_MISSING:F_CREATE_REQUEST'
run_expected_failure orphan-control 'first=ORPHAN_CONTROL:C_WAF'
run_expected_failure missing-validation 'first=VALIDATION_LINK_INVALID:T_ELEVATE'

cat "$BUILD_DIR/actual.out"
echo "fault_oracles=4"
