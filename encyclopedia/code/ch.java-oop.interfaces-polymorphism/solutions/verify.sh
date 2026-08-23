#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
FAILURE_CLASSES="$BUILD_DIR/failure-classes"
JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED JDK 25, got: $JAVAC_VERSION" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25.x, got: $JAVA_VERSION" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR" "$FAILURE_CLASSES" "$BUILD_DIR/failure-src"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/NotificationPolymorphismSolution.java"
java -cp "$CLASSES_DIR" NotificationPolymorphismSolution > "$BUILD_DIR/solution.out"
grep -Fqx "solution.assertions=12 passed" "$BUILD_DIR/solution.out"

cp "$ROOT_DIR/failures/MissingMethodFailure.java.txt" "$BUILD_DIR/failure-src/MissingMethodFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$FAILURE_CLASSES" "$BUILD_DIR/failure-src/MissingMethodFailure.java" > "$BUILD_DIR/missing.out" 2> "$BUILD_DIR/missing.err"
missing_status=$?
javac --release 25 -d "$FAILURE_CLASSES" "$ROOT_DIR/failures/WrongCastFailure.java" > "$BUILD_DIR/cast-compile.out" 2> "$BUILD_DIR/cast-compile.err"
cast_compile_status=$?
java -cp "$FAILURE_CLASSES" WrongCastFailure > "$BUILD_DIR/cast.out" 2> "$BUILD_DIR/cast.err"
cast_status=$?
set -e
[[ $missing_status -ne 0 ]]
[[ $cast_compile_status -eq 0 ]]
[[ $cast_status -eq 10 ]]
grep -Fq "compiler.err.does.not.override.abstract" "$BUILD_DIR/missing.err"
grep -Fqx "SOLUTION_WRONG_CAST actual=EmailSender target=SmsSender exception=ClassCastException" "$BUILD_DIR/cast.err"

cat "$BUILD_DIR/solution.out"
echo "EXPECTED_COMPILE_FAILURE MissingMethodFailure status=$missing_status evidence=interface-method"
echo "EXPECTED_FAILURE WrongCastFailure status=$cast_status evidence=ClassCastException"
echo "SOLUTION PASS assertions=12 expected_failures=2 java=$JAVA_VERSION"
