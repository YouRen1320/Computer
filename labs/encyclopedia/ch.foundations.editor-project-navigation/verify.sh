#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
ruby ../../../examples/encyclopedia/ch.foundations.editor-project-navigation/verify.rb
test -s navigation-evidence.txt
test -s problems.txt
