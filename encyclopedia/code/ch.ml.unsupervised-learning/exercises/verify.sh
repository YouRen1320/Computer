#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
STARTER_SHA256="473263b9517a0a7a50de86c716f3415510667a3ffd2c86239bfb799e64c3c6a7"
ORACLE_SHA256="50e1022e81f36a861c7b816f8aacc04c6b1872769cb445965721451f421d9288"
hash_file() { python3 - "$1" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
}
[[ "$(hash_file test_exercise.py)" == "$ORACLE_SHA256" ]] || { echo 'EXERCISE_ORACLE_CHANGED chapter=ch.ml.unsupervised-learning' >&2; exit 43; }
log="$(mktemp "${TMPDIR:-/tmp}/factorycare-ml-unsupervised.XXXXXX")"; trap 'rm -f "$log"' EXIT
set +e; uv run --isolated --with 'numpy==2.5.0' --with 'pandas==3.0.5' --with 'pytest==9.1.1' pytest -q -p no:cacheprovider >"$log" 2>&1; rc=$?; set -e
cat "$log"
if [[ $rc -eq 0 ]]; then echo 'EXERCISE_GREEN chapter=ch.ml.unsupervised-learning oracle=completed-solution'; exit 0; fi
if [[ $rc -eq 1 && "$(hash_file exercise.py)" == "$STARTER_SHA256" ]]; then echo 'EXPECTED_RED chapter=ch.ml.unsupervised-learning oracle=verified-starter-failure'; exit 41; fi
echo "EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.ml.unsupervised-learning actual_status=$rc" >&2; exit 43
