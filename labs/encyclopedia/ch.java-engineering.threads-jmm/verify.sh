#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$ROOT_DIR"/src/*.java "$ROOT_DIR"/failures/*.java
java -cp "$CLASSES_DIR" ThreadsJmmOracle > "$BUILD_DIR/lab.out"
grep -Fqx 'report.lifecycle=NEW->TERMINATED' "$BUILD_DIR/lab.out"
grep -Fqx 'report.happensBefore=start:config-v1,join:42,latch:9' "$BUILD_DIR/lab.out"
grep -Fqx 'report.counters=rounds:40,incrementsPerThread:200,expected:400' "$BUILD_DIR/lab.out"
grep -Fqx 'report.strategies=synchronized:400,lock:400,atomic:400' "$BUILD_DIR/lab.out"
grep -Fqx 'report.visibility=volatile:7,terminated:true' "$BUILD_DIR/lab.out"
grep -Fqx 'assertions=20 passed' "$BUILD_DIR/lab.out"

failure_count=0
for name in DeterministicLostUpdateFailure VolatileNotAtomicFailure WrongLockIdentityFailure CheckThenActFailure MissingVisibilityEdgeFailure LockOrderCycleFailure; do
    case "$name" in
        DeterministicLostUpdateFailure) expected='LOST_UPDATE' ;;
        VolatileNotAtomicFailure) expected='VOLATILE_NOT_ATOMIC' ;;
        WrongLockIdentityFailure) expected='WRONG_LOCK_IDENTITY' ;;
        CheckThenActFailure) expected='CHECK_THEN_ACT_DUPLICATE' ;;
        MissingVisibilityEdgeFailure) expected='MISSING_VISIBILITY_EDGE' ;;
        LockOrderCycleFailure) expected='LOCK_ORDER_CYCLE' ;;
    esac
    set +e
    java -cp "$CLASSES_DIR" "$name" > "$BUILD_DIR/$name.out" 2> "$BUILD_DIR/$name.err"
    status=$?
    set -e
    [[ $status -ne 0 ]]
    grep -Fq "$expected" "$BUILD_DIR/$name.err"
    failure_count=$((failure_count + 1))
    printf 'EXPECTED_RUNTIME_FAILURE %s status=%s evidence=%s\n' "$name" "$status" "$expected"
done
[[ $failure_count -eq 6 ]]

cat "$BUILD_DIR/lab.out"
printf 'LAB PASS assertions=20 rounds=40 runtime_failures=6 warnings=0 jdk=25\n'
