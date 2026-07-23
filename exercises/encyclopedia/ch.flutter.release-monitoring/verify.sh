#!/usr/bin/env bash
set -euo pipefail
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/release.env" <<'ENV'
FLAVOR=production
APPLICATION_ID=com.factorycare.mobile
VERSION=1.4.0
BUILD_NUMBER=10402
COMMIT=8f2c000000000000000000000000000000000042
ARTIFACT_SHA256=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
SYMBOLS_SHA256=
MONITORING_RELEASE=factorycare-mobile@1.4.0
ENV

symbols="$(sed -n 's/^SYMBOLS_SHA256=//p' "$tmp_dir/release.env")"
version="$(sed -n 's/^VERSION=//p' "$tmp_dir/release.env")"
build="$(sed -n 's/^BUILD_NUMBER=//p' "$tmp_dir/release.env")"
flavor="$(sed -n 's/^FLAVOR=//p' "$tmp_dir/release.env")"
release="$(sed -n 's/^MONITORING_RELEASE=//p' "$tmp_dir/release.env")"
expected="factorycare-mobile@${version}+${build}-${flavor}"

issues=0
if [[ ! "$symbols" =~ ^[0-9a-f]{64}$ ]]; then
  echo 'RELEASE_SYMBOL_EXERCISE symbols hash is missing or invalid' >&2
  issues=$((issues + 1))
fi
if [[ "$release" != "$expected" ]]; then
  echo "RELEASE_CORRELATION_EXERCISE expected=$expected actual=$release" >&2
  issues=$((issues + 1))
fi
if [[ $issues -eq 0 ]]; then
  echo 'unexpected green: release faults were not detected' >&2
  exit 42
fi
echo "FLUTTER_RELEASE_EXERCISE_EXPECTED_RED issues=$issues" >&2
exit 41
