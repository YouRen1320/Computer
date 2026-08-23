#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"; cd "$ROOT_DIR"
case "$(mvn -v 2>&1)" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
mvn --offline --batch-mode --no-transfer-progress clean test >.verify.log 2>&1
grep -Fq "Tests run: 10, Failures: 0, Errors: 0, Skipped: 0" .verify.log
printf 'acceptance=generated-parse,examples,runtime-success,problem,baseline-diff tests=10\n'
printf 'LAB PASS boot=4.1.0 springdoc=3.0.3 mode=offline\n'
