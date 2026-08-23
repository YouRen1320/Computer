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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/NetworkProgrammingChallenge.java" "$ROOT_DIR"/failures/*.java
set +e
java -cp "$CLASSES_DIR" NetworkProgrammingChallenge > "$BUILD_DIR/challenge.out" 2> "$BUILD_DIR/challenge.err"; challenge_status=$?
java -cp "$CLASSES_DIR" UnresolvedAddressFailure > /dev/null 2> "$BUILD_DIR/unresolved.err"; a=$?
java -cp "$CLASSES_DIR" ConnectionRefusedFailure > /dev/null 2> "$BUILD_DIR/refused.err"; b=$?
java -cp "$CLASSES_DIR" ReadTimeoutFailure > /dev/null 2> "$BUILD_DIR/timeout.err"; c=$?
java -cp "$CLASSES_DIR" SocketLeakFailure > /dev/null 2> "$BUILD_DIR/leak.err"; d=$?
set -e
case "$challenge_status" in
    8)
        grep -Eq '^STARTER_FRAME_LENGTH expectedBytes=[1-9][0-9]* declaredChars=[1-9][0-9]*$' "$BUILD_DIR/challenge.err"
        mode="starter"
        starter_failures=1
        echo "STARTER EXPECTED FAILURE status=8 reason=utf8-byte-length"
        ;;
    0)
        grep -Fqx "challenge.assertions=10 passed" "$BUILD_DIR/challenge.out"
        [[ ! -s "$BUILD_DIR/challenge.err" ]]
        mode="completed"
        starter_failures=0
        echo "COMPLETED CHALLENGE PASS assertions=10"
        ;;
    *)
        echo "UNEXPECTED CHALLENGE STATUS status=$challenge_status" >&2
        cat "$BUILD_DIR/challenge.err" >&2
        exit 1
        ;;
esac
[[ $a -eq 4 && $b -eq 5 && $c -eq 6 && $d -eq 7 ]]
grep -Fqx "UNRESOLVED_ADDRESS stage=pre-connect unresolved=true exception=UnknownHostException closed=true" "$BUILD_DIR/unresolved.err"
grep -Fqx "CONNECTION_REFUSED layer=tcp exception=ConnectException closed=true" "$BUILD_DIR/refused.err"
grep -Fqx "READ_TIMEOUT phase=read exception=SocketTimeoutException closed=true" "$BUILD_DIR/timeout.err"
grep -Fqx "SOCKET_LEAK observedClosed=false cleanupClosed=true" "$BUILD_DIR/leak.err"
echo "EXPECTED_FAILURE UnresolvedAddressFailure status=$a evidence=name-resolution"
echo "EXPECTED_FAILURE ConnectionRefusedFailure status=$b evidence=tcp-connect"
echo "EXPECTED_FAILURE ReadTimeoutFailure status=$c evidence=read-deadline"
echo "EXPECTED_FAILURE SocketLeakFailure status=$d evidence=resource-owner"
echo "EXERCISE CHECK PASS mode=$mode expected_failures=$((starter_failures + 4)) java=$JAVA_VERSION"
if [[ "$mode" == "starter" ]]; then
    printf '%s\n' 'EXPECTED_RED chapter=ch.java-engineering.network-programming oracle=verified-starter-failure'
    exit 41
fi
