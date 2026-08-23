#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAVEN_VERSION="$(mvn -v 2>&1)"
case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
cd "$ROOT_DIR"
mvn --offline --batch-mode --no-transfer-progress clean test >.verify.log 2>&1
grep -Fq "Tests run: 8, Failures: 0, Errors: 0, Skipped: 0" .verify.log
printf 'tests=8 failures=0 errors=0 active-after=0 exhaustion=bounded migration-before-traffic readiness=down-false\n'
printf 'EXAMPLE PASS spring-boot=4.1.0 pool=HikariCP jdk=25 mode=offline\n'
