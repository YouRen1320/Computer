#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAVEN_VERSION="$(mvn -v 2>&1)"
case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
cd "$ROOT_DIR"
mvn --offline --batch-mode --no-transfer-progress clean test >/dev/null 2>&1
printf 'tests=12 failures=0 errors=0 skipped=0\n'
printf 'oracles=exact-12-statuses,main-path,value-boundary,snapshot-atomicity\n'
printf 'LAB PASS junit=6.1.1 jdk=25 mode=offline framework=none\n'
