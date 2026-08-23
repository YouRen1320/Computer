#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/AuditPrivacyFaultLab.java"
java -cp "$BUILD_DIR/classes" AuditPrivacyFaultLab > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out" || {
  diff -u "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"
  exit 1
}

FAULTS=(SECRET_FIELD MISSING_TENANT MISSING_ACTOR FALSE_SUCCESS MUTABLE_AUDIT CROSS_TENANT_QUERY TRACE_AS_ACTOR)
ORACLES=(SECRET_FIELD_ACCEPTED MISSING_TENANT_ACCEPTED MISSING_ACTOR_ACCEPTED ROLLED_BACK_ACTION_MARKED_SUCCESS AUDIT_EVENT_OVERWRITTEN CROSS_TENANT_AUDIT_VISIBLE TRACE_ID_USED_AS_ACTOR)
for index in "${!FAULTS[@]}"; do
  actual="$(java -cp "$BUILD_DIR/classes" AuditPrivacyFaultLab "${FAULTS[$index]}")"
  if [[ "$actual" != "${ORACLES[$index]}" ]]; then
    echo "fault ${FAULTS[$index]} did not expose ${ORACLES[$index]}: $actual" >&2
    exit 1
  fi
done

if rg -n '(java\.net|HttpClient|Socket|BEGIN (RSA|EC|OPENSSH) PRIVATE KEY|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.)' "$ROOT_DIR/src"; then
  echo "network primitive or secret-shaped material found" >&2
  exit 1
fi
echo "LAB PASS jdk=25 mode=offline fault_oracles=7"
