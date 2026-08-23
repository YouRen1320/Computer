#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
STARTER_SHA256="d7671b125d68b3533124ee61e91105bcd89b60efe49d556e77134a2f66f1765f"
ORACLE_SHA256="21162ef877951ddf0df946cbbc531efc253c918992ac027c15ee933a377076bd"
hash_file() { python3 - "$1" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
}
[[ "$(hash_file test_exercise.py)" == "$ORACLE_SHA256" ]] || { echo 'EXERCISE_ORACLE_CHANGED chapter=ch.ops.metrics-traces-slo' >&2; exit 43; }
log="$(mktemp "${TMPDIR:-/tmp}/factorycare-metrics-exercise.XXXXXX")"; trap 'rm -f "$log"' EXIT
set +e; PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -v >"$log" 2>&1; rc=$?; set -e
cat "$log"
if [[ $rc -eq 0 ]]; then echo 'EXERCISE_GREEN chapter=ch.ops.metrics-traces-slo oracle=completed-solution'; exit 0; fi
if [[ $rc -eq 1 && "$(hash_file exercise.py)" == "$STARTER_SHA256" ]]; then echo 'EXPECTED_RED chapter=ch.ops.metrics-traces-slo oracle=verified-starter-failure'; exit 41; fi
echo "EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.ops.metrics-traces-slo actual_status=$rc" >&2; exit 43
