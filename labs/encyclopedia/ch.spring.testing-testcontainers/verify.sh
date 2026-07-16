#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
case "$(mvn -v 2>&1)" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
docker info >/dev/null 2>&1 || { echo 'EXPECTED_DOCKER_DAEMON_FOR_REAL_POSTGRESQL' >&2; exit 3; }
cd "$ROOT_DIR"
mvn --offline --batch-mode --no-transfer-progress clean test >.verify.log 2>&1
grep -Fq "Tests run: 8, Failures: 0, Errors: 0, Skipped: 0" .verify.log
printf 'acceptance=postgresql18,flyway,tenant-sql,optimistic-lock,shared-static-container,context-wiring tests=8\n'
printf 'LAB PASS boot=4.1.0 testcontainers=2.0.5 postgresql=18 mode=maven-offline\n'
