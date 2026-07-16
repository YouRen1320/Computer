#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$ROOT_DIR/.verify.log"
MAVEN_VERSION="$(mvn -v 2>&1)"
case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
cd "$ROOT_DIR"
set +e
mvn --offline --batch-mode --no-transfer-progress clean test >"$LOG_FILE" 2>&1
STATUS=$?
set -e
if [ "$STATUS" -eq 0 ]; then
  printf 'tests=2 failures=0 errors=0 skipped=0 state=completed\n'
  printf 'EXERCISE PASS sentinel=EXPECTED_VALIDATION_BEFORE_USE_CASE mode=offline\n'
  exit 0
fi
grep -q 'Tests run: 2, Failures: 1, Errors: 0, Skipped: 0' "$LOG_FILE"
grep -q 'EXPECTED_VALIDATION_BEFORE_USE_CASE' "$LOG_FILE"
printf 'tests=2 failures=1 errors=0 skipped=0 state=expected-red\n'
printf 'EXERCISE PASS sentinel=EXPECTED_VALIDATION_BEFORE_USE_CASE mode=offline\n'
