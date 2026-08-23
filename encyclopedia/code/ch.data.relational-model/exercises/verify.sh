#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ch-data-relational-model.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
STARTER_SENTINEL='answer-error=work order row meaning'
STARTER_SHA256='b3b53dd1f6e16cf273d79377ffc334ebbbb600886af9b954efcb83f5e7e8bed4'
STARTER_INPUTS=("$ROOT/answer.json")

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
ruby "$ROOT/oracle.rb" "$ROOT/answer.json" >"$TMP_ROOT/oracle.out" 2>&1
oracle_status=$?
set -e

if [[ $oracle_status -eq 0 ]]; then
  cat "$TMP_ROOT/oracle.out"
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.data.relational-model oracle=public-answer-accepted'
  exit 0
fi

if [[ $oracle_status -eq 1 ]] \
    && [[ "$current_sha256" == "$STARTER_SHA256" ]] \
    && grep -Fq "$STARTER_SENTINEL" "$TMP_ROOT/oracle.out"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.data.relational-model oracle=verified-starter-failure'
  exit 41
fi

cat "$TMP_ROOT/oracle.out" >&2
printf 'UNKNOWN_STATE chapter=ch.data.relational-model oracle_exit=%s expected=0-or-exact-starter\n' "$oracle_status" >&2
exit 43
