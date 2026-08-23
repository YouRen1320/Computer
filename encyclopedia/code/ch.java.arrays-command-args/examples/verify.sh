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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/ArrayCommandDemo.java" "$ROOT_DIR/failures/LengthAsLastIndexFailure.java"
java -cp "$CLASSES_DIR" ArrayCommandDemo > "$BUILD_DIR/no-args.out"
java -cp "$CLASSES_DIR" ArrayCommandDemo HIGH LOW > "$BUILD_DIR/two-args.out"

expected_no_args=$'length=3\nindex=0 value=3\nindex=1 value=4\nindex=2 value=2\nsummary.max=4 foundIndex=1 urgent=1\nmatrix.rows=3 lengths=2,1,0\nmatrix.value=A02\nargs.count=0\nargs.values=EMPTY'
expected_two_args=$'length=3\nindex=0 value=3\nindex=1 value=4\nindex=2 value=2\nsummary.max=4 foundIndex=1 urgent=1\nmatrix.rows=3 lengths=2,1,0\nmatrix.value=A02\nargs.count=2\nargs[0]=HIGH\nargs[1]=LOW'
[[ "$(cat "$BUILD_DIR/no-args.out")" == "$expected_no_args" ]]
[[ "$(cat "$BUILD_DIR/two-args.out")" == "$expected_two_args" ]]

set +e
java -cp "$CLASSES_DIR" LengthAsLastIndexFailure > "$BUILD_DIR/last-index.out" 2> "$BUILD_DIR/last-index.err"
failure_status=$?
set -e
if [[ $failure_status -eq 0 ]]; then echo "EXPECTED FAILURE: length-as-index exited 0" >&2; exit 1; fi
grep -Fq "ArrayIndexOutOfBoundsException" "$BUILD_DIR/last-index.err"
grep -Fq "Index 3 out of bounds for length 3" "$BUILD_DIR/last-index.err"

cat "$BUILD_DIR/no-args.out"
echo "--- args=HIGH LOW ---"
cat "$BUILD_DIR/two-args.out"
echo "EXPECTED_FAILURE LengthAsLastIndexFailure status=$failure_status evidence=index-3-length-3"
echo "EXAMPLES PASS javac=$JAVAC_VERSION java=$JAVA_VERSION"
