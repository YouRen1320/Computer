#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVIDENCE_DIR="$ROOT_DIR/build-evidence"
MAVEN_VERSION="$(mvn -v 2>&1)"
case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac

rm -rf "$EVIDENCE_DIR" "$ROOT_DIR/target"
mkdir -p "$EVIDENCE_DIR"
cd "$ROOT_DIR"

mvn --offline --batch-mode --no-transfer-progress clean test > "$EVIDENCE_DIR/test.log"
grep -Eq 'Tests run: 5, Failures: 0, Errors: 0, Skipped: 0' "$EVIDENCE_DIR/test.log"

if rg -n 'TODO' src >/dev/null; then
    echo "SOLUTION STILL CONTAINS TODO" >&2
    exit 1
fi

printf 'tests=5 failures=0 errors=0 skipped=0\n'
printf 'solution=fake-instance-state,spy-captured-message\n'
printf 'SOLUTION PASS maven=3.9.16 jdk=25 mode=offline\n'
