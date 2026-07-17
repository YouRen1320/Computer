#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! grep -Fq '"type": "module"' "$ROOT/package.json"; then
  echo "RUNTIME_ESM_EXERCISE_RED: PACKAGE_TYPE_NOT_MODULE" >&2
  exit 1
fi

if ! grep -Fq 'from "./status-label.js"' "$ROOT/src/main.js"; then
  echo "RUNTIME_ESM_EXERCISE_RED: RELATIVE_IMPORT_NEEDS_EXTENSION" >&2
  exit 1
fi

if ! grep -Fq 'import { statusLabel }' "$ROOT/src/main.js"; then
  echo "RUNTIME_ESM_EXERCISE_RED: NAMED_EXPORT_MISMATCH" >&2
  exit 1
fi

node --check "$ROOT/src/status-label.js"
node --check "$ROOT/src/main.js"
node "$ROOT/src/main.js" >"$TMP_DIR/actual.stdout" 2>"$TMP_DIR/actual.stderr"
cmp "$ROOT/expected.stdout" "$TMP_DIR/actual.stdout"
test ! -s "$TMP_DIR/actual.stderr"

echo "PASS runtime-esm exercise exit=0"
