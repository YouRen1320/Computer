#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
STARTER_SHA256="8baff353b11ffeb9ba7b959193119085822f244dcc8e6ddebaaf32ada4cf967d"
ORACLE_SHA256="69c1c7816236874be2e25dbe9b4a7405f50de783c97f580668dd919d7d5689ff"
hash_file() { python3 - "$1" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
}
[[ "$(hash_file test_exercise.py)" == "$ORACLE_SHA256" ]] || { echo 'EXERCISE_ORACLE_CHANGED chapter=ch.llm.streaming-resilience' >&2; exit 43; }
log="$(mktemp "${TMPDIR:-/tmp}/factorycare-llm-stream-exercise.XXXXXX")"; trap 'rm -f "$log"' EXIT
set +e; uv run --python 3.14 --with pytest==9.1.1 --with pytest-asyncio==1.3.0 pytest -q -p no:cacheprovider >"$log" 2>&1; rc=$?; set -e
cat "$log"
if [[ $rc -eq 0 ]]; then echo 'EXERCISE_GREEN chapter=ch.llm.streaming-resilience oracle=completed-solution'; exit 0; fi
if [[ $rc -eq 1 && "$(hash_file exercise.py)" == "$STARTER_SHA256" ]]; then echo 'EXPECTED_RED chapter=ch.llm.streaming-resilience oracle=verified-starter-failure'; exit 41; fi
echo "EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.llm.streaming-resilience actual_status=$rc" >&2; exit 43
