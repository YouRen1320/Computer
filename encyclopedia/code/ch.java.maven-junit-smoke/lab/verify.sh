#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C LANG=C MAVEN_OPTS="-Dfile.encoding=UTF-8 -Duser.language=en -Duser.country=US"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
WORK_DIR="$BUILD_DIR/work"
MAVEN_VERSION="$(mvn -v)"
case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

reset_work() {
  rm -rf "$WORK_DIR"
  cp -R "$ROOT_DIR/project" "$WORK_DIR"
}
run_maven() {
  local log="$1"
  set +e
  (cd "$WORK_DIR" && mvn --offline --batch-mode --no-transfer-progress -Dstyle.color=never clean test) > "$BUILD_DIR/$log" 2>&1
  local status=$?
  set -e
  return $status
}

reset_work
run_maven green.log
grep -Fq "Tests run: 2, Failures: 0, Errors: 0, Skipped: 0" "$BUILD_DIR/green.log"
grep -Fq "BUILD SUCCESS" "$BUILD_DIR/green.log"

reset_work
cp "$ROOT_DIR/faults/MissingSemicolon.java.txt" "$WORK_DIR/src/main/java/com/factorycare/learning/OrderAmountCalculator.java"
if run_maven compile.log; then echo "EXPECTED compile failure" >&2; exit 1; fi
grep -Fq "compiler:3.15.0:compile" "$BUILD_DIR/compile.log"
grep -Fq "Compilation failure" "$BUILD_DIR/compile.log"
if grep -Fq " T E S T S" "$BUILD_DIR/compile.log"; then echo "compile failure must not run tests" >&2; exit 1; fi

reset_work
cp "$ROOT_DIR/faults/WrongPackageTest.java.txt" "$WORK_DIR/src/test/java/com/factorycare/learning/OrderAmountCalculatorTest.java"
if run_maven test-compile.log; then echo "EXPECTED testCompile failure" >&2; exit 1; fi
grep -Fq "compiler:3.15.0:testCompile" "$BUILD_DIR/test-compile.log"
grep -Fq "cannot find symbol" "$BUILD_DIR/test-compile.log"
if grep -Fq " T E S T S" "$BUILD_DIR/test-compile.log"; then echo "testCompile failure must not run tests" >&2; exit 1; fi

reset_work
cp "$ROOT_DIR/faults/WrongExpectedTest.java.txt" "$WORK_DIR/src/test/java/com/factorycare/learning/OrderAmountCalculatorTest.java"
if run_maven surefire.log; then echo "EXPECTED assertion failure" >&2; exit 1; fi
grep -Fq "surefire:3.5.5:test" "$BUILD_DIR/surefire.log"
grep -Fq "Tests run: 2, Failures: 1, Errors: 0, Skipped: 0" "$BUILD_DIR/surefire.log"
grep -Fq "expected: <5998> but was: <5997>" "$BUILD_DIR/surefire.log"

echo "GREEN tests=2 failures=0 errors=0 skipped=0"
echo "EXPECTED_FAILURE compile tests-run=0"
echo "EXPECTED_FAILURE testCompile tests-run=0"
echo "EXPECTED_FAILURE surefire tests-run=2 failures=1 errors=0"
echo "LAB PASS maven-stages=compile,testCompile,surefire offline=true"
