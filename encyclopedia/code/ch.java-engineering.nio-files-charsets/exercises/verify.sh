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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/NioSafetyChallenge.java" "$ROOT_DIR"/failures/*.java
set +e
java -Dfile.encoding=ISO-8859-1 -cp "$CLASSES_DIR" NioSafetyChallenge > "$BUILD_DIR/challenge.out" 2> "$BUILD_DIR/challenge.err"; challenge_status=$?
java -cp "$CLASSES_DIR" DirectOverwriteFailure > "$BUILD_DIR/overwrite.out" 2> "$BUILD_DIR/overwrite.err"; overwrite_status=$?
java -cp "$CLASSES_DIR" RelativeBaseFailure > "$BUILD_DIR/base.out" 2> "$BUILD_DIR/base.err"; base_status=$?
java -cp "$CLASSES_DIR" SymlinkEscapeFailure > "$BUILD_DIR/link.out" 2> "$BUILD_DIR/link.err"; link_status=$?
set -e
case "$challenge_status" in
    8)
        grep -Fqx "STARTER_DEFAULT_CHARSET expectedUtf8=true actualRoundTrip=false" "$BUILD_DIR/challenge.err"
        challenge_mode="starter"
        challenge_failures=1
        echo "STARTER EXPECTED FAILURE status=$challenge_status reason=implicit-charset"
        ;;
    0)
        grep -Fqx "challenge.assertions=12 passed" "$BUILD_DIR/challenge.out"
        [[ ! -s "$BUILD_DIR/challenge.err" ]]
        challenge_mode="completed"
        challenge_failures=0
        echo "COMPLETED CHALLENGE PASS assertions=12"
        ;;
    *)
        echo "UNEXPECTED CHALLENGE STATUS status=$challenge_status" >&2
        cat "$BUILD_DIR/challenge.err" >&2
        exit 1
        ;;
esac
[[ $overwrite_status -eq 4 && $base_status -eq 5 && $link_status -eq 6 ]]
grep -Fqx "DIRECT_OVERWRITE_PARTIAL expected=old-complete actual=new-" "$BUILD_DIR/overwrite.err"
grep -Fqx "RELATIVE_BASE_DRIFT expectedConfiguredBase=true actualConfiguredBase=false" "$BUILD_DIR/base.err"
grep -Fqx "SYMLINK_ESCAPE lexicalInside=true realInside=false" "$BUILD_DIR/link.err"

echo "EXPECTED_FAILURE DirectOverwriteFailure status=$overwrite_status evidence=partial-target"
echo "EXPECTED_FAILURE RelativeBaseFailure status=$base_status evidence=wrong-anchor"
echo "EXPECTED_FAILURE SymlinkEscapeFailure status=$link_status evidence=real-path-escape"
echo "EXERCISE CHECK PASS mode=$challenge_mode expected_failures=$((challenge_failures + 3)) java=$JAVA_VERSION"
if [[ "$challenge_mode" == "starter" ]]; then
    printf '%s\n' 'EXPECTED_RED chapter=ch.java-engineering.nio-files-charsets oracle=verified-starter-failure'
    exit 41
fi
