#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/AuthorizationPolicyChallenge.java"
if java -cp "$BUILD_DIR/classes" AuthorizationPolicyChallenge > "$BUILD_DIR/starter.log" 2>&1; then
  echo "STARTER UNEXPECTEDLY PASSED" >&2
  exit 1
fi
grep -Fq 'UNKNOWN_ROLE_ALLOWED' "$BUILD_DIR/starter.log"
test "$(rg -c 'TODO' "$ROOT_DIR/src/AuthorizationPolicyChallenge.java")" -eq 7
echo "starter=expected-failure first=UNKNOWN_ROLE_ALLOWED todos=7"
echo "EXERCISE READY jdk=25 mode=offline"
