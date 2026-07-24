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
java -cp "$CLASSES_DIR" AssociativeCollectionsOracle > "$BUILD_DIR/lab.out"
grep -Fqx 'report.input=PUMP-01,FAN-02,PUMP-01' "$BUILD_DIR/lab.out"
grep -Fqx 'report.unique=PUMP-01,FAN-02' "$BUILD_DIR/lab.out"
grep -Fqx 'report.counts=pump:2,fan:1' "$BUILD_DIR/lab.out"
grep -Fqx 'report.equalKey=hit:ACTIVE' "$BUILD_DIR/lab.out"
grep -Fqx 'report.missing=contains:false,get:null' "$BUILD_DIR/lab.out"
grep -Fqx 'assertions=20 passed' "$BUILD_DIR/lab.out"

failure_count=0
for name in MutableHashKeyFailure BrokenHashContractFailure MissingKeyUnboxingFailure ComparatorCollisionFailure; do
    case "$name" in
        MutableHashKeyFailure) expected='LOST_HASH_KEY' ;;
        BrokenHashContractFailure) expected='BROKEN_EQUAL_HASH' ;;
        MissingKeyUnboxingFailure) expected='NullPointerException' ;;
        ComparatorCollisionFailure) expected='COMPARATOR_COLLISION' ;;
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
[[ $failure_count -eq 4 ]]

cat "$BUILD_DIR/lab.out"
printf 'LAB PASS assertions=20 runtime_failures=4 warnings=0 jdk=25\n'
