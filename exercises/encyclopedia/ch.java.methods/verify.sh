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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/WorkOrderMethodsChallenge.java"
java -cp "$CLASSES_DIR" WorkOrderMethodsChallenge > "$BUILD_DIR/challenge.out"
actual="$(cat "$BUILD_DIR/challenge.out")"
solved=$'total=5997\nremaining=7\nfirst=5\ncountdown=4'
starter=$'total=2002\nremaining=-7\nfirst=2\ncountdown=3'
cat "$BUILD_DIR/challenge.out"
if [[ "$actual" == "$solved" ]]; then
  echo "EXERCISE CHECK mode=solved contracts=4"
elif [[ "$actual" == "$starter" ]]; then
  echo "EXERCISE CHECK mode=starter-pending expected-mismatches=4"
else
  echo "UNRECOGNIZED OUTPUT: neither fixed starter nor solved contract" >&2
  exit 1
fi
