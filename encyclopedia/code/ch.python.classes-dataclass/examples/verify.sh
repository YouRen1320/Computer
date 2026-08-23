#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
cd "$(dirname "$0")"
command -v uvx >/dev/null || { echo "uvx is required" >&2; exit 2; }
uvx --from mypy==2.3.0 mypy --strict --no-incremental --cache-dir=/dev/null --python-version 3.14 model.py verify.py
negative_log="$(mktemp "${TMPDIR:-/tmp}/factorycare-classes-type-negative.XXXXXX")"
cleanup_negative_log() { rm -f "$negative_log"; }
trap cleanup_negative_log EXIT HUP INT TERM
set +e
uvx --from mypy==2.3.0 mypy --strict --no-incremental --cache-dir=/dev/null --python-version 3.14 typing_failure.py >"$negative_log" 2>&1
negative_status=$?
set -e
if [[ "$negative_status" -ne 1 ]] ||
   ! grep -Fq -- '[assignment]' "$negative_log" ||
   ! grep -Fq -- '[arg-type]' "$negative_log"; then
  cat "$negative_log" >&2
  echo "expected locked assignment and arg-type diagnostics" >&2
  exit 1
fi
python3 verify.py
