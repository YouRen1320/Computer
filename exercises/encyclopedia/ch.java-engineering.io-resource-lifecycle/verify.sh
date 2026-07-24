#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED JDK 25, got: $JAVAC_VERSION" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25.x, got: $JAVA_VERSION" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/IoLifecycleChallenge.java" "$ROOT_DIR/failures/BufferCountFailure.java"
set +e
java -cp "$CLASSES_DIR" IoLifecycleChallenge > "$BUILD_DIR/challenge.out" 2> "$BUILD_DIR/challenge.err"; challenge_status=$?
java -cp "$CLASSES_DIR" BufferCountFailure > "$BUILD_DIR/buffer.out" 2> "$BUILD_DIR/buffer.err"; buffer_status=$?
set -e
case "$challenge_status" in
    8)
        grep -Fqx "STARTER_SWALLOWED_IO expected=CopyException actual=empty-text" "$BUILD_DIR/challenge.err"
        challenge_mode="starter"
        challenge_failures=1
        echo "STARTER EXPECTED FAILURE status=$challenge_status reason=io-swallowed"
        ;;
    0)
        grep -Fqx "challenge.assertions=16 passed" "$BUILD_DIR/challenge.out"
        [[ ! -s "$BUILD_DIR/challenge.err" ]]
        challenge_mode="completed"
        challenge_failures=0
        echo "COMPLETED CHALLENGE PASS assertions=16"
        ;;
    *)
        echo "UNEXPECTED CHALLENGE STATUS status=$challenge_status" >&2
        cat "$BUILD_DIR/challenge.err" >&2
        exit 1
        ;;
esac
[[ $buffer_status -eq 7 ]]
grep -Fqx "BUFFER_COUNT_IGNORED expectedLength=5 actualLength=8" "$BUILD_DIR/buffer.err"

echo "EXPECTED_FAILURE BufferCountFailure status=$buffer_status evidence=read-count-ignored"
echo "EXERCISE CHECK PASS mode=$challenge_mode expected_failures=$((challenge_failures + 1)) java=$JAVA_VERSION"
if [[ "$challenge_mode" == "starter" ]]; then
    exit 41
fi
