#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac
rm -rf "$BUILD"
mkdir -p "$BUILD/classes"

javac --release 25 -Xlint:all -Werror -d "$BUILD/classes" "$ROOT/src/JwtValidationLab.java"
java -cp "$BUILD/classes" JwtValidationLab > "$BUILD/actual.out"
cmp -s "$ROOT/expected.out" "$BUILD/actual.out" || {
  diff -u "$ROOT/expected.out" "$BUILD/actual.out"
  exit 1
}

FAULTS=(DECODE_ONLY ALG_FROM_TOKEN ISSUER_NOT_CHECKED AUDIENCE_NOT_CHECKED TIME_NOT_CHECKED QUERY_TOKEN TOKEN_LOGGED)
ORACLES=(UNVERIFIED_DECODE_ACCEPTED UNSUPPORTED_ALGORITHM_ACCEPTED WRONG_ISSUER_ACCEPTED WRONG_AUDIENCE_ACCEPTED EXPIRED_TOKEN_ACCEPTED QUERY_BEARER_ACCEPTED FULL_TOKEN_LOGGED)

for index in "${!FAULTS[@]}"; do
  fault="${FAULTS[$index]}"
  oracle="${ORACLES[$index]}"
  actual="$(java -cp "$BUILD/classes" JwtValidationLab "$fault")"
  if [[ "$actual" != "$oracle" ]]; then
    echo "fault $fault did not expose $oracle: $actual" >&2
    exit 1
  fi
done

if rg -n '(BEGIN (RSA|EC|OPENSSH) PRIVATE KEY|client_secret|password\s*=|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.)' "$ROOT/src"; then
  echo "secret-shaped material found" >&2
  exit 1
fi

echo "LAB PASS jdk=25 mode=offline fault_oracles=7"
