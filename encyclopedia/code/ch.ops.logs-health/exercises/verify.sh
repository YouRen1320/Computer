#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
STARTER_SHA256="dbc64278ce26ffa843f6cb2a3d1094b86d49ca6853af248a87745705e451d8b3"
ORACLE_SHA256="353bb1bbd9f1710b50784e887c1b212f9b57c8f3c1af1aa5cbbd6e8d38382f88"
hash_file() { python3 - "$1" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
}
[[ "$(hash_file test_exercise.py)" == "$ORACLE_SHA256" ]] || { echo 'EXERCISE_ORACLE_CHANGED chapter=ch.ops.logs-health' >&2; exit 43; }
log="$(mktemp "${TMPDIR:-/tmp}/factorycare-logs-health-exercise.XXXXXX")"; trap 'rm -f "$log"' EXIT
set +e; PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -v >"$log" 2>&1; rc=$?; set -e
cat "$log"
if [[ $rc -eq 0 ]]; then echo 'EXERCISE_GREEN chapter=ch.ops.logs-health oracle=completed-solution'; exit 0; fi
if [[ $rc -eq 1 && "$(hash_file exercise.py)" == "$STARTER_SHA256" ]]; then echo 'EXPECTED_RED chapter=ch.ops.logs-health oracle=verified-starter-failure'; exit 41; fi
echo "EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.ops.logs-health actual_status=$rc" >&2; exit 43
