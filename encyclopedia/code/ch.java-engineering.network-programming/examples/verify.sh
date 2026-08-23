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
  "$ROOT_DIR/src/NetworkProgrammingDemo.java"
java -Dstdout.encoding=UTF-8 --add-modules jdk.httpserver \
  -cp "$CLASSES_DIR" \
  NetworkProgrammingDemo > "$BUILD_DIR/demo.out"

cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
address.loopback=true unresolvedFixture=true
tcp.requestBytes=12 responseBytes=16 response=ACK:维修单-42
tcp.closed=client:true,server:true,executor:true
udp.requestPacketBytes=9 responsePacketBytes=14 response=ECHO:状态-OK
udp.closed=client:true,server:true,executor:true
http.ok=200:ready
http.unavailable=503:maintenance classification=retry-later
http.timeout=HttpTimeoutException handlerStarted=true handlerFinished=true
http.closed=client:true,server:true,executors:true
assertions=26 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

javac --release 25 \
  -d "$FAILURE_CLASSES_DIR" \
  "$ROOT_DIR"/failures/*.java

set +e
java -cp "$FAILURE_CLASSES_DIR" UnresolvedAddressFailure > "$BUILD_DIR/unresolved.out" 2> "$BUILD_DIR/unresolved.err"; unresolved_status=$?
java -cp "$FAILURE_CLASSES_DIR" ConnectionRefusedFailure > "$BUILD_DIR/refused.out" 2> "$BUILD_DIR/refused.err"; refused_status=$?
java -cp "$FAILURE_CLASSES_DIR" ReadTimeoutFailure > "$BUILD_DIR/timeout.out" 2> "$BUILD_DIR/timeout.err"; timeout_status=$?
java -cp "$FAILURE_CLASSES_DIR" SocketLeakFailure > "$BUILD_DIR/leak.out" 2> "$BUILD_DIR/leak.err"; leak_status=$?
set -e

[[ $unresolved_status -eq 4 ]]
[[ $refused_status -eq 5 ]]
[[ $timeout_status -eq 6 ]]
[[ $leak_status -eq 7 ]]
[[ ! -s "$BUILD_DIR/unresolved.out" && ! -s "$BUILD_DIR/refused.out" && ! -s "$BUILD_DIR/timeout.out" && ! -s "$BUILD_DIR/leak.out" ]]
grep -Fqx "UNRESOLVED_ADDRESS host=offline.invalid resolved=false stage=pre-connect cause=UnknownHostException" "$BUILD_DIR/unresolved.err"
grep -Fqx "CONNECTION_REFUSED loopback=true listenerClosed=true cause=ConnectException" "$BUILD_DIR/refused.err"
grep -Fqx "READ_TIMEOUT loopback=true connected=true cause=SocketTimeoutException" "$BUILD_DIR/timeout.err"
grep -Fqx "SOCKET_LEAK observedClosed=false cleanupClosed=true" "$BUILD_DIR/leak.err"

cat "$BUILD_DIR/demo.out"
echo "EXPECTED_FAILURE UnresolvedAddressFailure status=$unresolved_status evidence=offline-unresolved-address"
echo "EXPECTED_FAILURE ConnectionRefusedFailure status=$refused_status evidence=closed-loopback-listener"
echo "EXPECTED_FAILURE ReadTimeoutFailure status=$timeout_status evidence=connected-silent-peer"
echo "EXPECTED_FAILURE SocketLeakFailure status=$leak_status evidence=observed-open-then-cleaned"
echo "EXAMPLE PASS assertions=26 expected_failures=4 java=$JAVA_VERSION"
