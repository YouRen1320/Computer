#!/usr/bin/env bash
set -euo pipefail
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/verify_rc.rb" <<'RUBY'
#!/usr/bin/env ruby
values = {}
File.readlines(ARGV.fetch(0), chomp: true).each do |line|
  next if line.empty? || line.start_with?("#")
  key, value = line.split("=", 2)
  values[key] = value
end

required = %w[
  FLAVOR APPLICATION_ID API_ORIGIN SIGNING_IDENTITY_SHA256 VERSION BUILD_NUMBER
  COMMIT ARTIFACT_SHA256 SYMBOLS_SHA256 MONITORING_RELEASE
]
missing = required.select { |key| values.fetch(key, "").empty? }
abort("RELEASE_MANIFEST_MISSING fields=#{missing.join(',')}") unless missing.empty?

expected_release = "factorycare-mobile@#{values['VERSION']}+#{values['BUILD_NUMBER']}-#{values['FLAVOR']}"
abort("RELEASE_FLAVOR_MISMATCH actual=#{values['FLAVOR']}") unless values["FLAVOR"] == "production"
abort("RELEASE_APP_ID_MISMATCH actual=#{values['APPLICATION_ID']}") unless values["APPLICATION_ID"] == "com.factorycare.mobile"
abort("RELEASE_ENDPOINT_MISMATCH actual=#{values['API_ORIGIN']}") unless values["API_ORIGIN"] == "https://api.factorycare.example"
abort("RELEASE_SIGNING_MISMATCH") unless values["SIGNING_IDENTITY_SHA256"] == "prod-signing-fingerprint"
abort("RELEASE_MONITORING_MISMATCH expected=#{expected_release} actual=#{values['MONITORING_RELEASE']}") unless values["MONITORING_RELEASE"] == expected_release
abort("RELEASE_ARTIFACT_HASH_INVALID") unless values["ARTIFACT_SHA256"].match?(/\A[0-9a-f]{64}\z/)
abort("RELEASE_SYMBOL_HASH_INVALID") unless values["SYMBOLS_SHA256"].match?(/\A[0-9a-f]{64}\z/)
puts "RC_CONTRACT_PASS release=#{expected_release} real_build=false real_signature=false"
RUBY

good="$tmp_dir/good.env"
cat >"$good" <<'ENV'
FLAVOR=production
APPLICATION_ID=com.factorycare.mobile
API_ORIGIN=https://api.factorycare.example
SIGNING_IDENTITY_SHA256=prod-signing-fingerprint
VERSION=1.4.0
BUILD_NUMBER=10402
COMMIT=8f2c000000000000000000000000000000000042
ARTIFACT_SHA256=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
SYMBOLS_SHA256=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
MONITORING_RELEASE=factorycare-mobile@1.4.0+10402-production
ENV
ruby "$tmp_dir/verify_rc.rb" "$good"

expect_failure() {
  local fixture="$1"
  local marker="$2"
  set +e
  local output
  output="$(ruby "$tmp_dir/verify_rc.rb" "$fixture" 2>&1)"
  local status=$?
  set -e
  if [[ $status -eq 0 || "$output" != *"$marker"* ]]; then
    echo "injected fault did not reach expected oracle marker=$marker output=$output" >&2
    exit 51
  fi
  echo "INJECTED_FAULT_DETECTED marker=$marker"
}

cp "$good" "$tmp_dir/staging.env"
sed -i.bak 's#API_ORIGIN=https://api.factorycare.example#API_ORIGIN=https://staging-api.factorycare.example#' "$tmp_dir/staging.env"
expect_failure "$tmp_dir/staging.env" RELEASE_ENDPOINT_MISMATCH

cp "$good" "$tmp_dir/no-symbols.env"
sed -i.bak 's/^SYMBOLS_SHA256=.*/SYMBOLS_SHA256=/' "$tmp_dir/no-symbols.env"
expect_failure "$tmp_dir/no-symbols.env" RELEASE_MANIFEST_MISSING

cp "$good" "$tmp_dir/wrong-release.env"
sed -i.bak 's/^MONITORING_RELEASE=.*/MONITORING_RELEASE=factorycare-mobile@1.4.0/' "$tmp_dir/wrong-release.env"
expect_failure "$tmp_dir/wrong-release.env" RELEASE_MONITORING_MISMATCH

echo 'FLUTTER_RELEASE_LAB_PASS injected_faults=3 real_build=false real_signature=false real_monitoring=false'
