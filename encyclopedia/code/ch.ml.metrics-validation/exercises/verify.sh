#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
STARTER_SHA256="5e5d7839aeb5dbdbb70a913002ecbd6b6b85ccf708c7a9171dc1d3800fcd73bf"
ORACLE_SHA256="caed3a126ec783528382e2d6821b0e48159cd5c0dbe20f02fba691e91c3549a5"
hash_file() { python3 - "$1" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
}
[[ "$(hash_file test_exercise.py)" == "$ORACLE_SHA256" ]] || { echo 'EXERCISE_ORACLE_CHANGED chapter=ch.ml.metrics-validation' >&2; exit 43; }
log="$(mktemp "${TMPDIR:-/tmp}/factorycare-ml-metrics.XXXXXX")"; trap 'rm -f "$log"' EXIT
set +e; uv run --isolated --with 'numpy==2.5.0' --with 'pandas==3.0.5' --with 'pytest==9.1.1' pytest -q -p no:cacheprovider >"$log" 2>&1; rc=$?; set -e
cat "$log"
if [[ $rc -eq 0 ]]; then echo 'EXERCISE_GREEN chapter=ch.ml.metrics-validation oracle=completed-solution'; exit 0; fi
if [[ $rc -eq 1 && "$(hash_file exercise.py)" == "$STARTER_SHA256" ]]; then echo 'EXPECTED_RED chapter=ch.ml.metrics-validation oracle=verified-starter-failure'; exit 41; fi
echo "EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.ml.metrics-validation actual_status=$rc" >&2; exit 43
