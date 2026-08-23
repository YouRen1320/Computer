#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

NODE_VERSION="$(node --version)"
NODE_MAJOR="$(node -p 'Number(process.versions.node.split(".")[0])')"
if (( NODE_MAJOR < 22 )); then
  echo "FAIL runtime-esm lab: Node >=22 required, got $NODE_VERSION" >&2
  exit 1
fi

node "$ROOT/src/main.mjs" >"$TMP_DIR/baseline.stdout" 2>"$TMP_DIR/baseline.stderr"
cmp "$ROOT/expected.stdout" "$TMP_DIR/baseline.stdout"
test ! -s "$TMP_DIR/baseline.stderr"

wrong_type_exit=0
node "$ROOT/faults/wrong-package-type.cjs" >"$TMP_DIR/type.stdout" 2>"$TMP_DIR/type.stderr" || wrong_type_exit=$?
if (( wrong_type_exit == 0 )); then
  echo "FAIL runtime-esm lab: wrong package type did not fail" >&2
  exit 1
fi
grep -Fq 'SyntaxError' "$TMP_DIR/type.stderr"
grep -Fq 'Cannot use import statement outside a module' "$TMP_DIR/type.stderr"
test ! -s "$TMP_DIR/type.stdout"

missing_extension_exit=0
node "$ROOT/faults/missing-extension.mjs" >"$TMP_DIR/path.stdout" 2>"$TMP_DIR/path.stderr" || missing_extension_exit=$?
if (( missing_extension_exit == 0 )); then
  echo "FAIL runtime-esm lab: missing extension did not fail" >&2
  exit 1
fi
grep -Fq 'ERR_MODULE_NOT_FOUND' "$TMP_DIR/path.stderr"
test ! -s "$TMP_DIR/path.stdout"

grep -Fq 'expected_node_major=24' "$ROOT/fixtures/toolchain-drift.txt"
grep -Fq 'observed_node_major=22' "$ROOT/fixtures/toolchain-drift.txt"
grep -Fq 'expected_pnpm_major=11' "$ROOT/fixtures/toolchain-drift.txt"
grep -Fq 'observed_pnpm_major=10' "$ROOT/fixtures/toolchain-drift.txt"

echo "PASS runtime-esm lab baseline=0 package_type=$wrong_type_exit module_path=$missing_extension_exit drift=detected node=$NODE_VERSION"
