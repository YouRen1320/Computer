#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
ruby scripts/check_tree.rb
