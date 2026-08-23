#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"
uv run --python 3.14 --with pydantic==2.13.4 python demo.py
printf '%s\n' 'EXAMPLE_GREEN versioned strict schema verified'
