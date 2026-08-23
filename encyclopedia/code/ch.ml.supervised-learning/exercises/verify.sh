#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
STARTER_SHA256="a73f01b7cf60457e87dd5e93fa44b2410ec3ecf08ab5ae1e2c8005983dbc8357"
ORACLE_SHA256="09ab0382bfbfac631e2c27542ed37ae3132327d8da57b28a67ec4388e13661b4"
hash_file() { python3 - "$1" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
}
[[ "$(hash_file test_exercise.py)" == "$ORACLE_SHA256" ]] || { echo 'EXERCISE_ORACLE_CHANGED chapter=ch.ml.supervised-learning' >&2; exit 43; }
log="$(mktemp "${TMPDIR:-/tmp}/factorycare-ml-supervised.XXXXXX")"; trap 'rm -f "$log"' EXIT
set +e; uv run --isolated --with 'numpy==2.5.0' --with 'pandas==3.0.5' --with 'pytest==9.1.1' pytest -q -p no:cacheprovider >"$log" 2>&1; rc=$?; set -e
cat "$log"
if [[ $rc -eq 0 ]]; then echo 'EXERCISE_GREEN chapter=ch.ml.supervised-learning oracle=completed-solution'; exit 0; fi
if [[ $rc -eq 1 && "$(hash_file exercise.py)" == "$STARTER_SHA256" ]]; then echo 'EXPECTED_RED chapter=ch.ml.supervised-learning oracle=verified-starter-failure'; exit 41; fi
echo "EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.ml.supervised-learning actual_status=$rc" >&2; exit 43
