#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
ruby ../../../exercises/encyclopedia/ch.web.media-assets/oracle.rb answer.html answer.json | diff -u expected.out -
printf '%s\n' 'MEDIA_ASSETS_SOLUTION=PASS'
