#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

NODE_PATH="$(command -v node)"
NODE_VERSION="$(node --version)"
NODE_MAJOR="$(node -p 'Number(process.versions.node.split(".")[0])')"

if (( NODE_MAJOR < 22 )); then
  echo "FAIL runtime-esm example: Node >=22 required, got $NODE_VERSION at $NODE_PATH" >&2
  exit 1
fi

grep -Fq '"type": "module"' "$ROOT/package.json"
grep -Fq '"packageManager": "pnpm@11.9.0"' "$ROOT/package.json"
node --check "$ROOT/src/status-label.mjs"
node --check "$ROOT/src/main.mjs"
node "$ROOT/src/main.mjs" >"$TMP_DIR/actual.stdout" 2>"$TMP_DIR/actual.stderr"
cmp "$ROOT/expected.stdout" "$TMP_DIR/actual.stdout"
test ! -s "$TMP_DIR/actual.stderr"

echo "PASS runtime-esm example node=$NODE_VERSION path=$NODE_PATH exit=0"
echo "RUNTIME_ESM_EXAMPLE_GREEN contract=verified"
