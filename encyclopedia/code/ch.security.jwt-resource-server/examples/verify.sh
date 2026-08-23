#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac
rm -rf "$BUILD"
mkdir -p "$BUILD/classes"

javac --release 25 -Xlint:all -Werror -d "$BUILD/classes" "$ROOT/src/JwtResourceServerExample.java"
java -cp "$BUILD/classes" JwtResourceServerExample > "$BUILD/actual.out"
cmp -s "$ROOT/expected.out" "$BUILD/actual.out" || {
  diff -u "$ROOT/expected.out" "$BUILD/actual.out"
  exit 1
}

if rg -n '(BEGIN (RSA|EC|OPENSSH) PRIVATE KEY|client_secret|password\s*=|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.)' "$ROOT/src"; then
  echo "secret-shaped material found" >&2
  exit 1
fi

echo "EXAMPLE PASS jdk=25 mode=offline"
