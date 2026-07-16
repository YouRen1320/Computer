#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C LANG=C

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED JDK 25, got: $JAVAC_VERSION" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25.x, got: $JAVA_VERSION" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR"/src/*.java "$ROOT_DIR"/failures/*.java
java -cp "$CLASSES_DIR" ArrayBoundaryLab > "$BUILD_DIR/no-args.out"
java -cp "$CLASSES_DIR" ArrayBoundaryLab 3 5 2 > "$BUILD_DIR/three-args.out"
java -ea -cp "$CLASSES_DIR" ArrayBoundaryOracle > "$BUILD_DIR/oracle.out"

expected_prefix=$'empty.length=0 traversed=0\none.length=1 first=4 last=4\nmany.length=4 max=5 found4=2 urgent=3\nalias.before=3 alias.after=5 original=5\ncopy.changed=9 original=5\nmatrix.rows=3 lengths=2,1,0 value=B01'
expected_no_args="$expected_prefix"$'\nargs.count=0\nargs.summary=max=NONE sum=0'
expected_three_args="$expected_prefix"$'\nargs.count=3\nargs.summary=max=5 sum=10'
[[ "$(cat "$BUILD_DIR/no-args.out")" == "$expected_no_args" ]]
[[ "$(cat "$BUILD_DIR/three-args.out")" == "$expected_three_args" ]]
grep -Fqx "assertions=14 passed" "$BUILD_DIR/oracle.out"

run_failure() {
  local class_name="$1" expected_detail="$2"
  set +e
  java -cp "$CLASSES_DIR" "$class_name" > "$BUILD_DIR/$class_name.out" 2> "$BUILD_DIR/$class_name.err"
  local status=$?
  set -e
  if [[ $status -eq 0 ]]; then echo "EXPECTED FAILURE: $class_name exited 0" >&2; exit 1; fi
  grep -Fq "ArrayIndexOutOfBoundsException" "$BUILD_DIR/$class_name.err"
  grep -Fq "$expected_detail" "$BUILD_DIR/$class_name.err"
  echo "EXPECTED_FAILURE $class_name status=$status evidence=$expected_detail"
}

cat "$BUILD_DIR/no-args.out"
cat "$BUILD_DIR/oracle.out"
run_failure LengthAsLastIndexFailure "Index 3 out of bounds for length 3"
run_failure EmptyArgsFailure "Index 0 out of bounds for length 0"
run_failure SwappedCoordinatesFailure "Index 1 out of bounds for length 1"
echo "LAB PASS arrays=empty-one-many alias=verified matrix=2-1-0 assertions=14 java=$JAVA_VERSION"
