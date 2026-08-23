#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"; cd "$ROOT_DIR"
case "$(mvn -v 2>&1)" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
mvn --offline --batch-mode --no-transfer-progress clean test >.verify.log 2>&1
grep -Fq "Tests run: 8, Failures: 0, Errors: 0, Skipped: 0" .verify.log
printf 'acceptance=proxy,atomic-two-table-commit,runtime-rollback,after-commit,target-bypass tests=8\n'
printf 'EXAMPLE PASS spring-framework=7.0.8 boot=4.1.0 database=h2-boundary mode=offline\n'
