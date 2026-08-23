#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
MAVEN_LOG="$TMP_DIR/maven.log"
case "$(mvn -v 2>&1)" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
cd "$ROOT_DIR"
if ! docker info >/dev/null 2>&1; then
  mvn --offline --batch-mode --no-transfer-progress -DskipTests package >"$MAVEN_LOG" 2>&1
  grep -Fq '<artifactId>postgresql</artifactId>' pom.xml
  grep -Rqs '@Container' src/test
  grep -Rqs 'postgres:18' src/test
  printf 'LAB STATIC PASS contract=postgresql18,testcontainers-container,offline-compile\n'
  printf 'UNVERIFIED real Docker daemon, PostgreSQL startup, Flyway migration, tenant SQL, optimistic locking and Spring context wiring\n'
  exit 0
fi
mvn --offline --batch-mode --no-transfer-progress clean test >"$MAVEN_LOG" 2>&1
grep -Fq "Tests run: 8, Failures: 0, Errors: 0, Skipped: 0" "$MAVEN_LOG"
printf 'acceptance=postgresql18,flyway,tenant-sql,optimistic-lock,shared-static-container,context-wiring tests=8\n'
printf 'LAB PASS boot=4.1.0 testcontainers=2.0.5 postgresql=18 mode=maven-offline\n'
