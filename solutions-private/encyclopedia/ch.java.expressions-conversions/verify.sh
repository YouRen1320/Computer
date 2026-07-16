#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"

JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in
  "javac 25"|"javac 25."*) ;;
  *)
    echo "EXPECTED JDK 25, got: $JAVAC_VERSION" >&2
    exit 2
    ;;
esac
case "$JAVA_VERSION" in
  *'version "25.'*|*'version "25"'*) ;;
  *)
    echo "EXPECTED java 25.x, got: $JAVA_VERSION" >&2
    exit 2
    ;;
esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/MoneyChallenge.java"
java -cp "$CLASSES_DIR" MoneyChallenge > "$BUILD_DIR/solution.out"

grep -Fqx "totalCents=7501" "$BUILD_DIR/solution.out"
grep -Fqx "eachCents=1875" "$BUILD_DIR/solution.out"
grep -Fqx "remainderCents=1" "$BUILD_DIR/solution.out"
grep -Fqx "conserved=true" "$BUILD_DIR/solution.out"
solution_line_count="$(wc -l < "$BUILD_DIR/solution.out" | tr -d '[:space:]')"
if [[ "$solution_line_count" != "4" ]]; then
  echo "UNEXPECTED OUTPUT: expected 4 lines, got $solution_line_count" >&2
  cat "$BUILD_DIR/solution.out" >&2
  exit 1
fi

cat "$BUILD_DIR/solution.out"
echo "PRIVATE SOLUTION PASS javac=$JAVAC_VERSION java=$JAVA_VERSION"
