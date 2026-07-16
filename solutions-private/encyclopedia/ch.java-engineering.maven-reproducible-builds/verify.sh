#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVIDENCE_DIR="$ROOT_DIR/build-evidence"
MAVEN_VERSION="$(mvn -v 2>&1)"
case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
rm -rf "$EVIDENCE_DIR"
mkdir -p "$EVIDENCE_DIR"
cd "$ROOT_DIR"
mvn --offline --batch-mode --no-transfer-progress clean test > "$EVIDENCE_DIR/test.log"
grep -Eq 'Tests run: 2, Failures: 0, Errors: 0, Skipped: 0' "$EVIDENCE_DIR/test.log"
mvn --offline --batch-mode --no-transfer-progress dependency:tree -Dscope=compile > "$EVIDENCE_DIR/compile-tree.log"
if grep -Fq 'org.junit' "$EVIDENCE_DIR/compile-tree.log"; then echo "JUnit scope leak" >&2; exit 1; fi
mvn --offline --batch-mode --no-transfer-progress clean package > "$EVIDENCE_DIR/package-1.log"
JAR="$ROOT_DIR/target/maven-contract-challenge-1.0.0-SNAPSHOT.jar"
HASH_ONE="$(shasum -a 256 "$JAR" | awk '{print $1}')"
jar tf "$JAR" > "$EVIDENCE_DIR/jar.list"
if grep -Fq 'DowntimeCostTest.class' "$EVIDENCE_DIR/jar.list"; then echo "test class leak" >&2; exit 1; fi
mvn --offline --batch-mode --no-transfer-progress clean package > "$EVIDENCE_DIR/package-2.log"
HASH_TWO="$(shasum -a 256 "$JAR" | awk '{print $1}')"
[[ "$HASH_ONE" == "$HASH_TWO" ]]
printf 'PRIVATE SOLUTION PASS tests=2 repeated_sha256=%s offline=true\n' "$HASH_ONE"
