#!/bin/sh
set -eu
cd "$(dirname "$0")"
uv run --python 3.14 --with pytest==9.1.1 pytest -q
printf '%s\n' 'SOLUTION_GREEN corrected API boundary verified'
