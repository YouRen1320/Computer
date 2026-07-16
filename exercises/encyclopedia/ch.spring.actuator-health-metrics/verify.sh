#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"; cd "$ROOT_DIR"
case "$(mvn -v 2>&1)" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
set +e; mvn --offline --batch-mode --no-transfer-progress clean test >.verify.log 2>&1; STATUS=$?; set -e
if [[ $STATUS -eq 0 ]]; then grep -Fq "Tests run: 2, Failures: 0, Errors: 0, Skipped: 0" .verify.log; printf 'EXERCISE PASS tests=2 liveness-independent=true mode=offline\n'; else grep -Fq "Tests run: 2, Failures: 1, Errors: 0, Skipped: 0" .verify.log; grep -Fq "EXPECTED_LIVENESS_INDEPENDENT_FROM_DATABASE" .verify.log; printf 'STARTER EXPECTED FAILURE tests=2 failures=1 sentinel=EXPECTED_LIVENESS_INDEPENDENT_FROM_DATABASE mode=offline\n'; fi
