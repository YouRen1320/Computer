#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
bash -n serve.sh
server_check="$(bash serve.sh --check 4173)"
grep -Fq 'STATIC_SERVER_READY bind=127.0.0.1 port=4173' <<<"$server_check"
ruby oracle.rb | diff -u expected.out -
printf '%s\n' 'BROWSER_RENDER_EXAMPLE=PASS'
