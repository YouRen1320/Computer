#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"
uv run --python 3.14 --with pydantic==2.13.4 --with pytest==9.1.1 pytest -q
printf '%s\n' 'LAB_GREEN valid/missing/enum/extra/version/non-JSON/refusal/incomplete verified'
