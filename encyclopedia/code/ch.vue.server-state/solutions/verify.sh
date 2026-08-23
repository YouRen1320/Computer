#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

node scripts/check-contract.mjs | diff -u expected.out -
