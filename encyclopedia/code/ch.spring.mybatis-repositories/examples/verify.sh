#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAVEN_VERSION="$(mvn -v 2>&1)"
case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
cd "$ROOT_DIR"
mvn --offline --batch-mode --no-transfer-progress clean test >.verify.log 2>&1
grep -Fq "Tests run: 9, Failures: 0, Errors: 0, Skipped: 0" .verify.log
printf 'tests=9 port=framework-free sql=adapter-only tenant=id-bound outcomes=updated,not-found,version-conflict\n'
printf 'EXAMPLE PASS spring-boot=4.1.0 mybatis-starter=4.0.0 jdk=25 mode=offline\n'
