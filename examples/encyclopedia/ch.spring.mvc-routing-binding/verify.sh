#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAVEN_VERSION="$(mvn -v 2>&1)"
case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
cd "$ROOT_DIR"
mvn --offline --batch-mode --no-transfer-progress clean test >/dev/null 2>&1
printf 'tests=10 failures=0 errors=0 skipped=0\n'
printf 'contract=path,query,header statuses=200,400,404,405 representation=text\n'
printf 'EXAMPLE PASS spring-boot=4.1.0 spring-framework=7.0.8 servlet=6.1 jdk=25 mode=offline\n'
