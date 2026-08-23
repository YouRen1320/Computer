#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

ruby oracle.rb | diff -u expected.out -
printf '%s\n' 'EXAMPLE_GREEN chapter=ch.css.motion-compositing oracle=expected-output-match'
