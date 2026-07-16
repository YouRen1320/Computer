#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVIDENCE_DIR="$ROOT_DIR/build-evidence"
MAVEN_VERSION="$(mvn -v 2>&1)"
case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac

rm -rf "$EVIDENCE_DIR"
mkdir -p "$EVIDENCE_DIR"
cd "$ROOT_DIR"

grep -Fqx 'distributionUrl=https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/3.9.16/apache-maven-3.9.16-bin.zip' .mvn/wrapper/maven-wrapper.properties
grep -Eq '^distributionSha256Sum=[0-9a-f]{64}$' .mvn/wrapper/maven-wrapper.properties

mvn --offline --batch-mode --no-transfer-progress clean test > "$EVIDENCE_DIR/test.log"
grep -Eq 'Tests run: 3, Failures: 0, Errors: 0, Skipped: 0' "$EVIDENCE_DIR/test.log"

mvn --offline --batch-mode --no-transfer-progress dependency:tree -Dscope=compile > "$EVIDENCE_DIR/compile-tree.log"
if grep -Fq 'org.junit' "$EVIDENCE_DIR/compile-tree.log"; then
    echo "JUnit leaked into compile scope" >&2
    exit 1
fi
mvn --offline --batch-mode --no-transfer-progress dependency:tree -Dscope=test > "$EVIDENCE_DIR/test-tree.log"
grep -Fq 'org.junit.jupiter:junit-jupiter-engine:jar:6.1.1:test' "$EVIDENCE_DIR/test-tree.log"

mvn --offline --batch-mode --no-transfer-progress clean package > "$EVIDENCE_DIR/package-1.log"
JAR_PATH="$ROOT_DIR/target/work-order-build-lab-1.0.0-SNAPSHOT.jar"
HASH_ONE="$(shasum -a 256 "$JAR_PATH" | awk '{print $1}')"
jar tf "$JAR_PATH" > "$EVIDENCE_DIR/jar.list"
grep -Fqx 'com/factorycare/learning/WorkOrderCost.class' "$EVIDENCE_DIR/jar.list"
if grep -Fq 'WorkOrderCostTest.class' "$EVIDENCE_DIR/jar.list"; then
    echo "test class leaked into jar" >&2
    exit 1
fi
mvn --offline --batch-mode --no-transfer-progress clean package > "$EVIDENCE_DIR/package-2.log"
HASH_TWO="$(shasum -a 256 "$JAR_PATH" | awk '{print $1}')"
[[ "$HASH_ONE" == "$HASH_TWO" ]]

mvn --offline --batch-mode --no-transfer-progress -f faults/scope-leak/pom.xml dependency:tree -Dscope=compile > "$EVIDENCE_DIR/fault-scope-tree.log"
grep -Fq 'org.junit.jupiter:junit-jupiter-api:jar:6.1.1:compile' "$EVIDENCE_DIR/fault-scope-tree.log"

printf 'tests=3 failures=0 errors=0 skipped=0\n'
printf 'main.scope.junit=absent fault.scope.junit=compile\n'
printf 'jar.sha256=%s repeated=true\n' "$HASH_ONE"
printf 'LAB PASS maven=3.9.16 jdk=25 mode=offline\n'
