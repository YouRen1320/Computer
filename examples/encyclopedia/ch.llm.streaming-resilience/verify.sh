#!/bin/sh
set -eu
cd "$(dirname "$0")"
uv run --python 3.14 python demo.py
printf '%s\n' 'EXAMPLE_GREEN typed stream completion verified'
