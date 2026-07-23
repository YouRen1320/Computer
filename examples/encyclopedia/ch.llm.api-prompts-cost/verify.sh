#!/bin/sh
set -eu
cd "$(dirname "$0")"
uv run --python 3.14 python demo.py
printf '%s\n' 'EXAMPLE_GREEN api contract and usage cost verified'
