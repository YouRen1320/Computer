#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/AuditPrivacyChallenge.java"
if java -cp "$BUILD_DIR/classes" AuditPrivacyChallenge > "$BUILD_DIR/starter.log" 2>&1; then
  echo "STARTER UNEXPECTEDLY PASSED" >&2
  exit 42
fi
if ! grep -Fq 'SECRET_FIELD_ACCEPTED' "$BUILD_DIR/starter.log"; then
  cat "$BUILD_DIR/starter.log" >&2
  echo "STARTER FAILURE MARKER MISMATCH expected=SECRET_FIELD_ACCEPTED" >&2
  exit 43
fi
todo_count="$(grep -c 'TODO' "$ROOT_DIR/src/AuditPrivacyChallenge.java" || true)"
if [[ "$todo_count" != "7" ]]; then
  echo "STARTER TODO COUNT MISMATCH expected=7 actual=${todo_count:-0}" >&2
  exit 44
fi
echo "EXPECTED_RED first=SECRET_FIELD_ACCEPTED todos=7 jdk=25 mode=offline"
exit 41
