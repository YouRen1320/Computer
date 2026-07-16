#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$ROOT_DIR"/src/*.java
java -cp "$CLASSES_DIR" LambdaContractOracle > "$BUILD_DIR/lab.out"
grep -Fqx 'report.rules=WO-101,WO-102' "$BUILD_DIR/lab.out"
grep -Fqx 'report.labels=P4:WO-101,P3:WO-102,P2:WO-103' "$BUILD_DIR/lab.out"
grep -Fqx 'report.notifications=notify:WO-101,notify:WO-102' "$BUILD_DIR/lab.out"
grep -Fqx 'report.references=static:true,bound:true,unbound:true,constructor:true' "$BUILD_DIR/lab.out"
grep -Fqx 'report.capture=threshold:3,below:false,equal:true,above:true' "$BUILD_DIR/lab.out"
grep -Fqx 'assertions=20 passed' "$BUILD_DIR/lab.out"

compile_failures=0
for name in CapturedVariableCompileFailure TwoAbstractMethodsCompileFailure MethodReferenceMismatchCompileFailure; do
    case "$name" in
        CapturedVariableCompileFailure) expected='effectively final' ;;
        TwoAbstractMethodsCompileFailure) expected='not a functional interface' ;;
        MethodReferenceMismatchCompileFailure) expected='invalid method reference' ;;
    esac
    set +e
    javac -J-Duser.language=en -J-Duser.country=US --release 25 -Xlint:all -Werror \
        -d "$CLASSES_DIR" "$ROOT_DIR/failures/$name.java" \
        > "$BUILD_DIR/$name.out" 2> "$BUILD_DIR/$name.err"
    status=$?
    set -e
    [[ $status -ne 0 ]]
    grep -Fq "$expected" "$BUILD_DIR/$name.err"
    compile_failures=$((compile_failures + 1))
    printf 'EXPECTED_COMPILE_FAILURE %s status=%s evidence=%s\n' "$name" "$status" "$expected"
done
[[ $compile_failures -eq 3 ]]

javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$ROOT_DIR/failures/HiddenSideEffectFailure.java"
set +e
java -cp "$CLASSES_DIR" HiddenSideEffectFailure > "$BUILD_DIR/HiddenSideEffectFailure.out" 2> "$BUILD_DIR/HiddenSideEffectFailure.err"
runtime_status=$?
set -e
[[ $runtime_status -ne 0 ]]
grep -Fq 'HIDDEN_SIDE_EFFECT' "$BUILD_DIR/HiddenSideEffectFailure.err"
printf 'EXPECTED_RUNTIME_FAILURE HiddenSideEffectFailure status=%s evidence=HIDDEN_SIDE_EFFECT\n' "$runtime_status"

cat "$BUILD_DIR/lab.out"
printf 'LAB PASS assertions=20 compile_failures=3 runtime_failures=1 warnings=0 jdk=25\n'
