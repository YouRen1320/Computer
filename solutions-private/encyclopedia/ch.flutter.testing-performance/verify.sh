#!/usr/bin/env bash
set -euo pipefail
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/test-contract.env" <<'ENV'
ANIMATION=indeterminate
WAIT_STRATEGY=controlled-future-and-exact-pump
GOLDEN_FLUTTER=3.44.x-fixed-runner
GOLDEN_FONT_SHA=sha256-font-fixture-001
CONTROLLERS_CREATED=3
CONTROLLERS_DISPOSED=3
PROFILE_MODE=required-on-representative-device
ENV

grep -q '^WAIT_STRATEGY=controlled-future-and-exact-pump$' "$tmp_dir/test-contract.env"
grep -Eq '^GOLDEN_FLUTTER=3\.44\.x-' "$tmp_dir/test-contract.env"
grep -Eq '^GOLDEN_FONT_SHA=sha256-' "$tmp_dir/test-contract.env"
created="$(sed -n 's/^CONTROLLERS_CREATED=//p' "$tmp_dir/test-contract.env")"
disposed="$(sed -n 's/^CONTROLLERS_DISPOSED=//p' "$tmp_dir/test-contract.env")"
[[ "$created" == "$disposed" ]]
grep -q '^PROFILE_MODE=required-on-representative-device$' "$tmp_dir/test-contract.env"
echo 'FLUTTER_TESTING_PERFORMANCE_SOLUTION_PASS real_profile=false real_golden=false'
