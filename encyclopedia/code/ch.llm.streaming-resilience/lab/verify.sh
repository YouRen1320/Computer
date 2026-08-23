#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"
uv run --python 3.14 --with pytest==9.1.1 --with pytest-asyncio==1.3.0 pytest -q
printf '%s\n' 'LAB_GREEN timeout/partial/429/cancel/fallback contracts verified'
