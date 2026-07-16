#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/ModularMonolithFaultLab.java"
java -cp "$BUILD_DIR/classes" ModularMonolithFaultLab > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out" || { diff -u "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"; exit 1; }
FAULTS=(DIRECT_REPOSITORY_ACCESS REVERSE_DEPENDENCY SHARED_ENTITY UNDECLARED_EDGE COMMON_BUSINESS_SERVICE SYNC_DERIVED_LISTENER FULL_CONTEXT_ONLY DIRECTORY_COUNT_SPLIT)
ORACLES=(INTERNAL_ACCESS MODULE_CYCLE SHARED_MUTABLE_ENTITY UNDECLARED_DEPENDENCY HIDDEN_BUSINESS_MODULE DERIVED_FAILURE_ROLLS_BACK_CORE MODULE_NOT_ISOLATABLE UNSUPPORTED_SPLIT_SIGNAL)
for index in "${!FAULTS[@]}"; do
  actual="$(java -cp "$BUILD_DIR/classes" ModularMonolithFaultLab "${FAULTS[$index]}")"
  [[ "$actual" == "${ORACLES[$index]}" ]] || { echo "fault ${FAULTS[$index]} did not expose ${ORACLES[$index]}: $actual" >&2; exit 1; }
done
if rg -n '(java\.net|HttpClient|Socket|BEGIN (RSA|EC|OPENSSH) PRIVATE KEY)' "$ROOT_DIR/src"; then echo "network primitive or secret material found" >&2; exit 1; fi
echo "LAB PASS jdk=25 mode=offline fault_oracles=8"
