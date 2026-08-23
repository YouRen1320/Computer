#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
/usr/bin/ruby --disable-gems ../../../examples/encyclopedia/ch.foundations.git-collaboration-security/verify.rb
test -s git-evidence.txt
test -s worksheet.md
