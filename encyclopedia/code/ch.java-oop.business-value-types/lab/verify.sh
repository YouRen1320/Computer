#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
FAILURE_CLASSES="$BUILD_DIR/failure-classes"
JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED JDK 25, got: $JAVAC_VERSION" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25.x, got: $JAVA_VERSION" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR" "$FAILURE_CLASSES"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/BusinessValueTypesLab.java"
java -cp "$CLASSES_DIR" BusinessValueTypesLab > "$BUILD_DIR/lab.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
report.money=INPUT 19.995 CNY | OP HALF_UP scale=2 | RESULT CNY 20.00
report.id=INPUT canonical text | OP regex+UUID parse | RESULT WO-550e8400-e29b-41d4-a716-446655440000
report.time=INPUT 2026-07-16T01:00:00Z Asia/Shanghai | OP atZone | RESULT 2026-07-16T09:00+08:00[Asia/Shanghai]
assertions=24 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/lab.out"

javac --release 25 -d "$FAILURE_CLASSES" "$ROOT_DIR"/failures/*.java
set +e
java -cp "$FAILURE_CLASSES" DoubleMoneyFailure > "$BUILD_DIR/double.out" 2> "$BUILD_DIR/double.err"; double_status=$?
java -cp "$FAILURE_CLASSES" ScaleEqualityFailure > "$BUILD_DIR/scale.out" 2> "$BUILD_DIR/scale.err"; scale_status=$?
java -cp "$FAILURE_CLASSES" DefaultZoneFailure > "$BUILD_DIR/zone.out" 2> "$BUILD_DIR/zone.err"; zone_status=$?
java -cp "$FAILURE_CLASSES" LooseRegexFailure > "$BUILD_DIR/regex.out" 2> "$BUILD_DIR/regex.err"; regex_status=$?
java -cp "$FAILURE_CLASSES" CrossCurrencyFailure > "$BUILD_DIR/currency.out" 2> "$BUILD_DIR/currency.err"; currency_status=$?
set -e
[[ $double_status -eq 4 && $scale_status -eq 5 && $zone_status -eq 6 && $regex_status -eq 7 && $currency_status -eq 8 ]]
grep -Fqx "DOUBLE_MONEY_ERROR expected=0.1 actual=0.1000000000000000055511151231257827021181583404541015625" "$BUILD_DIR/double.err"
grep -Fqx "SCALE_EQUALITY_FAILURE leftScale=1 rightScale=2 equals=false compareTo=0" "$BUILD_DIR/scale.err"
grep -Fqx "DEFAULT_ZONE_DRIFT utc=2026-07-16T09:00:00Z shanghai=2026-07-16T01:00:00Z" "$BUILD_DIR/zone.err"
grep -Fqx "LOOSE_REGEX_ACCEPTED input=WO- expected=false actual=true" "$BUILD_DIR/regex.err"
grep -Fqx "CROSS_CURRENCY_ACCEPTED left=CNY right=USD result=CNY-12.00" "$BUILD_DIR/currency.err"

cat "$BUILD_DIR/lab.out"
echo "EXPECTED_FAILURE DoubleMoneyFailure status=$double_status evidence=binary-tail"
echo "EXPECTED_FAILURE ScaleEqualityFailure status=$scale_status evidence=scale-sensitive-equals"
echo "EXPECTED_FAILURE DefaultZoneFailure status=$zone_status evidence=system-default"
echo "EXPECTED_FAILURE LooseRegexFailure status=$regex_status evidence=invalid-id-accepted"
echo "EXPECTED_FAILURE CrossCurrencyFailure status=$currency_status evidence=unit-mismatch"
echo "LAB PASS assertions=24 expected_failures=5 java=$JAVA_VERSION"
