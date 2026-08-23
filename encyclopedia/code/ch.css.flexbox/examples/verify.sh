#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
ruby oracle.rb | diff -u expected.out -
printf '%s\n' 'CSS_FLEXBOX_EXAMPLE_VERIFY=PASS'
