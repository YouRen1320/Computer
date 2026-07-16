#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C LANG=C

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED JDK 25, got: $JAVAC_VERSION" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25.x, got: $JAVA_VERSION" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/MethodsDemo.java" "$ROOT_DIR/failures/RecursiveWithoutBase.java"
java -cp "$CLASSES_DIR" MethodsDemo > "$BUILD_DIR/demo.out"
expected=$'total.zero=0\ntotal.multiple=5997\npriority.3=NORMAL\npriority.5=URGENT\nlabel.simple=T-7\nlabel.status=T-7:ASSIGNED\nvalue.caller=3\narray.element=5\narray.afterReassign=5\ncountdown.0=0\ncountdown.1=1\ncountdown.4=4'
[[ "$(cat "$BUILD_DIR/demo.out")" == "$expected" ]]

set +e
java -Xss256k -cp "$CLASSES_DIR" RecursiveWithoutBase > "$BUILD_DIR/recursive.out" 2> "$BUILD_DIR/recursive.err"
failure_status=$?
set -e
if [[ $failure_status -eq 0 ]]; then echo "EXPECTED FAILURE: recursion-without-base exited 0" >&2; exit 1; fi
grep -Fq "StackOverflowError" "$BUILD_DIR/recursive.err"
grep -Fq "RecursiveWithoutBase.countdown" "$BUILD_DIR/recursive.err"

cat "$BUILD_DIR/demo.out"
echo "EXPECTED_FAILURE RecursiveWithoutBase status=$failure_status evidence=StackOverflowError"
echo "EXAMPLES PASS methods=contracts-and-recursion javac=$JAVAC_VERSION java=$JAVA_VERSION"
