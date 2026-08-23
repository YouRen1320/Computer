#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$ROOT_DIR/.verify.log"
EXPECTED_TESTS=5
STARTER_SOURCE_SHA256="32634b6a59e46720c5b30431ef41119244d21218080856522bb017accea6fd4d"

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
  done < <(find "$ROOT_DIR/src" -type f -print | LC_ALL=C sort)
  [[ -n "$manifest" ]] || return 1
  printf '%s' "$manifest" | sha256_stream
}

if ! current_source_sha256="$(source_tree_sha256)"; then
  echo "UNKNOWN_STATE chapter=ch.java-engineering.testing-test-doubles phase=starter-fingerprint" >&2
  exit 43
fi
starter_sources_match=0
if [[ "$current_source_sha256" == "$STARTER_SOURCE_SHA256" ]]; then
  starter_sources_match=1
fi

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
status=$?
set -e
todo_count=$(
  { grep -R -h -c 'TODO' "$ROOT_DIR/src" 2>/dev/null || true; } \
    | awk '{ total += $1 } END { print total + 0 }'
)

if [[ $status -eq 0 ]] \
    && grep -Fq "Tests run: $EXPECTED_TESTS, Failures: 0, Errors: 0, Skipped: 0" "$LOG_FILE" \
    && [[ $todo_count -eq 0 ]]; then
  echo "EXERCISE_GREEN chapter=ch.java-engineering.testing-test-doubles tests=$EXPECTED_TESTS failures=0 errors=0 skipped=0 mode=offline"
  exit 0
fi

if [[ $starter_sources_match -eq 1 ]] \
    && [[ $status -eq 1 ]] \
    && grep -Fq "Tests run: $EXPECTED_TESTS, Failures: 2, Errors: 0, Skipped: 0" "$LOG_FILE" \
    && grep -Fq 'candidateFakePersistsObservableState' "$LOG_FILE" \
    && grep -Fq 'candidateSpyCapturesTheRequiredNotification' "$LOG_FILE" \
    && [[ $todo_count -eq 2 ]]; then
  echo "EXPECTED_RED chapter=ch.java-engineering.testing-test-doubles first=fake-and-spy-unimplemented tests=$EXPECTED_TESTS failures=2 errors=0 skipped=0 todos=2"
  exit 41
fi

cat "$LOG_FILE" >&2
echo "UNKNOWN_STATE chapter=ch.java-engineering.testing-test-doubles maven_exit=$status todos=$todo_count expected=completed-or-exact-starter" >&2
exit 43
