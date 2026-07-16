#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$ROOT_DIR/.verify.log"
MAVEN_VERSION="$(mvn -v 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"

case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac

cd "$ROOT_DIR"
rm -f "$LOG_FILE"
set +e
mvn --offline --batch-mode --no-transfer-progress clean test >"$LOG_FILE" 2>&1
STATUS=$?
set -e

if [ "$STATUS" -eq 0 ]; then
    rm -f "$LOG_FILE"
    printf 'tests=3 failures=0 errors=0 skipped=0\n'
    printf 'EXERCISE PASS state=completed maven=3.9.16 jdk=25 mode=offline\n'
    exit 0
fi

if grep -Rqs 'EXPECTED_EXPLICIT_CONSTRUCTOR_GRAPH' "$ROOT_DIR/target/surefire-reports" "$LOG_FILE"; then
    rm -f "$LOG_FILE"
    printf 'sentinel=EXPECTED_EXPLICIT_CONSTRUCTOR_GRAPH\n'
    printf 'EXERCISE PASS state=expected-red maven=3.9.16 jdk=25 mode=offline\n'
    exit 0
fi

cat "$LOG_FILE" >&2
rm -f "$LOG_FILE"
echo "UNEXPECTED EXERCISE FAILURE" >&2
exit "$STATUS"
