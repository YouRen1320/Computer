#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVIDENCE_DIR="$ROOT_DIR/build-evidence"
MAVEN_VERSION="$(mvn -v 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"

case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac

rm -rf "$EVIDENCE_DIR" "$ROOT_DIR/target"
mkdir -p "$EVIDENCE_DIR"
cd "$ROOT_DIR"

mvn --offline --batch-mode --no-transfer-progress clean test > "$EVIDENCE_DIR/test.log"
grep -Eq 'Tests run: 6, Failures: 0, Errors: 0, Skipped: 0' "$EVIDENCE_DIR/test.log"

mvn --offline --batch-mode --no-transfer-progress dependency:tree -Dscope=compile > "$EVIDENCE_DIR/compile-tree.log"
if grep -Eq 'org\.(junit|mockito)' "$EVIDENCE_DIR/compile-tree.log"; then
    echo "TEST LIBRARY LEAKED INTO COMPILE SCOPE" >&2
    exit 1
fi

printf 'tests=6 failures=0 errors=0 skipped=0\n'
printf 'doubles=stub,fake,mock boundary=external-collaborators\n'
printf 'EXAMPLE PASS maven=3.9.16 jdk=25 mode=offline\n'
