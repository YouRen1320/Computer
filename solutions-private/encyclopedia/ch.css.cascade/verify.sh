#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
ruby ../../../exercises/encyclopedia/ch.css.cascade/oracle.rb answer.html answer.css answer.json | diff -u expected.out -
printf '%s\n' 'CSS_CASCADE_PRIVATE_VERIFY=PASS'
