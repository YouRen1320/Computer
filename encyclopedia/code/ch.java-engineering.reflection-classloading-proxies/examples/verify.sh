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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/ReflectionProxyDemo.java"
java -cp "$CLASSES_DIR" ReflectionProxyDemo > "$BUILD_DIR/demo.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
class.interface=true
class.assignable=true
annotation.role=MAINTAINER
proxy.result=device=A-17
proxy.events=before:inspect,after:inspect,before:fail,failure:fail:IllegalStateException
proxy.targetClass=false
proxy.denied=true
proxy.cause=IllegalStateException
loader.rejected=true
loader.restored=true
assertions=24 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

javac --release 25 -d "$FAILURE_CLASSES" "$ROOT_DIR"/failures/*.java
set +e
java -cp "$FAILURE_CLASSES" NoInterfaceProxyFailure > "$BUILD_DIR/no-interface.out" 2> "$BUILD_DIR/no-interface.err"; no_interface_status=$?
java -cp "$FAILURE_CLASSES" PrivateAccessFailure > "$BUILD_DIR/access.out" 2> "$BUILD_DIR/access.err"; access_status=$?
java -cp "$FAILURE_CLASSES" WrongContextLoaderFailure > "$BUILD_DIR/loader.out" 2> "$BUILD_DIR/loader.err"; loader_status=$?
java -cp "$FAILURE_CLASSES" WrappedTargetFailure > "$BUILD_DIR/wrapper.out" 2> "$BUILD_DIR/wrapper.err"; wrapper_status=$?
set -e
[[ $no_interface_status -eq 4 && $access_status -eq 5 && $loader_status -eq 6 && $wrapper_status -eq 7 ]]
grep -Fqx "NO_INTERFACE_PROXY contractInterface=false exception=IllegalArgumentException" "$BUILD_DIR/no-interface.err"
grep -Fqx "PRIVATE_ACCESS_DENIED canAccess=false exception=IllegalAccessException" "$BUILD_DIR/access.err"
grep -Fqx "WRONG_CONTEXT_LOADER classFound=false restored=true" "$BUILD_DIR/loader.err"
grep -Fqx "WRAPPED_TARGET expected=IllegalStateException actual=InvocationTargetException" "$BUILD_DIR/wrapper.err"

cat "$BUILD_DIR/demo.out"
echo "EXPECTED_FAILURE NoInterfaceProxyFailure status=$no_interface_status evidence=interface-required"
echo "EXPECTED_FAILURE PrivateAccessFailure status=$access_status evidence=language-access"
echo "EXPECTED_FAILURE WrongContextLoaderFailure status=$loader_status evidence=explicit-loader"
echo "EXPECTED_FAILURE WrappedTargetFailure status=$wrapper_status evidence=unwrap-cause"
echo "EXAMPLE PASS assertions=24 expected_failures=4 java=$JAVA_VERSION"
