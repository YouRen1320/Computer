#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export CI=true
cleanup() { rm -rf node_modules dist; }
trap cleanup EXIT
pnpm install --offline --frozen-lockfile --ignore-scripts --reporter=silent
pnpm exec vite build --logLevel silent
pnpm run budget
