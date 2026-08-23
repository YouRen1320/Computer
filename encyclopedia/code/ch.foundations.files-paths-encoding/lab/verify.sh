#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
ruby ../../../examples/encyclopedia/ch.foundations.files-paths-encoding/verify.rb
test -s workspace/tree.md
test -s worksheet.md
