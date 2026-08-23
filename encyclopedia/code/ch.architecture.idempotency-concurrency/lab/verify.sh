#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/IdempotencyConcurrencyFaultLab.java"
java -cp "$BUILD_DIR/classes" IdempotencyConcurrencyFaultLab > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out" || {
  diff -u "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"
  exit 1
}

FAULTS=(SIDE_EFFECT_BEFORE_CLAIM KEY_ONLY_SCOPE PAYLOAD_NOT_BOUND RESPONSE_NOT_SAVED VERSION_NOT_IN_WHERE UPDATE_ZERO_IGNORED BLIND_RETRY)
ORACLES=(DUPLICATE_SIDE_EFFECT CROSS_SCOPE_KEY_COLLISION DIFFERENT_PAYLOAD_REPLAYED REPLAY_RESPONSE_CHANGED LOST_UPDATE_COMMITTED ZERO_ROW_UPDATE_REPORTED_SUCCESS STALE_COMMAND_REAPPLIED)
for index in "${!FAULTS[@]}"; do
  actual="$(java -cp "$BUILD_DIR/classes" IdempotencyConcurrencyFaultLab "${FAULTS[$index]}")"
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
