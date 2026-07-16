#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/OAuthOidcFaultLab.java"
java -cp "$BUILD_DIR/classes" OAuthOidcFaultLab > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out" || {
  diff -u "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"
  exit 1
}

FAULTS=(MISSING_STATE WIDE_REDIRECT PKCE_NOT_CHECKED NONCE_NOT_CHECKED ID_TOKEN_AS_API REFRESH_TOKEN_EXPOSED PUBLIC_CLIENT_SECRET)
ORACLES=(MISSING_STATE_ACCEPTED WIDE_REDIRECT_ACCEPTED WRONG_VERIFIER_ACCEPTED WRONG_NONCE_ACCEPTED ID_TOKEN_ACCEPTED_BY_API REFRESH_TOKEN_SENT_TO_FRONTEND PUBLIC_CLIENT_STATIC_SECRET_ACCEPTED)
for index in "${!FAULTS[@]}"; do
  actual="$(java -cp "$BUILD_DIR/classes" OAuthOidcFaultLab "${FAULTS[$index]}")"
  if [[ "$actual" != "${ORACLES[$index]}" ]]; then
    echo "fault ${FAULTS[$index]} did not expose ${ORACLES[$index]}: $actual" >&2
    exit 1
  fi
done

if rg -n '(BEGIN (RSA|EC|OPENSSH) PRIVATE KEY|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.|java\.net|HttpClient|Socket)' "$ROOT_DIR/src"; then
  echo "secret-shaped material or network primitive found" >&2
  exit 1
fi
echo "LAB PASS jdk=25 mode=offline fault_oracles=7"
