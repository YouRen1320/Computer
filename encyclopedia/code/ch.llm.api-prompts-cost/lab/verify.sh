#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"
uv run --python 3.14 --with pytest==9.1.1 pytest -q
printf '%s\n' 'LAB_GREEN mock success, usage invariants, authentication failure and rate limit verified'
