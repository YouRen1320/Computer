#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVIDENCE_DIR="$ROOT_DIR/build-evidence"
MAVEN_VERSION="$(mvn -v 2>&1)"
case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac

rm -rf "$EVIDENCE_DIR" "$ROOT_DIR/target"
mkdir -p "$EVIDENCE_DIR"
cd "$ROOT_DIR"

if mvn --offline --batch-mode --no-transfer-progress clean test > "$EVIDENCE_DIR/starter.log" 2>&1; then
    echo "STARTER UNEXPECTEDLY PASSED: complete-state students should run mvn test directly" >&2
    exit 1
fi

grep -Fq 'NotificationChallengeTest' "$EVIDENCE_DIR/starter.log"
grep -Fq 'TODO implement in-memory save' \
    "$ROOT_DIR/src/test/java/factorycare/challenge/NotificationChallengeTest.java"
grep -Fq 'TODO capture the business message' \
    "$ROOT_DIR/src/test/java/factorycare/challenge/NotificationChallengeTest.java"

printf 'EXPECTED_RED starter=expected-failure todos=fake-save,spy-capture\n'
printf 'EXERCISE READY maven=3.9.16 jdk=25 mode=offline\n'
exit 41
