#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
STARTER_SHA256="47d4b95aab56c8b69dd6c3f083eda174a91e98bace273eb377ed9bfb3eb05f14"
ORACLE_SHA256="e7f187d1c69e10a9b124dc3c62504f17647cb9062cf9a07a8b5f8d944594c24b"
hash_file() { python3 - "$1" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
}
oracle_hash="$(hash_file test_audit.py)"
[[ "$oracle_hash" == "$ORACLE_SHA256" ]] || { echo 'EXERCISE_ORACLE_CHANGED chapter=ch.ops.compose-services' >&2; exit 43; }
log="$(mktemp "${TMPDIR:-/tmp}/factorycare-compose-exercise.XXXXXX")"; trap 'rm -f "$log"' EXIT
set +e; PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -v >"$log" 2>&1; rc=$?; set -e
cat "$log"
if [[ $rc -eq 0 ]]; then echo 'EXERCISE_GREEN chapter=ch.ops.compose-services oracle=completed-solution'; exit 0; fi
if [[ $rc -eq 1 && "$(hash_file audit.py)" == "$STARTER_SHA256" ]]; then echo 'EXPECTED_RED chapter=ch.ops.compose-services oracle=verified-starter-failure'; exit 41; fi
echo "EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.ops.compose-services actual_status=$rc" >&2; exit 43
