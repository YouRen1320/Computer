#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVIDENCE_DIR="$ROOT_DIR/build-evidence"
MAVEN_VERSION="$(mvn -v 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"

case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*) ;; *) echo "EXPECTED Maven 3.9.16" >&2; exit 2 ;; esac
case "$MAVEN_VERSION" in *"Java version: 25."*) ;; *) echo "EXPECTED Maven JVM 25" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac

rm -rf "$EVIDENCE_DIR"
mkdir -p "$EVIDENCE_DIR"

cd "$ROOT_DIR"
mvn --offline --batch-mode --no-transfer-progress clean test > "$EVIDENCE_DIR/test.log"
grep -Eq 'Tests run: 2, Failures: 0, Errors: 0, Skipped: 0' "$EVIDENCE_DIR/test.log"

mvn --offline --batch-mode --no-transfer-progress dependency:tree -Dscope=compile > "$EVIDENCE_DIR/compile-tree.log"
if grep -Fq 'org.junit' "$EVIDENCE_DIR/compile-tree.log"; then
    echo "TEST DEPENDENCY LEAKED INTO COMPILE SCOPE" >&2
    exit 1
fi
mvn --offline --batch-mode --no-transfer-progress dependency:tree -Dscope=test > "$EVIDENCE_DIR/test-tree.log"
grep -Fq 'org.junit.jupiter:junit-jupiter:jar:6.1.1:test' "$EVIDENCE_DIR/test-tree.log"

mvn --offline --batch-mode --no-transfer-progress clean package > "$EVIDENCE_DIR/package-1.log"
JAR_PATH="$ROOT_DIR/target/reproducible-order-core-1.0.0-SNAPSHOT.jar"
HASH_ONE="$(shasum -a 256 "$JAR_PATH" | awk '{print $1}')"
jar tf "$JAR_PATH" > "$EVIDENCE_DIR/jar-1.list"
grep -Fqx 'com/factorycare/learning/OrderAmountCalculator.class' "$EVIDENCE_DIR/jar-1.list"
if grep -Fq 'OrderAmountCalculatorTest.class' "$EVIDENCE_DIR/jar-1.list"; then
    echo "TEST CLASS LEAKED INTO MAIN JAR" >&2
    exit 1
fi

mvn --offline --batch-mode --no-transfer-progress clean package > "$EVIDENCE_DIR/package-2.log"
HASH_TWO="$(shasum -a 256 "$JAR_PATH" | awk '{print $1}')"
[[ "$HASH_ONE" == "$HASH_TWO" ]]

printf 'tests=2 failures=0 errors=0 skipped=0\n'
printf 'scope.compile.junit=absent scope.test.junit=6.1.1\n'
printf 'jar.sha256=%s repeated=true\n' "$HASH_ONE"
printf 'EXAMPLE PASS maven=3.9.16 jdk=25 mode=offline\n'
