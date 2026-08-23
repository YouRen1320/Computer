#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
STARTER_SHA256="255b4cf75c64d0d72d43ff94641dc1e3068b560c0215b428763a6f8d9ce5e69d"
ORACLE_SHA256="e25f83888d1f040539c9c9b0b7bee82e7e9922200b22e49f26131439c3472990"
hash_file() { python3 - "$1" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
}
[[ "$(hash_file test_exercise.py)" == "$ORACLE_SHA256" ]] || { echo 'EXERCISE_ORACLE_CHANGED chapter=ch.llm.structured-output' >&2; exit 43; }
log="$(mktemp "${TMPDIR:-/tmp}/factorycare-llm-structured-exercise.XXXXXX")"; trap 'rm -f "$log"' EXIT
set +e; uv run --python 3.14 --with pydantic==2.13.4 --with pytest==9.1.1 pytest -q -p no:cacheprovider >"$log" 2>&1; rc=$?; set -e
cat "$log"
if [[ $rc -eq 0 ]]; then echo 'EXERCISE_GREEN chapter=ch.llm.structured-output oracle=completed-solution'; exit 0; fi
if [[ $rc -eq 1 && "$(hash_file exercise.py)" == "$STARTER_SHA256" ]]; then echo 'EXPECTED_RED chapter=ch.llm.structured-output oracle=verified-starter-failure'; exit 41; fi
echo "EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.llm.structured-output actual_status=$rc" >&2; exit 43
