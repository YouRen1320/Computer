#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
ruby ../../../exercises/encyclopedia/ch.architecture.observability-slo/verify.rb answer.json | diff -u expected.out -
printf '%s\n' 'SOLUTION_VERIFIER=PASS'
