#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$ROOT_DIR/.verify.log"
SENTINEL="EXPECTED_LIVENESS_INDEPENDENT_FROM_DATABASE"
EXPECTED_TESTS=2

case "$(mvn -v 2>&1)" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
cd "$ROOT_DIR"
rm -f "$LOG_FILE"
set +e
mvn --offline --batch-mode --no-transfer-progress clean test >"$LOG_FILE" 2>&1
STATUS=$?
set -e

if [[ $STATUS -eq 0 ]]; then
  echo "STARTER UNEXPECTEDLY PASSED sentinel=$SENTINEL" >&2
  exit 42
fi
if [[ $STATUS -ne 1 ]] || ! grep -Fq "Tests run: $EXPECTED_TESTS, Failures: 1, Errors: 0, Skipped: 0" "$LOG_FILE"; then
  cat "$LOG_FILE" >&2
  echo "STARTER FAILURE SHAPE MISMATCH expected=tests:$EXPECTED_TESTS/failures:1/errors:0/skipped:0 actual_exit=$STATUS" >&2
  exit 43
fi
if ! grep -Fq "$SENTINEL" "$LOG_FILE"; then
  cat "$LOG_FILE" >&2
  echo "STARTER FAILURE MARKER MISMATCH expected=$SENTINEL" >&2
  exit 44
fi
echo "EXPECTED_RED first=$SENTINEL tests=$EXPECTED_TESTS failures=1 errors=0 skipped=0 mode=offline"
exit 41
