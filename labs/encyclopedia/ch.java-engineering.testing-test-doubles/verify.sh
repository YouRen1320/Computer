#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVIDENCE_DIR="$ROOT_DIR/build-evidence"
MAVEN_VERSION="$(mvn -v 2>&1)"

case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac

rm -rf "$EVIDENCE_DIR" "$ROOT_DIR/target"
mkdir -p "$EVIDENCE_DIR"
cd "$ROOT_DIR"

mvn --offline --batch-mode --no-transfer-progress clean test > "$EVIDENCE_DIR/behavior.log"
grep -Eq 'Tests run: 8, Failures: 0, Errors: 0, Skipped: 0' "$EVIDENCE_DIR/behavior.log"

run_expected_failure() {
    local class_name="$1"
    local log_file="$EVIDENCE_DIR/$2"
    if mvn --offline --batch-mode --no-transfer-progress -Dtest="$class_name" test > "$log_file" 2>&1; then
        echo "EXPECTED FAILURE: $class_name" >&2
        exit 1
    fi
    grep -Fq "$class_name" "$log_file"
}

run_expected_failure OverspecifiedInteractionOrderFault overspecified-order.log
run_expected_failure SharedFixturePollutionFault shared-fixture.log
run_expected_failure MockDatabaseProofFault mock-database.log

printf 'behavior.tests=8 failures=0 errors=0\n'
printf 'faults=overspecified-order,shared-fixture,mock-database-proof expected=failed\n'
printf 'LAB PASS maven=3.9.16 jdk=25 mode=offline\n'
