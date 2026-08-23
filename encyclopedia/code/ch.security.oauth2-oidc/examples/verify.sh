#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/OAuthOidcBoundaryExample.java"
java -cp "$BUILD_DIR/classes" OAuthOidcBoundaryExample > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out" || {
  diff -u "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"
  exit 1
}
if rg -n '(BEGIN (RSA|EC|OPENSSH) PRIVATE KEY|client_secret|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.|java\.net|HttpClient|Socket)' "$ROOT_DIR/src"; then
  echo "secret-shaped material or network primitive found" >&2
  exit 1
fi
echo "EXAMPLE PASS jdk=25 mode=offline"
