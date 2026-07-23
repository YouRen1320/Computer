#!/bin/sh
set -eu
cd "$(dirname "$0")"
uv run --python 3.14 --with pydantic==2.13.4 --with pytest==9.1.1 pytest -q
printf '%s\n' 'LAB_GREEN allowlist/schema/resource-auth/approval/idempotency verified'
