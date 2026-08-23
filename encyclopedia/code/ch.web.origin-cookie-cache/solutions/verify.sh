#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
ruby ../../../exercises/encyclopedia/ch.web.origin-cookie-cache/oracle.rb answer.json | diff -u expected.out -
printf '%s\n' 'ORIGIN_COOKIE_CACHE_SOLUTION=PASS'
