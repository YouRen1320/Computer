#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$ROOT_DIR/.verify.log"
STARTER_SOURCE_SHA256="857ed3b9849d34cca3e4f56cbc67d9642f49861d47bbb3413ba9720aa2a43359"

sha256_stream() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    return 127
  fi
}

source_tree_sha256() {
  local file relative digest manifest=""
  while IFS= read -r file; do
    relative=${file#"$ROOT_DIR/"}
    digest="$(sha256_stream <"$file")" || return $?
    manifest="${manifest}${relative}:${digest}"$'\n'
  done < <(find "$ROOT_DIR/src/main" -type f -print | LC_ALL=C sort)
  [[ -n "$manifest" ]] || return 1
  printf '%s' "$manifest" | sha256_stream
}

if ! current_source_sha256="$(source_tree_sha256)"; then
  echo "UNKNOWN_STATE chapter=ch.spring.aop-proxy-model phase=starter-fingerprint" >&2
  exit 43
fi
starter_sources_match=0
if [[ "$current_source_sha256" == "$STARTER_SOURCE_SHA256" ]]; then
  starter_sources_match=1
fi
SENTINEL="EXPECTED_EXCEPTION_PROPAGATION"
EXPECTED_TESTS=2

case "$(mvn -v 2>&1)" in
  *"Apache Maven 3.9.16"*"Java version: 25."*) ;;
  *)
    echo "UNKNOWN_STATE expected=Maven-3.9.16-on-JDK-25" >&2
    exit 43
    ;;
esac

cd "$ROOT_DIR"
rm -f "$LOG_FILE"
set +e
mvn --offline --batch-mode --no-transfer-progress clean test >"$LOG_FILE" 2>&1
STATUS=$?
set -e

if [[ $STATUS -eq 0 ]]; then
  if ! grep -Fq "Tests run: $EXPECTED_TESTS, Failures: 0, Errors: 0, Skipped: 0" "$LOG_FILE"; then
    cat "$LOG_FILE" >&2
    echo "UNKNOWN_STATE green-summary-mismatch expected=tests:$EXPECTED_TESTS/failures:0/errors:0/skipped:0" >&2
    exit 43
  fi
  echo "EXERCISE_GREEN chapter=ch.spring.aop-proxy-model state=completed tests=$EXPECTED_TESTS failures=0 errors=0 skipped=0 mode=offline"
  exit 0
fi

if [[ $starter_sources_match -eq 1 ]] \
    && [[ $STATUS -eq 1 ]] \
    && grep -Fq "Tests run: $EXPECTED_TESTS, Failures: 1, Errors: 0, Skipped: 0" "$LOG_FILE" \
    && grep -Fq "$SENTINEL" "$LOG_FILE"; then
  echo "EXPECTED_RED chapter=ch.spring.aop-proxy-model first=$SENTINEL tests=$EXPECTED_TESTS failures=1 errors=0 skipped=0 mode=offline"
  exit 41
fi

cat "$LOG_FILE" >&2
echo "UNKNOWN_STATE chapter=ch.spring.aop-proxy-model maven_exit=$STATUS expected=completed-or-exact-starter" >&2
exit 43
