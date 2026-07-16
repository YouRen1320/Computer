#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED JDK 25, got: $JAVAC_VERSION" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25.x, got: $JAVA_VERSION" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR"/src/*.java
java -cp "$CLASSES_DIR" ReferenceMapLab > "$BUILD_DIR/lab.out"
java -ea -cp "$CLASSES_DIR" ReferenceMapOracle > "$BUILD_DIR/oracle.out"

cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
alias.sameIdentity=true
peer.sameIdentity=false
primary.status=RUNNING
peer.status=IDLE
missing.route=REJECT_MISSING_DEVICE
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/lab.out"
grep -Fqx "assertions=10 passed" "$BUILD_DIR/oracle.out"

set +e
java -cp "$CLASSES_DIR" IdentityMistakeFailure > "$BUILD_DIR/identity.out" 2> "$BUILD_DIR/identity.err"
identity_status=$?
java -cp "$CLASSES_DIR" NullPathFailure > "$BUILD_DIR/null.out" 2> "$BUILD_DIR/null.err"
null_status=$?
set -e
[[ $identity_status -ne 0 ]]
[[ $null_status -ne 0 ]]
grep -Fqx "IDENTITY_MISTAKE sameText=true sameIdentity=false" "$BUILD_DIR/identity.err"
grep -Fq "java.lang.NullPointerException" "$BUILD_DIR/null.err"

cat "$BUILD_DIR/lab.out"
cat "$BUILD_DIR/oracle.out"
echo "EXPECTED_FAILURE IdentityMistakeFailure status=$identity_status evidence=IDENTITY_MISTAKE"
echo "EXPECTED_FAILURE NullPathFailure status=$null_status evidence=NullPointerException"
echo "LAB PASS assertions=10 expected_failures=2 java=$JAVA_VERSION"
