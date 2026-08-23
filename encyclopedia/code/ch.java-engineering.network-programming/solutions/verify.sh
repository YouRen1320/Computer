#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
FAILURE_CLASSES="$BUILD_DIR/failure-classes"
JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED JDK 25, got: $JAVAC_VERSION" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25.x, got: $JAVA_VERSION" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR" "$FAILURE_CLASSES"
javac --release 25 --add-modules jdk.httpserver -d "$CLASSES_DIR" "$ROOT_DIR/src/NetworkProgrammingSolution.java"
java --add-modules jdk.httpserver -cp "$CLASSES_DIR" NetworkProgrammingSolution > "$BUILD_DIR/solution.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
solution.tcpUtf8=true
solution.tcpFrameBytes=10
solution.tcpClosed=true
solution.udp=alarm=A17
solution.udpDatagramBytes=9
solution.udpClosed=true
solution.httpStatus=200
solution.httpBody=ready
solution.httpUnavailable=503
solution.httpTimedOut=true
solution.assertions=20 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/solution.out"

javac --release 25 -d "$FAILURE_CLASSES" "$ROOT_DIR"/failures/*.java
set +e
java -cp "$FAILURE_CLASSES" UnresolvedAddressFailure > /dev/null 2> "$BUILD_DIR/unresolved.err"; a=$?
java -cp "$FAILURE_CLASSES" ConnectionRefusedFailure > /dev/null 2> "$BUILD_DIR/refused.err"; b=$?
java -cp "$FAILURE_CLASSES" ReadTimeoutFailure > /dev/null 2> "$BUILD_DIR/timeout.err"; c=$?
java -cp "$FAILURE_CLASSES" SocketLeakFailure > /dev/null 2> "$BUILD_DIR/leak.err"; d=$?
java -cp "$FAILURE_CLASSES" FrameLengthFailure > /dev/null 2> "$BUILD_DIR/frame.err"; e=$?
set -e
[[ $a -eq 4 && $b -eq 5 && $c -eq 6 && $d -eq 7 && $e -eq 8 ]]
grep -Fqx "UNRESOLVED_ADDRESS stage=pre-connect unresolved=true exception=UnknownHostException closed=true" "$BUILD_DIR/unresolved.err"
grep -Fqx "CONNECTION_REFUSED layer=tcp exception=ConnectException closed=true" "$BUILD_DIR/refused.err"
grep -Fqx "READ_TIMEOUT phase=read exception=SocketTimeoutException closed=true" "$BUILD_DIR/timeout.err"
grep -Fqx "SOCKET_LEAK observedClosed=false cleanupClosed=true" "$BUILD_DIR/leak.err"
grep -Fqx "FRAME_LENGTH_REJECTED declared=4096 max=2048 exception=ProtocolException" "$BUILD_DIR/frame.err"

cat "$BUILD_DIR/solution.out"
echo "EXPECTED_FAILURE UnresolvedAddressFailure status=$a evidence=name-resolution"
echo "EXPECTED_FAILURE ConnectionRefusedFailure status=$b evidence=tcp-connect"
echo "EXPECTED_FAILURE ReadTimeoutFailure status=$c evidence=read-deadline"
echo "EXPECTED_FAILURE SocketLeakFailure status=$d evidence=resource-owner"
echo "EXPECTED_FAILURE FrameLengthFailure status=$e evidence=allocation-guard"
echo "SOLUTION PASS assertions=20 expected_failures=5 java=$JAVA_VERSION"
