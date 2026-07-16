#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/AuthorizationFaultLab.java"
java -cp "$BUILD_DIR/classes" AuthorizationFaultLab > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out" || {
  diff -u "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"
  exit 1
}

FAULTS=(UI_ONLY URL_ONLY OBJECT_IDOR ALLOW_UNKNOWN_ROLE ALLOW_UNKNOWN_ACTION CONFLICT_LAST_ALLOW TRUST_REQUEST_ATTRIBUTE)
ORACLES=(UI_ONLY_SERVER_BYPASS DIRECT_SERVICE_BYPASS OTHER_OWNER_OBJECT_ACCEPTED UNKNOWN_ROLE_ACCEPTED UNKNOWN_ACTION_ACCEPTED EXPLICIT_DENY_OVERRIDDEN CLIENT_OWNER_FLAG_TRUSTED)
for index in "${!FAULTS[@]}"; do
  actual="$(java -cp "$BUILD_DIR/classes" AuthorizationFaultLab "${FAULTS[$index]}")"
  if [[ "$actual" != "${ORACLES[$index]}" ]]; then
    echo "fault ${FAULTS[$index]} did not expose ${ORACLES[$index]}: $actual" >&2
    exit 1
  fi
done
echo "LAB PASS jdk=25 mode=offline fault_oracles=7"
