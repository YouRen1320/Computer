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
mkdir -p "$CLASSES_DIR" "$BUILD_DIR/failure-classes"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/MethodContractLab.java" "$ROOT_DIR/src/MethodContractOracle.java" "$ROOT_DIR/failures/RecursionWithoutBaseFailure.java"
java -cp "$CLASSES_DIR" MethodContractLab > "$BUILD_DIR/lab.out"
java -ea -cp "$CLASSES_DIR" MethodContractOracle > "$BUILD_DIR/oracle.out"

expected=$'total.zero=0 one=1999 three=5997\nremaining.correct=7 swapped=-7\nclassify.0=INVALID classify.4=URGENT\nlabel.simple=T-7\nlabel.status=T-7:ASSIGNED\npass.value.before=3 after=3\npass.array.element=5\npass.reassign.element=5\ncountdown.0=0\ncountdown.1=1\ncountdown.4=4'
[[ "$(cat "$BUILD_DIR/lab.out")" == "$expected" ]]
grep -Fqx "assertions=18 passed" "$BUILD_DIR/oracle.out"

run_compile_failure() {
  local class_name="$1" expected_detail="$2"
  local source="$ROOT_DIR/failures/$class_name.java"
  set +e
  javac -J-Duser.language=en -J-Duser.country=US --release 25 \
    -d "$BUILD_DIR/failure-classes" "$source" \
    > "$BUILD_DIR/$class_name.out" 2> "$BUILD_DIR/$class_name.err"
  local status=$?
  set -e
  if [[ $status -eq 0 ]]; then echo "EXPECTED COMPILE FAILURE: $class_name compiled" >&2; exit 1; fi
  grep -Fq "$expected_detail" "$BUILD_DIR/$class_name.err"
  echo "EXPECTED_COMPILE_FAILURE $class_name status=$status evidence=$expected_detail"
}

cat "$BUILD_DIR/lab.out"
cat "$BUILD_DIR/oracle.out"
run_compile_failure MissingReturnFailure "missing return statement"
run_compile_failure ScopeFailure "cannot find symbol"
run_compile_failure AmbiguousOverloadFailure "reference to route is ambiguous"

set +e
java -Xss256k -cp "$CLASSES_DIR" RecursionWithoutBaseFailure > "$BUILD_DIR/recursion.out" 2> "$BUILD_DIR/recursion.err"
recursion_status=$?
set -e
if [[ $recursion_status -eq 0 ]]; then echo "EXPECTED RUNTIME FAILURE: recursion-without-base exited 0" >&2; exit 1; fi
grep -Fq "StackOverflowError" "$BUILD_DIR/recursion.err"
grep -Fq "RecursionWithoutBaseFailure.countdown" "$BUILD_DIR/recursion.err"
echo "EXPECTED_RUNTIME_FAILURE RecursionWithoutBaseFailure status=$recursion_status evidence=StackOverflowError"
echo "LAB PASS methods=deterministic pass-by-value=verified recursion=0-1-4 assertions=18 java=$JAVA_VERSION"
