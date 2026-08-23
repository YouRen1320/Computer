#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ch-data-dml.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
STARTER_SENTINEL='answer-error=versioned UPDATE must include device_id and version predicate'
STARTER_SHA256='be7f126eb60b140e9f523f86aa21dbd17ac6973f65e5547ceabef37af00fce84'
STARTER_INPUTS=("$ROOT/answer.sql")

if ! command -v ruby >/dev/null 2>&1; then
  printf '%s\n' 'UNKNOWN_STATE dependency=ruby status=not-found' >&2
  exit 43
fi

for input in "${STARTER_INPUTS[@]}"; do
  if [[ ! -f "$input" ]]; then
    printf 'UNKNOWN_STATE missing-input=%s\n' "$input" >&2
    exit 43
  fi
done
current_sha256=$(ruby -rdigest -e '
  digest = Digest::SHA256.new
  ARGV.each do |path|
    bytes = File.binread(path)
    digest << [bytes.bytesize].pack("Q>") << bytes
  end
  print digest.hexdigest
' "${STARTER_INPUTS[@]}")

set +e
ruby "$ROOT/oracle.rb" "$ROOT/answer.sql" >"$TMP_ROOT/oracle.out" 2>&1
oracle_status=$?
set -e

if [[ $oracle_status -eq 0 ]]; then
  cat "$TMP_ROOT/oracle.out"
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.data.dml oracle=public-answer-accepted'
  exit 0
fi

if [[ $oracle_status -eq 1 ]] \
    && [[ "$current_sha256" == "$STARTER_SHA256" ]] \
    && grep -Fq "$STARTER_SENTINEL" "$TMP_ROOT/oracle.out"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.data.dml oracle=verified-starter-failure'
  exit 41
fi

cat "$TMP_ROOT/oracle.out" >&2
printf 'UNKNOWN_STATE chapter=ch.data.dml oracle_exit=%s expected=0-or-exact-starter\n' "$oracle_status" >&2
exit 43
