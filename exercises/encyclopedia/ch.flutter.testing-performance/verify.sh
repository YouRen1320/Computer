#!/usr/bin/env bash
set -euo pipefail
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/test-contract.env" <<'ENV'
ANIMATION=indeterminate
WAIT_STRATEGY=pumpAndSettle
GOLDEN_FLUTTER=unlocked
GOLDEN_FONT_SHA=missing
CONTROLLERS_CREATED=3
CONTROLLERS_DISPOSED=0
PROFILE_MODE=false
ENV

issues=0
if grep -q '^ANIMATION=indeterminate$' "$tmp_dir/test-contract.env" &&
   grep -q '^WAIT_STRATEGY=pumpAndSettle$' "$tmp_dir/test-contract.env"; then
  echo 'PUMP_SETTLE_EXERCISE infinite animation cannot settle' >&2
  issues=$((issues + 1))
fi
if grep -q '^GOLDEN_FLUTTER=unlocked$' "$tmp_dir/test-contract.env" ||
   grep -q '^GOLDEN_FONT_SHA=missing$' "$tmp_dir/test-contract.env"; then
  echo 'GOLDEN_ENVIRONMENT_EXERCISE SDK/font fingerprint is not frozen' >&2
  issues=$((issues + 1))
fi
created="$(sed -n 's/^CONTROLLERS_CREATED=//p' "$tmp_dir/test-contract.env")"
disposed="$(sed -n 's/^CONTROLLERS_DISPOSED=//p' "$tmp_dir/test-contract.env")"
if [[ "$created" != "$disposed" ]]; then
  echo "CONTROLLER_LIFECYCLE_EXERCISE created=$created disposed=$disposed" >&2
  issues=$((issues + 1))
fi
if grep -q '^PROFILE_MODE=false$' "$tmp_dir/test-contract.env"; then
  echo 'PERFORMANCE_MODE_EXERCISE debug/synthetic data cannot prove release performance' >&2
  issues=$((issues + 1))
fi
if [[ $issues -eq 0 ]]; then
  echo 'unexpected green: exercise faults were not detected' >&2
  exit 42
fi
echo "FLUTTER_TESTING_PERFORMANCE_EXERCISE_EXPECTED_RED issues=$issues" >&2
exit 41
