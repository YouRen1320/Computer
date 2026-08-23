#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
ruby verify.rb telemetry.json | diff -u expected.out -
printf '%s\n' 'EXAMPLE_VERIFIER=PASS'
