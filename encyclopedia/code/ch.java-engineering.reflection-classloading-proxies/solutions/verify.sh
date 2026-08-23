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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/ReflectionProxySolution.java"
java -cp "$CLASSES_DIR" ReflectionProxySolution > "$BUILD_DIR/solution.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
solution.annotation=MAINTAINER
solution.result=device=A-17
solution.events=before:inspect,after:inspect,before:fail,failure:fail:IllegalStateException
solution.denied=true
solution.cause=IllegalStateException
solution.loaderRestored=true
solution.assertions=19 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/solution.out"

javac --release 25 -d "$FAILURE_CLASSES" "$ROOT_DIR"/failures/*.java
set +e
java -cp "$FAILURE_CLASSES" NoInterfaceProxyFailure > /dev/null 2> "$BUILD_DIR/interface.err"; a=$?
java -cp "$FAILURE_CLASSES" PrivateAccessFailure > /dev/null 2> "$BUILD_DIR/access.err"; b=$?
java -cp "$FAILURE_CLASSES" WrongContextLoaderFailure > /dev/null 2> "$BUILD_DIR/loader.err"; c=$?
java -cp "$FAILURE_CLASSES" WrappedTargetFailure > /dev/null 2> "$BUILD_DIR/wrapper.err"; d=$?
java -cp "$FAILURE_CLASSES" EagerInitializationFailure > /dev/null 2> "$BUILD_DIR/init.err"; e=$?
set -e
[[ $a -eq 4 && $b -eq 5 && $c -eq 6 && $d -eq 7 && $e -eq 8 ]]
grep -Fqx "NO_INTERFACE_PROXY contractInterface=false exception=IllegalArgumentException" "$BUILD_DIR/interface.err"
grep -Fqx "PRIVATE_ACCESS_DENIED canAccess=false exception=IllegalAccessException" "$BUILD_DIR/access.err"
grep -Fqx "WRONG_CONTEXT_LOADER classFound=false explicitContractLoader=true" "$BUILD_DIR/loader.err"
grep -Fqx "WRAPPED_TARGET expected=IllegalStateException actual=InvocationTargetException" "$BUILD_DIR/wrapper.err"
grep -Fqx "EAGER_INITIALIZATION before=0 after=1" "$BUILD_DIR/init.err"
cat "$BUILD_DIR/solution.out"
echo "EXPECTED_FAILURE NoInterfaceProxyFailure status=$a evidence=interface-required"
echo "EXPECTED_FAILURE PrivateAccessFailure status=$b evidence=language-access"
echo "EXPECTED_FAILURE WrongContextLoaderFailure status=$c evidence=explicit-loader"
echo "EXPECTED_FAILURE WrappedTargetFailure status=$d evidence=unwrap-cause"
echo "EXPECTED_FAILURE EagerInitializationFailure status=$e evidence=initialize-flag"
echo "SOLUTION PASS assertions=19 expected_failures=5 java=$JAVA_VERSION"
