#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
ruby ../../../exercises/encyclopedia/ch.web.semantic-html/oracle.rb answer.html | diff -u expected.out -
printf '%s\n' 'SEMANTIC_HTML_SOLUTION=PASS'
