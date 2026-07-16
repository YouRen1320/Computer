#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C LANG=C MAVEN_OPTS="-Dfile.encoding=UTF-8 -Duser.language=en -Duser.country=US"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
WORK_DIR="$BUILD_DIR/work"
rm -rf "$BUILD_DIR" && mkdir -p "$BUILD_DIR"

reset_work() { rm -rf "$WORK_DIR"; cp -R "$ROOT_DIR/project" "$WORK_DIR"; }
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
grep -Fq "Tests run: 4, Failures: 0, Errors: 0, Skipped: 0" "$BUILD_DIR/green.log"

reset_work
cp "$ROOT_DIR/faults/CompileFailure.java.txt" "$WORK_DIR/src/main/java/com/factorycare/learning/RepairCost.java"
if run_maven compile.log; then echo "EXPECTED compile failure" >&2; exit 1; fi
grep -Fq "compiler:3.15.0:compile" "$BUILD_DIR/compile.log"
grep -Fq "Compilation failure" "$BUILD_DIR/compile.log"

reset_work
cp "$ROOT_DIR/faults/RuntimeFailure.java.txt" "$WORK_DIR/src/main/java/com/factorycare/learning/RepairCost.java"
if run_maven runtime.log; then echo "EXPECTED runtime error" >&2; exit 1; fi
grep -Fq "Tests run: 4, Failures: 0, Errors: 1, Skipped: 0" "$BUILD_DIR/runtime.log"
grep -Fq "ArithmeticException" "$BUILD_DIR/runtime.log"
grep -Fq "RepairCost.java" "$BUILD_DIR/runtime.log"

reset_work
cp "$ROOT_DIR/faults/WrongExpectedTest.java.txt" "$WORK_DIR/src/test/java/com/factorycare/learning/RepairCostTest.java"
if run_maven assertion.log; then echo "EXPECTED assertion failure" >&2; exit 1; fi
grep -Fq "Tests run: 4, Failures: 1, Errors: 0, Skipped: 0" "$BUILD_DIR/assertion.log"
grep -Fq "expected: <12501> but was: <12500>" "$BUILD_DIR/assertion.log"

reset_work
cp "$ROOT_DIR/faults/LogicFailure.java.txt" "$WORK_DIR/src/main/java/com/factorycare/learning/RepairCost.java"
if run_maven logic.log; then echo "EXPECTED logic failure" >&2; exit 1; fi
grep -Fq "Tests run: 4, Failures: 3, Errors: 0, Skipped: 0" "$BUILD_DIR/logic.log"
grep -Fq "expected: <12500>" "$BUILD_DIR/logic.log"

echo "GREEN tests=4 failures=0 errors=0"
echo "EXPECTED_FAILURE kind=compile stage=compile"
echo "EXPECTED_FAILURE kind=runtime-exception errors=1"
echo "EXPECTED_FAILURE kind=wrong-assertion failures=1"
echo "EXPECTED_FAILURE kind=logic failures=3"
echo "LAB PASS debugging categories=4 offline=true"
