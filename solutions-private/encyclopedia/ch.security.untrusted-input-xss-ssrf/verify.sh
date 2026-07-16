#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"

case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/InputBoundaryChallengeSolution.java"
java -cp "$BUILD_DIR/classes" InputBoundaryChallengeSolution > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"
if rg -n 'TODO' "$ROOT_DIR/src" >/dev/null; then
    echo "SOLUTION STILL CONTAINS TODO" >&2
    exit 1
fi
cat "$BUILD_DIR/actual.out"
