#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/TenantIsolationFaultLab.java"
java -cp "$BUILD_DIR/classes" TenantIsolationFaultLab > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out" || {
  diff -u "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"
  exit 1
}

FAULTS=(TRUST_REQUEST_TENANT LIST_MISSING_TENANT WRITE_BY_ID_ONLY CACHE_KEY_MISSING_TENANT TASK_CONTEXT_MISSING JOIN_TENANT_MISSING NULL_MEANS_GLOBAL)
ORACLES=(FORGED_TENANT_ACCEPTED CROSS_TENANT_LIST_LEAKED CROSS_TENANT_WRITE_CHANGED CROSS_TENANT_CACHE_COLLISION BACKGROUND_CONTEXT_LEAKED CROSS_TENANT_JOIN_LEAKED NULL_TENANT_TREATED_AS_GLOBAL)
for index in "${!FAULTS[@]}"; do
  actual="$(java -cp "$BUILD_DIR/classes" TenantIsolationFaultLab "${FAULTS[$index]}")"
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
