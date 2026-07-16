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
java -cp "$CLASSES_DIR" ComplexityAlgorithmsOracle > "$BUILD_DIR/lab.out"
grep -Fqx 'report.search=n:1024,linearMissing:1024,binaryMissing:10' "$BUILD_DIR/lab.out"
grep -Fqx 'report.scale=128:128/7,1024:1024/10,8192:8192/13' "$BUILD_DIR/lab.out"
grep -Fqx 'report.model=100:100/7,10000:10000/14,1000000:1000000/20' "$BUILD_DIR/lab.out"
grep -Fqx 'report.dedup=n:64,naivePairs:2016,setChecks:64' "$BUILD_DIR/lab.out"
grep -Fqx 'report.repeatedSort=queries:4,repeated:4,reused:1' "$BUILD_DIR/lab.out"
grep -Fqx 'assertions=20 passed' "$BUILD_DIR/lab.out"

failure_count=0
for name in UnsortedBinarySearchFailure QuadraticDedupFailure RepeatedSortFailure SemanticChangeFailure; do
    case "$name" in
        UnsortedBinarySearchFailure) expected='UNSORTED_PRECONDITION' ;;
        QuadraticDedupFailure) expected='QUADRATIC_GROWTH' ;;
        RepeatedSortFailure) expected='REPEATED_SORT' ;;
        SemanticChangeFailure) expected='SEMANTIC_CHANGE' ;;
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
