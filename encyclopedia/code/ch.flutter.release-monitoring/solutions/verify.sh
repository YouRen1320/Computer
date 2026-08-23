#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
file='solution.env'
value() { sed -n "s/^$1=//p" "$file"; }
flavor="$(value FLAVOR)"
version="$(value VERSION)"
build="$(value BUILD_NUMBER)"
[[ "$(value APPLICATION_ID)" =~ ^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$ ]]
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
[[ "$build" =~ ^[1-9][0-9]*$ ]]
[[ "$(value COMMIT)" =~ ^[0-9a-f]{40}$ ]]
[[ "$(value ARTIFACT_SHA256)" =~ ^[0-9a-f]{64}$ ]]
[[ "$(value SYMBOLS_SHA256)" =~ ^[0-9a-f]{64}$ ]]
[[ "$(value MONITORING_RELEASE)" == "factorycare-mobile@${version}+${build}-${flavor}" ]]
echo 'FLUTTER_RELEASE_SOLUTION_PASS checks=7 real_artifact=false real_signature=false real_monitoring=false'
