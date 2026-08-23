#!/usr/bin/env bash
set -euo pipefail
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

artifact="$tmp_dir/factorycare-1.4.0+10402-production.synthetic-aab"
symbols="$tmp_dir/factorycare-1.4.0+10402-production.synthetic-symbols"
printf '%s\n' 'synthetic artifact; not an Android App Bundle' >"$artifact"
printf '%s\n' 'synthetic symbols; not Flutter split-debug-info' >"$symbols"
artifact_sha="$(shasum -a 256 "$artifact" | awk '{print $1}')"
symbols_sha="$(shasum -a 256 "$symbols" | awk '{print $1}')"

cat >"$tmp_dir/release.env" <<ENV
APPLICATION=factorycare-mobile
FLAVOR=production
APPLICATION_ID=com.factorycare.mobile
VERSION=1.4.0
BUILD_NUMBER=10402
COMMIT=8f2c000000000000000000000000000000000042
SOURCE_DIRTY=false
FLUTTER=3.44.x
DART=3.12.x
SIGNING_IDENTITY_SHA256=certificate-fingerprint-metadata-only
API_ORIGIN=https://api.factorycare.example
ARTIFACT_SHA256=$artifact_sha
SYMBOLS_SHA256=$symbols_sha
MONITORING_RELEASE=factorycare-mobile@1.4.0+10402-production
REAL_ARTIFACT=false
REAL_SIGNATURE=false
ENV

grep -q '^FLAVOR=production$' "$tmp_dir/release.env"
grep -q '^APPLICATION_ID=com.factorycare.mobile$' "$tmp_dir/release.env"
grep -q '^API_ORIGIN=https://api.factorycare.example$' "$tmp_dir/release.env"
grep -q '^SOURCE_DIRTY=false$' "$tmp_dir/release.env"
grep -q "^ARTIFACT_SHA256=$artifact_sha$" "$tmp_dir/release.env"
grep -q "^SYMBOLS_SHA256=$symbols_sha$" "$tmp_dir/release.env"
grep -q '^MONITORING_RELEASE=factorycare-mobile@1.4.0+10402-production$' "$tmp_dir/release.env"
grep -q '^REAL_ARTIFACT=false$' "$tmp_dir/release.env"
grep -q '^REAL_SIGNATURE=false$' "$tmp_dir/release.env"
echo "FLUTTER_RELEASE_EXAMPLE_PASS artifact_sha=$artifact_sha symbols_sha=$symbols_sha real_artifact=false"
