#!/bin/sh
set -eu
cd "$(dirname "$0")"
uv run --python 3.14 --with pytest==9.1.1 pytest -q
printf '%s\n' 'LAB_GREEN mock success, authentication failure and rate limit verified'
