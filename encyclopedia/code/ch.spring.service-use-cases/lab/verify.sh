#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"; MAVEN_VERSION="$(mvn -v 2>&1)"
case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
cd "$ROOT_DIR"; mvn --offline --batch-mode --no-transfer-progress clean test >.verify.log 2>&1
grep -Fq "Tests run: 10, Failures: 0, Errors: 0, Skipped: 0" .verify.log
printf 'acceptance=proxy-transaction,ordered-orchestration,commit,audit-rollback,outbox-rollback,domain-rule,version-conflict tests=10\n'
printf 'LAB PASS spring-framework=7.0.8 spring-boot=4.1.0 jdk=25 mode=offline\n'
