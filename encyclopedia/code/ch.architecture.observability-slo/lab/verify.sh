#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
ruby verify.rb faults.json | diff -u expected.out -
printf '%s\n' 'LAB_VERIFIER=PASS'
