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
java -cp "$CLASSES_DIR" SortingContractOracle > "$BUILD_DIR/lab.out"
grep -Fqx 'report.dispatch=WO-101,WO-102,WO-103,WO-104,WO-105,WO-106' "$BUILD_DIR/lab.out"
grep -Fqx 'report.stable=A,C,B,D' "$BUILD_DIR/lab.out"
grep -Fqx 'report.nullsLast=WO-201,WO-203,WO-202' "$BUILD_DIR/lab.out"
grep -Fqx 'report.contract=elements:6,pairs:36,triples:216' "$BUILD_DIR/lab.out"
grep -Fqx 'assertions=18 passed' "$BUILD_DIR/lab.out"

failure_count=0
for name in SubtractionOverflowFailure CyclicComparatorFailure SignSymmetryFailure NullFieldComparatorFailure TreeSetEqualityFailure; do
    case "$name" in
        SubtractionOverflowFailure) expected='OVERFLOW_ORDER' ;;
        CyclicComparatorFailure) expected='CYCLIC_ORDER' ;;
        SignSymmetryFailure) expected='SIGN_SYMMETRY' ;;
        NullFieldComparatorFailure) expected='NullPointerException' ;;
        TreeSetEqualityFailure) expected='COMPARATOR_COLLISION' ;;
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
[[ $failure_count -eq 5 ]]

cat "$BUILD_DIR/lab.out"
printf 'LAB PASS assertions=18 contract_triples=216 runtime_failures=5 warnings=0 jdk=25\n'
