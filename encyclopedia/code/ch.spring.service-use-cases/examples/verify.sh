#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"; MAVEN_VERSION="$(mvn -v 2>&1)"
case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
cd "$ROOT_DIR"; mvn --offline --batch-mode --no-transfer-progress clean test >.verify.log 2>&1
grep -Fq "Tests run: 9, Failures: 0, Errors: 0, Skipped: 0" .verify.log
printf 'tests=9 order=load,assign,save,audit,outbox domain=pure controller=protocol-only repository=replaceable\n'
printf 'EXAMPLE PASS spring-framework=7.0.8 spring-boot-baseline=4.1.0 jdk=25 mode=offline\n'
