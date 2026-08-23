#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/RedisCacheRateLimitFaultLab.java"
java -cp "$BUILD_DIR/classes" RedisCacheRateLimitFaultLab > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out" || {
  diff -u "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"
  exit 1
}

FAULTS=(MISSING_TENANT_KEY NO_INVALIDATION SAME_TTL NON_ATOMIC_INCREMENT_EXPIRE CHECK_THEN_INCREMENT WRONG_FAIL_POLICY AUTHORIZATION_CACHED)
ORACLES=(CROSS_TENANT_CACHE_LEAK STALE_AFTER_UPDATE SYNCHRONIZED_EXPIRY_STAMPEDE RATE_KEY_WITHOUT_TTL TOO_MANY_REQUESTS_ALLOWED EXPENSIVE_ENDPOINT_FAIL_OPEN REVOKED_ACCESS_ALLOWED)
for index in "${!FAULTS[@]}"; do
  actual="$(java -cp "$BUILD_DIR/classes" RedisCacheRateLimitFaultLab "${FAULTS[$index]}")"
  if [[ "$actual" != "${ORACLES[$index]}" ]]; then
    echo "fault ${FAULTS[$index]} did not expose ${ORACLES[$index]}: $actual" >&2
    exit 1
  fi
done
if rg -n '(java\.net|HttpClient|Socket|BEGIN (RSA|EC|OPENSSH) PRIVATE KEY)' "$ROOT_DIR/src"; then
  echo "network primitive or secret material found" >&2
  exit 1
fi
echo "LAB PASS jdk=25 mode=offline fault_oracles=7"
