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
mkdir -p "$CLASSES_DIR" "$BUILD_DIR/failure-src"
find "$ROOT_DIR/src" -name '*.java' -print0 | xargs -0 javac --release 25 -d "$CLASSES_DIR"
java -cp "$CLASSES_DIR" com.factorycare.device.app.AccessDemo > "$BUILD_DIR/demo.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
code=PUMP-01
status=REGISTERED
after=IN_REPAIR
packageProbe=VALVE-02
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

cp "$ROOT_DIR/failures/PrivateFieldAccess.java.txt" "$BUILD_DIR/failure-src/PrivateFieldAccess.java"
cp "$ROOT_DIR/failures/PackagePrivateAccess.java.txt" "$BUILD_DIR/failure-src/PackagePrivateAccess.java"
set +e
javac -XDrawDiagnostics --release 25 -cp "$CLASSES_DIR" -d "$BUILD_DIR/failure-classes" "$BUILD_DIR/failure-src/PrivateFieldAccess.java" > "$BUILD_DIR/private.out" 2> "$BUILD_DIR/private.err"
private_status=$?
javac -XDrawDiagnostics --release 25 -cp "$CLASSES_DIR" -d "$BUILD_DIR/failure-classes" "$BUILD_DIR/failure-src/PackagePrivateAccess.java" > "$BUILD_DIR/package.out" 2> "$BUILD_DIR/package.err"
package_status=$?
set -e
[[ $private_status -ne 0 ]]
[[ $package_status -ne 0 ]]
grep -Fq "compiler.err.report.access: status, private, com.factorycare.device.domain.Device" "$BUILD_DIR/private.err"
grep -Fq "compiler.err.not.def.public.cant.access: com.factorycare.device.domain.DeviceCodePolicy" "$BUILD_DIR/package.err"

cat "$BUILD_DIR/demo.out"
echo "EXPECTED_COMPILE_FAILURE PrivateFieldAccess status=$private_status evidence=private-access"
echo "EXPECTED_COMPILE_FAILURE PackagePrivateAccess status=$package_status evidence=package-private-access"
echo "EXAMPLE PASS lines=4 expected_failures=2 java=$JAVA_VERSION"
