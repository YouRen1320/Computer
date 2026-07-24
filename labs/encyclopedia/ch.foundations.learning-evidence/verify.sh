#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
ruby ../../../examples/encyclopedia/ch.foundations.learning-evidence/verify.rb \
  ../../../examples/encyclopedia/ch.foundations.learning-evidence/valid-ledger.yml
test -s starter-ledger.yml
test -s faulty-ledger.yml
