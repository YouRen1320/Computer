#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
submission='release.env'

required=(FLAVOR APPLICATION_ID VERSION BUILD_NUMBER COMMIT ARTIFACT_SHA256 SYMBOLS_SHA256 MONITORING_RELEASE)
for key in "${required[@]}"; do
  count="$(grep -c "^${key}=" "$submission" || true)"
  if [[ "$count" -ne 1 ]]; then
    echo "RELEASE_MANIFEST_SHAPE_MISMATCH key=$key count=$count" >&2
    exit 43
  fi
done
if grep -Ev '^(FLAVOR|APPLICATION_ID|VERSION|BUILD_NUMBER|COMMIT|ARTIFACT_SHA256|SYMBOLS_SHA256|MONITORING_RELEASE)=[^[:cntrl:]]*$' "$submission" | grep -q .; then
  echo 'RELEASE_MANIFEST_SHAPE_MISMATCH unknown-or-malformed-line' >&2
  exit 43
fi

value() { sed -n "s/^$1=//p" "$submission"; }
flavor="$(value FLAVOR)"
application_id="$(value APPLICATION_ID)"
version="$(value VERSION)"
build="$(value BUILD_NUMBER)"
commit="$(value COMMIT)"
artifact="$(value ARTIFACT_SHA256)"
symbols="$(value SYMBOLS_SHA256)"
release="$(value MONITORING_RELEASE)"
expected="factorycare-mobile@${version}+${build}-${flavor}"

issues=0
if [[ ! "$flavor" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo 'RELEASE_FLAVOR_EXERCISE invalid flavor' >&2
  issues=$((issues + 1))
fi
if [[ ! "$application_id" =~ ^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$ ]]; then
  echo 'RELEASE_APPLICATION_ID_EXERCISE invalid application id' >&2
  issues=$((issues + 1))
fi
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ ! "$build" =~ ^[1-9][0-9]*$ ]]; then
  echo 'RELEASE_VERSION_EXERCISE invalid version or build number' >&2
  issues=$((issues + 1))
fi
if [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]] || [[ ! "$artifact" =~ ^[0-9a-f]{64}$ ]]; then
  echo 'RELEASE_PROVENANCE_EXERCISE invalid commit or artifact hash' >&2
  issues=$((issues + 1))
fi
if [[ ! "$symbols" =~ ^[0-9a-f]{64}$ ]]; then
  echo 'RELEASE_SYMBOL_EXERCISE symbols hash is missing or invalid' >&2
  issues=$((issues + 1))
fi
if [[ "$release" != "$expected" ]]; then
  echo "RELEASE_CORRELATION_EXERCISE expected=$expected actual=$release" >&2
  issues=$((issues + 1))
fi
if [[ $issues -eq 0 ]]; then
  echo 'EXERCISE_GREEN chapter=ch.flutter.release-monitoring oracle=completed-solution'
  exit 0
fi
echo "EXPECTED_FLUTTER_RELEASE_MONITORING_RED issues=$issues" >&2
echo 'EXPECTED_RED chapter=ch.flutter.release-monitoring oracle=verified-starter-failure'
exit 41
