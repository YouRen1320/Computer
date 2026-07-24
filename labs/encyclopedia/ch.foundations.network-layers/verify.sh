#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
ruby ../../../examples/encyclopedia/ch.foundations.network-layers/verify.rb
ruby run_lab.rb >/dev/null
