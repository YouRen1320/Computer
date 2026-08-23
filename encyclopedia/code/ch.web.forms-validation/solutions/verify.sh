#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
ruby ../../../exercises/encyclopedia/ch.web.forms-validation/oracle.rb answer.html answer.json | diff -u expected.out -
printf '%s\n' 'FORMS_VALIDATION_SOLUTION=PASS'
