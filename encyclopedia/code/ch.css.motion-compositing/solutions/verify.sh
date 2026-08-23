#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

ruby ../../../exercises/encyclopedia/ch.css.motion-compositing/oracle.rb | diff -u expected.out -
