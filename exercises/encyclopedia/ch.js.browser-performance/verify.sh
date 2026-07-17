#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

cleanup() {
  rm -rf "$ROOT_DIR/node_modules"
}
trap cleanup EXIT

cd "$ROOT_DIR"
pnpm install --offline --frozen-lockfile --ignore-scripts >/dev/null
node --check src/exercise.mjs
node src/exercise.mjs

