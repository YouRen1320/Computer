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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/ReflectionProxyChallenge.java" "$ROOT_DIR"/failures/*.java
set +e
java -cp "$CLASSES_DIR" ReflectionProxyChallenge > "$BUILD_DIR/challenge.out" 2> "$BUILD_DIR/challenge.err"; challenge_status=$?
java -cp "$CLASSES_DIR" NoInterfaceProxyFailure > /dev/null 2> "$BUILD_DIR/interface.err"; a=$?
java -cp "$CLASSES_DIR" PrivateAccessFailure > /dev/null 2> "$BUILD_DIR/access.err"; b=$?
java -cp "$CLASSES_DIR" WrongContextLoaderFailure > /dev/null 2> "$BUILD_DIR/loader.err"; c=$?
set -e
case "$challenge_status" in
    8)
        grep -Fqx "STARTER_AUTH_BYPASS expected=SecurityException actual=device=A-17" "$BUILD_DIR/challenge.err"
        mode="starter"
        starter_failures=1
        echo "STARTER EXPECTED FAILURE status=8 reason=authorization-bypass"
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
[[ $a -eq 4 && $b -eq 5 && $c -eq 6 ]]
grep -Fqx "NO_INTERFACE_PROXY contractInterface=false exception=IllegalArgumentException" "$BUILD_DIR/interface.err"
grep -Fqx "PRIVATE_ACCESS_DENIED canAccess=false exception=IllegalAccessException" "$BUILD_DIR/access.err"
grep -Fqx "WRONG_CONTEXT_LOADER classFound=false explicitContractLoader=true" "$BUILD_DIR/loader.err"
echo "EXPECTED_FAILURE NoInterfaceProxyFailure status=$a evidence=interface-required"
echo "EXPECTED_FAILURE PrivateAccessFailure status=$b evidence=language-access"
echo "EXPECTED_FAILURE WrongContextLoaderFailure status=$c evidence=explicit-loader"
echo "EXERCISE CHECK PASS mode=$mode expected_failures=$((starter_failures + 3)) java=$JAVA_VERSION"
