#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
ruby ../../../exercises/encyclopedia/ch.css.grid/oracle.rb answer.html answer.css answer.json | diff -u expected.out -
printf '%s\n' 'CSS_GRID_PRIVATE_VERIFY=PASS'
