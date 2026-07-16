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
java -cp "$CLASSES_DIR" FunctionalPipelinesOracle > "$BUILD_DIR/lab.out"
grep -Fqx 'report.empty=ids:0,groups:0,total:0,max:empty' "$BUILD_DIR/lab.out"
grep -Fqx 'report.single=ids:WO-201,groups:MECHANICAL:15,total:15,max:4' "$BUILD_DIR/lab.out"
grep -Fqx 'report.multi=ids:WO-101,WO-103,WO-104,WO-105' "$BUILD_DIR/lab.out"
grep -Fqx 'report.groups=MECHANICAL:55,ELECTRICAL:20,NETWORK:40' "$BUILD_DIR/lab.out"
grep -Fqx 'report.optional=present:P5,empty:fallback,calls:1' "$BUILD_DIR/lab.out"
grep -Fqx 'assertions=22 passed' "$BUILD_DIR/lab.out"

failure_count=0
for name in ReusedStreamFailure PeekSideEffectFailure OptionalGetFailure NonAssociativeReducerFailure EagerFallbackFailure; do
    case "$name" in
        ReusedStreamFailure) expected='REUSED_STREAM' ;;
        PeekSideEffectFailure) expected='PEEK_NOT_EXECUTED' ;;
        OptionalGetFailure) expected='OPTIONAL_EMPTY_GET' ;;
        NonAssociativeReducerFailure) expected='NON_ASSOCIATIVE_REDUCER' ;;
        EagerFallbackFailure) expected='EAGER_FALLBACK' ;;
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
printf 'LAB PASS assertions=22 runtime_failures=5 warnings=0 jdk=25\n'
