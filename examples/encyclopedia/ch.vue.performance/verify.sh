#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export CI=true
cleanup() { rm -rf node_modules dist; }
trap cleanup EXIT
pnpm install --offline --frozen-lockfile --ignore-scripts
pnpm run build
pnpm run budget
