#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C LANG=C

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED JDK 25, got: $JAVAC_VERSION" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/PriorityBatchChallenge.java"
java -cp "$CLASSES_DIR" PriorityBatchChallenge > "$BUILD_DIR/empty.out"
java -cp "$CLASSES_DIR" PriorityBatchChallenge 3 4 5 4 > "$BUILD_DIR/many.out"

actual_empty="$(cat "$BUILD_DIR/empty.out")"
actual_many="$(cat "$BUILD_DIR/many.out")"
solved_empty=$'count=0\nmax=NONE\nurgent=0\nfirst4=-1'
solved_many=$'count=4\nmax=5\nurgent=3\nfirst4=1'
starter_empty=$'count=0\nmax=0\nurgent=0\nfirst4=-1'
starter_many=$'count=4\nmax=5\nurgent=1\nfirst4=3'

if [[ "$actual_empty" == "$solved_empty" && "$actual_many" == "$solved_many" ]]; then
  cat "$BUILD_DIR/empty.out"
  cat "$BUILD_DIR/many.out"
  echo "EXERCISE CHECK mode=solved boundaries=empty-and-many"
elif [[ "$actual_empty" == "$starter_empty" && "$actual_many" == "$starter_many" ]]; then
  cat "$BUILD_DIR/empty.out"
  cat "$BUILD_DIR/many.out"
  echo "EXERCISE CHECK mode=starter-pending expected-mismatches=4"
else
  echo "UNRECOGNIZED OUTPUT: neither fixed starter nor solved contract" >&2
  cat "$BUILD_DIR/empty.out" >&2
  cat "$BUILD_DIR/many.out" >&2
  exit 1
fi
