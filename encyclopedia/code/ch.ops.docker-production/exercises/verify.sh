#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
STARTER_SHA256="1058f8d29a413edad82e14f1a7d97f8327ca4df0508b9d56c1cb6bafaa7566e5"
ORACLE_SHA256="a6f4730fdb9264ecec2c12cc0aacd9809971bb5975de901a68772880162f2e31"
hash_file() { python3 - "$1" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
}
[[ "$(hash_file test_audit.py)" == "$ORACLE_SHA256" ]] || { echo 'EXERCISE_ORACLE_CHANGED chapter=ch.ops.docker-production' >&2; exit 43; }
log="$(mktemp "${TMPDIR:-/tmp}/factorycare-docker-exercise.XXXXXX")"; trap 'rm -f "$log"' EXIT
set +e; PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -v >"$log" 2>&1; rc=$?; set -e
cat "$log"
if [[ $rc -eq 0 ]]; then echo 'EXERCISE_GREEN chapter=ch.ops.docker-production oracle=completed-solution'; exit 0; fi
if [[ $rc -eq 1 && "$(hash_file audit.py)" == "$STARTER_SHA256" ]]; then echo 'EXPECTED_RED chapter=ch.ops.docker-production oracle=verified-starter-failure'; exit 41; fi
echo "EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.ops.docker-production actual_status=$rc" >&2; exit 43
