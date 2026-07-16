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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/NioFilesCharsetsLab.java"
java -cp "$CLASSES_DIR" NioFilesCharsetsLab > "$BUILD_DIR/lab.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
lab.utf8=true
lab.invalid=MalformedInputException
lab.failure.oldPreserved=true
lab.failure.tempRemaining=0
lab.success=true
lab.walk.depth1=a.txt
lab.walk.depth4=a.txt,nested/b.txt
lab.symlinkFiltered=true
lab.realEscape=true
lab.assertions=24 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/lab.out"

javac --release 25 -d "$FAILURE_CLASSES" "$ROOT_DIR"/failures/*.java
set +e
java -Dfile.encoding=ISO-8859-1 -cp "$FAILURE_CLASSES" DefaultCharsetFailure > "$BUILD_DIR/charset.out" 2> "$BUILD_DIR/charset.err"; charset_status=$?
java -cp "$FAILURE_CLASSES" DirectOverwriteFailure > "$BUILD_DIR/overwrite.out" 2> "$BUILD_DIR/overwrite.err"; overwrite_status=$?
java -cp "$FAILURE_CLASSES" RelativeBaseFailure > "$BUILD_DIR/base.out" 2> "$BUILD_DIR/base.err"; base_status=$?
java -cp "$FAILURE_CLASSES" FollowLinksEscapeFailure > "$BUILD_DIR/links.out" 2> "$BUILD_DIR/links.err"; links_status=$?
java -cp "$FAILURE_CLASSES" TempResidueFailure > "$BUILD_DIR/residue.out" 2> "$BUILD_DIR/residue.err"; residue_status=$?
set -e
[[ $charset_status -eq 4 && $overwrite_status -eq 5 && $base_status -eq 6 && $links_status -eq 7 && $residue_status -eq 8 ]]
grep -Fqx "DEFAULT_CHARSET_MISMATCH charset=ISO-8859-1 roundTrip=false" "$BUILD_DIR/charset.err"
grep -Fqx "DIRECT_OVERWRITE_PARTIAL expected=old-complete actual=new-" "$BUILD_DIR/overwrite.err"
grep -Fqx "RELATIVE_BASE_DRIFT expectedConfiguredBase=true actualConfiguredBase=false" "$BUILD_DIR/base.err"
grep -Fqx "FOLLOW_LINKS_ESCAPE secretVisited=true" "$BUILD_DIR/links.err"
grep -Fqx "TEMP_RESIDUE_AFTER_FAILURE count=1" "$BUILD_DIR/residue.err"

cat "$BUILD_DIR/lab.out"
echo "EXPECTED_FAILURE DefaultCharsetFailure status=$charset_status evidence=implicit-decoder"
echo "EXPECTED_FAILURE DirectOverwriteFailure status=$overwrite_status evidence=partial-target"
echo "EXPECTED_FAILURE RelativeBaseFailure status=$base_status evidence=wrong-anchor"
echo "EXPECTED_FAILURE FollowLinksEscapeFailure status=$links_status evidence=external-secret"
echo "EXPECTED_FAILURE TempResidueFailure status=$residue_status evidence=temp-left-behind"
echo "LAB PASS assertions=24 expected_failures=5 java=$JAVA_VERSION"
