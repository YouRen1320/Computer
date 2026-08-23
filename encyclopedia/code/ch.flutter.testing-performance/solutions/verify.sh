#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
file='solution.env'
value() { sed -n "s/^$1=//p" "$file"; }
[[ "$(value ANIMATION)" == 'indeterminate' ]]
[[ "$(value WAIT_STRATEGY)" == 'controlled-future-and-exact-pump' ]]
[[ "$(value GOLDEN_FLUTTER)" =~ ^[0-9]+\.[0-9]+\.[0-9]+-fixed-runner$ ]]
[[ "$(value GOLDEN_FONT_SHA)" =~ ^sha256-[0-9a-f]{16,64}$ ]]
[[ "$(value CONTROLLERS_CREATED)" == "$(value CONTROLLERS_DISPOSED)" ]]
[[ "$(value PROFILE_MODE)" == 'required-on-representative-device' ]]
echo 'FLUTTER_TESTING_PERFORMANCE_SOLUTION_PASS checks=6 real_profile=false real_golden=false'
