#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
ruby ../../../exercises/encyclopedia/ch.web.accessibility-interaction/oracle.rb answer.html answer.js answer.json | diff -u expected.out -
printf '%s\n' 'ACCESSIBILITY_INTERACTION_SOLUTION=PASS'
