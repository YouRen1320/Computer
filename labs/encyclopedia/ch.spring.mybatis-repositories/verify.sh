#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAVEN_VERSION="$(mvn -v 2>&1)"
case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
cd "$ROOT_DIR"
mvn --offline --batch-mode --no-transfer-progress clean test >.verify.log 2>&1
grep -Fq "Tests run: 11, Failures: 0, Errors: 0, Skipped: 0" .verify.log
printf 'acceptance=exists,missing,tenant-isolation,save,zero-row-conflict,zero-row-not-found,adapter-sql,domain-clean,upper-transaction tests=11\n'
printf 'LAB PASS spring-boot=4.1.0 mybatis-starter=4.0.0 jdk=25 mode=offline\n'
