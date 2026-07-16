#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"; cd "$ROOT_DIR"
case "$(mvn -v 2>&1)" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
mvn --offline --batch-mode --no-transfer-progress clean test >.verify.log 2>&1
grep -Fq "Tests run: 10, Failures: 0, Errors: 0, Skipped: 0" .verify.log
printf 'acceptance=liveness,readiness,dependency-down,security,env-hidden,bounded-meter tests=10\n'
printf 'LAB PASS boot=4.1.0 micrometer=1.17.0 database=fake-boundary mode=offline\n'
