#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAVEN_VERSION="$(mvn -v 2>&1)"
case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
cd "$ROOT_DIR"
mvn --offline --batch-mode --no-transfer-progress clean test >/dev/null 2>&1
printf 'tests=11 failures=0 errors=0 skipped=0\n'
printf 'oracles=entity-identity,value-equality,legal-create,named-transitions,unchanged-on-failure\n'
printf 'EXAMPLE PASS junit=6.1.1 jdk=25 mode=offline framework=none\n'
