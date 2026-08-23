#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

ruby ../../../exercises/encyclopedia/ch.css.theme-variables/oracle.rb | diff -u expected.out -
