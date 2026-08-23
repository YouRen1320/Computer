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
java -cp "$CLASSES_DIR" ReferenceIdentityDemo > "$BUILD_DIR/demo.out"

cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
alias.sameIdentity=true
sameState.sameIdentity=false
sameState.sameFields=true
primary.statusAfterAliasWrite=RUNNING
missing.isNull=true
missing.label=<missing>
text.sameIdentity=false
text.sameContent=true
text.missing=true
text.empty=true
text.blank=true
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

set +e
java -cp "$CLASSES_DIR" NullDereferenceFailure > "$BUILD_DIR/null.out" 2> "$BUILD_DIR/null.err"
null_status=$?
set -e
if [[ $null_status -eq 0 ]]; then echo "EXPECTED FAILURE: null dereference exited 0" >&2; exit 1; fi
grep -Fq "java.lang.NullPointerException" "$BUILD_DIR/null.err"
grep -Fq "NullDereferenceFailure.java" "$BUILD_DIR/null.err"

cat "$BUILD_DIR/demo.out"
echo "EXPECTED_FAILURE NullDereferenceFailure status=$null_status evidence=NullPointerException"
echo "EXAMPLE PASS lines=11 javac=$JAVAC_VERSION java=$JAVA_VERSION"
