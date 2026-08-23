#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -v
printf '%s\n' 'PASS static Nginx policy solution'
printf '%s\n' 'UNVERIFIED nginx -t, live TLS chain/hostname, proxy headers and upstream response behavior'
