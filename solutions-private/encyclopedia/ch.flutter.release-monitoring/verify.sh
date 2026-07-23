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
SYMBOLS_SHA256=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
MONITORING_RELEASE=factorycare-mobile@1.4.0+10402-production
REAL_ARTIFACT=false
REAL_SIGNATURE=false
REAL_MONITORING=false
ENV

symbols="$(sed -n 's/^SYMBOLS_SHA256=//p' "$tmp_dir/release.env")"
version="$(sed -n 's/^VERSION=//p' "$tmp_dir/release.env")"
build="$(sed -n 's/^BUILD_NUMBER=//p' "$tmp_dir/release.env")"
flavor="$(sed -n 's/^FLAVOR=//p' "$tmp_dir/release.env")"
release="$(sed -n 's/^MONITORING_RELEASE=//p' "$tmp_dir/release.env")"
[[ "$symbols" =~ ^[0-9a-f]{64}$ ]]
[[ "$release" == "factorycare-mobile@${version}+${build}-${flavor}" ]]
grep -q '^REAL_ARTIFACT=false$' "$tmp_dir/release.env"
grep -q '^REAL_SIGNATURE=false$' "$tmp_dir/release.env"
grep -q '^REAL_MONITORING=false$' "$tmp_dir/release.env"
echo 'FLUTTER_RELEASE_SOLUTION_PASS real_artifact=false real_signature=false real_monitoring=false'
