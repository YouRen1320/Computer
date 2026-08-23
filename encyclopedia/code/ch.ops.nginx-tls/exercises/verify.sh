#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
STARTER_SHA256="4b8c1b67cbf343c2c54692b8f3cec65b89fa4556d667722aca6a4b8d7ed39e4c"
ORACLE_SHA256="f6e7f6db98be5bb64e25868627e4ad7335e87344401b7437809451224ea512e0"
hash_file() { python3 - "$1" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
}
[[ "$(hash_file test_audit.py)" == "$ORACLE_SHA256" ]] || { echo 'EXERCISE_ORACLE_CHANGED chapter=ch.ops.nginx-tls' >&2; exit 43; }
log="$(mktemp "${TMPDIR:-/tmp}/factorycare-nginx-exercise.XXXXXX")"; trap 'rm -f "$log"' EXIT
set +e; PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -v >"$log" 2>&1; rc=$?; set -e
cat "$log"
if [[ $rc -eq 0 ]]; then echo 'EXERCISE_GREEN chapter=ch.ops.nginx-tls oracle=completed-solution'; exit 0; fi
if [[ $rc -eq 1 && "$(hash_file audit.py)" == "$STARTER_SHA256" ]]; then echo 'EXPECTED_RED chapter=ch.ops.nginx-tls oracle=verified-starter-failure'; exit 41; fi
echo "EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.ops.nginx-tls actual_status=$rc" >&2; exit 43
