#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
submission='test-contract.env'

required=(ANIMATION WAIT_STRATEGY GOLDEN_FLUTTER GOLDEN_FONT_SHA CONTROLLERS_CREATED CONTROLLERS_DISPOSED PROFILE_MODE)
for key in "${required[@]}"; do
  count="$(grep -c "^${key}=" "$submission" || true)"
  if [[ "$count" -ne 1 ]]; then
    echo "TEST_CONTRACT_SHAPE_MISMATCH key=$key count=$count" >&2
    exit 43
  fi
done
if grep -Ev '^(ANIMATION|WAIT_STRATEGY|GOLDEN_FLUTTER|GOLDEN_FONT_SHA|CONTROLLERS_CREATED|CONTROLLERS_DISPOSED|PROFILE_MODE)=[^[:cntrl:]]*$' "$submission" | grep -q .; then
  echo 'TEST_CONTRACT_SHAPE_MISMATCH unknown-or-malformed-line' >&2
  exit 43
fi

value() { sed -n "s/^$1=//p" "$submission"; }
animation="$(value ANIMATION)"
wait_strategy="$(value WAIT_STRATEGY)"
golden_flutter="$(value GOLDEN_FLUTTER)"
golden_font="$(value GOLDEN_FONT_SHA)"
created="$(value CONTROLLERS_CREATED)"
disposed="$(value CONTROLLERS_DISPOSED)"
profile_mode="$(value PROFILE_MODE)"

if [[ ! "$created" =~ ^[0-9]+$ ]] || [[ ! "$disposed" =~ ^[0-9]+$ ]]; then
  echo 'TEST_CONTRACT_SHAPE_MISMATCH controller counts must be integers' >&2
  exit 43
fi

issues=0
if [[ "$animation" == 'indeterminate' && "$wait_strategy" != 'controlled-future-and-exact-pump' ]]; then
  echo 'PUMP_SETTLE_EXERCISE infinite animation cannot settle' >&2
  issues=$((issues + 1))
fi
if [[ ! "$golden_flutter" =~ ^[0-9]+\.[0-9]+\.[0-9]+-fixed-runner$ ]] ||
   [[ ! "$golden_font" =~ ^sha256-[0-9a-f]{16,64}$ ]]; then
  echo 'GOLDEN_ENVIRONMENT_EXERCISE SDK/font fingerprint is not frozen' >&2
  issues=$((issues + 1))
fi
if [[ "$created" != "$disposed" ]]; then
  echo "CONTROLLER_LIFECYCLE_EXERCISE created=$created disposed=$disposed" >&2
  issues=$((issues + 1))
fi
if [[ "$profile_mode" != 'required-on-representative-device' ]]; then
  echo 'PERFORMANCE_MODE_EXERCISE debug/synthetic data cannot prove release performance' >&2
  issues=$((issues + 1))
fi
if [[ $issues -eq 0 ]]; then
  echo 'EXERCISE_GREEN chapter=ch.flutter.testing-performance oracle=completed-solution'
  exit 0
fi
echo "EXPECTED_FLUTTER_TESTING_PERFORMANCE_RED issues=$issues" >&2
echo 'EXPECTED_RED chapter=ch.flutter.testing-performance oracle=verified-starter-failure'
exit 41
