#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/DomainEventsOutboxFaultLab.java"
java -cp "$BUILD_DIR/classes" DomainEventsOutboxFaultLab > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out" || {
  diff -u "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"
  exit 1
}

FAULTS=(BUSINESS_COMMIT_BEFORE_EVENT EVENT_BEFORE_STATE_CHANGE SEND_THEN_MARK_CRASH NEW_ID_ON_RETRY PAYLOAD_WITHOUT_VERSION MARK_BEFORE_SEND CLAIM_WITHOUT_LEASE SWALLOW_OUTBOX_FAILURE)
ORACLES=(CLOSED_WITHOUT_OUTBOX GHOST_EVENT_AFTER_ROLLBACK DUPLICATE_DELIVERY_EXPECTED DUPLICATE_CONSUMER_EFFECT VERSION_GUESSED EVENT_LOST OUTBOX_STUCK PARTIAL_COMMIT)
for index in "${!FAULTS[@]}"; do
  actual="$(java -cp "$BUILD_DIR/classes" DomainEventsOutboxFaultLab "${FAULTS[$index]}")"
  if [[ "$actual" != "${ORACLES[$index]}" ]]; then
    echo "fault ${FAULTS[$index]} did not expose ${ORACLES[$index]}: $actual" >&2
    exit 1
  fi
done
if rg -n '(java\.net|HttpClient|Socket|BEGIN (RSA|EC|OPENSSH) PRIVATE KEY)' "$ROOT_DIR/src"; then
  echo "network primitive or secret material found" >&2
  exit 1
fi
echo "LAB PASS jdk=25 mode=offline fault_oracles=8"
