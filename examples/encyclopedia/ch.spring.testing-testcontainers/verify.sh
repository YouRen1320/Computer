#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
case "$(mvn -v 2>&1)" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
cd "$ROOT_DIR"
mvn --offline --batch-mode --no-transfer-progress clean test >.verify.log 2>&1
grep -Fq "Tests run: 8, Failures: 0, Errors: 0, Skipped: 0" .verify.log
printf 'oracles=controller-http,repository-sql,context-bean-graph tests=8\n'
printf 'EXAMPLE PASS spring=7.0.8 boot=4.1.0 database=h2-boundary-only mode=offline\n'
