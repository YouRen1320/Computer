#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"

JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in
  "javac 25"|"javac 25."*) ;;
  *) echo "EXPECTED JDK 25, got: $JAVAC_VERSION" >&2; exit 2 ;;
esac
case "$JAVA_VERSION" in
  *'version "25.'*|*'version "25"'*) ;;
  *) echo "EXPECTED java 25.x, got: $JAVA_VERSION" >&2; exit 2 ;;
esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/BranchingDemo.java"
java -cp "$CLASSES_DIR" BranchingDemo > "$BUILD_DIR/demo.out"

expected_lines=(
  "priority.1=ROUTINE"
  "priority.3=HIGH"
  "priority.5=CRITICAL"
  "priority.0=REJECTED"
  "shortCircuit=false"
  "switchExpression=WORK"
  "switchStatement=DISPATCH"
)
for line in "${expected_lines[@]}"; do
  grep -Fqx "$line" "$BUILD_DIR/demo.out"
done
actual_line_count="$(wc -l < "$BUILD_DIR/demo.out" | tr -d '[:space:]')"
if [[ "$actual_line_count" != "${#expected_lines[@]}" ]]; then
  echo "UNEXPECTED OUTPUT: expected ${#expected_lines[@]} lines, got $actual_line_count" >&2
  cat "$BUILD_DIR/demo.out" >&2
  exit 1
fi

cp "$ROOT_DIR/failures/MissingSwitchCase.java.txt" "$BUILD_DIR/MissingSwitchCase.java"
set +e
javac -J-Duser.language=en -J-Duser.country=US --release 25 \
  -d "$CLASSES_DIR" "$BUILD_DIR/MissingSwitchCase.java" \
  > "$BUILD_DIR/missing-switch.out" 2> "$BUILD_DIR/missing-switch.err"
failure_status=$?
set -e
if [[ $failure_status -eq 0 ]]; then
  echo "EXPECTED FAILURE: incomplete switch expression compiled" >&2
  exit 1
fi
grep -Fq "switch expression does not cover all possible input values" "$BUILD_DIR/missing-switch.err"
grep -Fq "MissingSwitchCase.java:" "$BUILD_DIR/missing-switch.err"

cat "$BUILD_DIR/demo.out"
echo "EXPECTED_FAILURE MissingSwitchCase status=$failure_status stage=compile evidence=non-exhaustive-switch"
echo "EXAMPLES PASS javac=$JAVAC_VERSION java=$JAVA_VERSION"
