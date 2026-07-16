#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"; MAVEN_VERSION="$(mvn -v 2>&1)"; case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
cd "$ROOT_DIR"; set +e; mvn --offline --batch-mode --no-transfer-progress clean test >.verify.log 2>&1; STATUS=$?; set -e
if [[ $STATUS -eq 0 ]]; then grep -Fq "Tests run: 2, Failures: 0, Errors: 0, Skipped: 0" .verify.log; printf 'EXERCISE PASS tests=2 orchestration=load,domain.assign,save mode=offline\n'; else grep -Fq "Tests run: 2, Failures: 1, Errors: 0, Skipped: 0" .verify.log; grep -Fq "EXPECTED_USE_CASE_ORCHESTRATION" .verify.log; printf 'STARTER EXPECTED FAILURE tests=2 failures=1 sentinel=EXPECTED_USE_CASE_ORCHESTRATION mode=offline\n'; fi
