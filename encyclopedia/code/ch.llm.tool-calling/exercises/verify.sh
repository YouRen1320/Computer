#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
STARTER_SHA256="ef965c3b6212c193d9bb5d6752e705a7b6bb3b6d43fc8b05b8a9be75a035626d"
ORACLE_SHA256="1be1ea0ef6c609cb9fa2d1c81331150fdad407bb25de412605811d8f70bb7760"
hash_file() { python3 - "$1" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
}
[[ "$(hash_file test_exercise.py)" == "$ORACLE_SHA256" ]] || { echo 'EXERCISE_ORACLE_CHANGED chapter=ch.llm.tool-calling' >&2; exit 43; }
log="$(mktemp "${TMPDIR:-/tmp}/factorycare-llm-tools-exercise.XXXXXX")"; trap 'rm -f "$log"' EXIT
set +e; uv run --python 3.14 --with pydantic==2.13.4 --with pytest==9.1.1 pytest -q -p no:cacheprovider >"$log" 2>&1; rc=$?; set -e
cat "$log"
if [[ $rc -eq 0 ]]; then echo 'EXERCISE_GREEN chapter=ch.llm.tool-calling oracle=completed-solution'; exit 0; fi
if [[ $rc -eq 1 && "$(hash_file exercise.py)" == "$STARTER_SHA256" ]]; then echo 'EXPECTED_RED chapter=ch.llm.tool-calling oracle=verified-starter-failure'; exit 41; fi
echo "EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.llm.tool-calling actual_status=$rc" >&2; exit 43
