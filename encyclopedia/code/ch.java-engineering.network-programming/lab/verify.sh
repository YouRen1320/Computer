#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
FAILURE_CLASSES_DIR="$BUILD_DIR/failure-classes"

JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in
  "javac 25"|"javac 25."*) ;;
  *) echo "EXPECTED JDK 25 javac, got: $JAVAC_VERSION" >&2; exit 2 ;;
esac
case "$JAVA_VERSION" in
  *'version "25"'*|*'version "25.'*) ;;
  *) echo "EXPECTED Java 25 runtime, got: $JAVA_VERSION" >&2; exit 2 ;;
esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR" "$FAILURE_CLASSES_DIR"

javac --release 25 --add-modules jdk.httpserver \
  -d "$CLASSES_DIR" \
  "$ROOT_DIR/src/NetworkProgrammingLab.java"
java -Dstdout.encoding=UTF-8 --add-modules jdk.httpserver \
  -cp "$CLASSES_DIR" \
  NetworkProgrammingLab > "$BUILD_DIR/lab.out"

cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
address.loopback=true unresolvedFixture=true
frame.emptyPayloadBytes=0 utf8PayloadBytes=12 headerBytes=4
frame.readFullyRecovered=true truncated=EOFException oversized=FrameTooLargeException max=1024
tcp.requestBytes=12 responseBytes=16 response=ACK:维修单-84
tcp.closed=client:true,server:true,executor:true
udp.packetLengths=1,6 responseBytes=3,8 responses=1:A|2:状态
udp.boundaryCount=2 closed=client:true,server:true,executor:true
uri.scheme=http path=/ok dynamicPort=true
http.ok=200:ready
http.unavailable=503:maintenance action=surface-maintenance
http.timeout=HttpTimeoutException handlerStarted=true handlerFinished=true
http.closed=client:true,server:true,executors:true
assertions=40 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/lab.out"

javac --release 25 \
  -d "$FAILURE_CLASSES_DIR" \
  "$ROOT_DIR"/failures/*.java

set +e
java -cp "$FAILURE_CLASSES_DIR" UnresolvedAddressFailure > "$BUILD_DIR/unresolved.out" 2> "$BUILD_DIR/unresolved.err"; unresolved_status=$?
java -cp "$FAILURE_CLASSES_DIR" ConnectionRefusedFailure > "$BUILD_DIR/refused.out" 2> "$BUILD_DIR/refused.err"; refused_status=$?
java -cp "$FAILURE_CLASSES_DIR" ReadTimeoutFailure > "$BUILD_DIR/timeout.out" 2> "$BUILD_DIR/timeout.err"; timeout_status=$?
java -cp "$FAILURE_CLASSES_DIR" SocketLeakFailure > "$BUILD_DIR/leak.out" 2> "$BUILD_DIR/leak.err"; leak_status=$?
java -cp "$FAILURE_CLASSES_DIR" FrameLengthFailure > "$BUILD_DIR/frame.out" 2> "$BUILD_DIR/frame.err"; frame_status=$?
set -e

[[ $unresolved_status -eq 4 ]]
[[ $refused_status -eq 5 ]]
[[ $timeout_status -eq 6 ]]
[[ $leak_status -eq 7 ]]
[[ $frame_status -eq 8 ]]
[[ ! -s "$BUILD_DIR/unresolved.out" && ! -s "$BUILD_DIR/refused.out" && ! -s "$BUILD_DIR/timeout.out" && ! -s "$BUILD_DIR/leak.out" && ! -s "$BUILD_DIR/frame.out" ]]
grep -Fqx "UNRESOLVED_ADDRESS host=offline.invalid resolved=false stage=pre-connect cause=UnknownHostException" "$BUILD_DIR/unresolved.err"
grep -Fqx "CONNECTION_REFUSED loopback=true listenerClosed=true cause=ConnectException" "$BUILD_DIR/refused.err"
grep -Fqx "READ_TIMEOUT loopback=true connected=true cause=SocketTimeoutException" "$BUILD_DIR/timeout.err"
grep -Fqx "SOCKET_LEAK observedClosed=false cleanupClosed=true" "$BUILD_DIR/leak.err"
grep -Fqx "FRAME_LENGTH_REJECTED declared=1025 max=1024 allocationAttempted=false cause=FrameTooLargeException" "$BUILD_DIR/frame.err"

cat "$BUILD_DIR/lab.out"
echo "EXPECTED_FAILURE UnresolvedAddressFailure status=$unresolved_status evidence=offline-unresolved-address"
echo "EXPECTED_FAILURE ConnectionRefusedFailure status=$refused_status evidence=closed-loopback-listener"
echo "EXPECTED_FAILURE ReadTimeoutFailure status=$timeout_status evidence=connected-silent-peer"
echo "EXPECTED_FAILURE SocketLeakFailure status=$leak_status evidence=observed-open-then-cleaned"
echo "EXPECTED_FAILURE FrameLengthFailure status=$frame_status evidence=rejected-before-allocation"
echo "LAB PASS assertions=40 expected_failures=5 java=$JAVA_VERSION"
