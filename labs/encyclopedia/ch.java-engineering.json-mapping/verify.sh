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
java -cp "$CLASSES_DIR" JsonMappingOracle "$BUILD_DIR/roundtrip.json" > "$BUILD_DIR/lab.out"
grep -Fqx 'report.roundtrip=WO-机泵-101,OPEN,1234.50' "$BUILD_DIR/lab.out"
grep -Fqx 'report.presence=missing:MISSING,null:EXPLICIT_NULL,value:VALUE' "$BUILD_DIR/lab.out"
grep -Fqx 'report.unknown=strict:UNKNOWN_FIELD:priorityLabel,lenient:WO-101' "$BUILD_DIR/lab.out"
grep -Fqx 'report.file=utf8:true' "$BUILD_DIR/lab.out"
grep -Fqx 'report.errors=missing-id,null-status,invalid-time,negative-amount,scale,exponent,duplicate,version' "$BUILD_DIR/lab.out"
grep -Fqx 'assertions=25 passed' "$BUILD_DIR/lab.out"

failure_count=0
for name in WrongCharsetFailure MissingFileFailure FieldDriftFailure InvalidEnumFailure UnknownFieldIgnoredFailure PrecisionLossFailure; do
    case "$name" in
        WrongCharsetFailure) expected='WRONG_CHARSET'; argument="$BUILD_DIR/wrong-charset.json" ;;
        MissingFileFailure) expected='IO_READ_FAILURE'; argument="$BUILD_DIR/does-not-exist.json" ;;
        FieldDriftFailure) expected='FIELD_DRIFT'; argument='' ;;
        InvalidEnumFailure) expected='INVALID_ENUM:status'; argument='' ;;
        UnknownFieldIgnoredFailure) expected='UNKNOWN_FIELD_SILENTLY_IGNORED'; argument='' ;;
        PrecisionLossFailure) expected='DOUBLE_PRECISION_LOSS'; argument='' ;;
    esac
    set +e
    if [[ -n "$argument" ]]; then
        java -cp "$CLASSES_DIR" "$name" "$argument" > "$BUILD_DIR/$name.out" 2> "$BUILD_DIR/$name.err"
    else
        java -cp "$CLASSES_DIR" "$name" > "$BUILD_DIR/$name.out" 2> "$BUILD_DIR/$name.err"
    fi
    status=$?
    set -e
    [[ $status -ne 0 ]]
    grep -Fq "$expected" "$BUILD_DIR/$name.err"
    failure_count=$((failure_count + 1))
    printf 'EXPECTED_RUNTIME_FAILURE %s status=%s evidence=%s\n' "$name" "$status" "$expected"
done
[[ $failure_count -eq 6 ]]

cat "$BUILD_DIR/lab.out"
printf 'LAB PASS assertions=25 runtime_failures=6 warnings=0 jdk=25\n'
