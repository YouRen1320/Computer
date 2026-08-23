#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
STARTER_SHA256="e7bc8a27c836f6a6158efd03a93597359030cea5bf7b548dd678e5334cc6ef3d"
ORACLE_SHA256="11a09b6f2f8f3b66032c28b547f5e4068b5e0cc5d39ebc9deac7784a5eca2ca5"
hash_file() { python3 - "$1" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
}
[[ "$(hash_file test_exercise.py)" == "$ORACLE_SHA256" ]] || { echo 'EXERCISE_ORACLE_CHANGED chapter=ch.llm.api-prompts-cost' >&2; exit 43; }
log="$(mktemp "${TMPDIR:-/tmp}/factorycare-llm-api-exercise.XXXXXX")"; trap 'rm -f "$log"' EXIT
set +e; uv run --python 3.14 --with pytest==9.1.1 pytest -q -p no:cacheprovider >"$log" 2>&1; rc=$?; set -e
cat "$log"
if [[ $rc -eq 0 ]]; then echo 'EXERCISE_GREEN chapter=ch.llm.api-prompts-cost oracle=completed-solution'; exit 0; fi
if [[ $rc -eq 1 && "$(hash_file exercise.py)" == "$STARTER_SHA256" ]]; then echo 'EXPECTED_RED chapter=ch.llm.api-prompts-cost oracle=verified-starter-failure'; exit 41; fi
echo "EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.llm.api-prompts-cost actual_status=$rc" >&2; exit 43
