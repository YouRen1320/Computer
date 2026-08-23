#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
ruby ../../../exercises/encyclopedia/ch.web.browser-render-devtools/oracle.rb answer.json | diff -u expected.out -
printf '%s\n' 'BROWSER_RENDER_SOLUTION=PASS'
