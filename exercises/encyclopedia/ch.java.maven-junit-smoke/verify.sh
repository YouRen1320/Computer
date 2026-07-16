#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C LANG=C MAVEN_OPTS="-Dfile.encoding=UTF-8 -Duser.language=en -Duser.country=US"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
rm -rf "$BUILD_DIR" && mkdir -p "$BUILD_DIR"
(cd "$ROOT_DIR" && mvn --offline --batch-mode --no-transfer-progress -Dstyle.color=never clean test) > "$BUILD_DIR/maven.log" 2>&1
grep -Fq "Tests run: 2, Failures: 0, Errors: 0, Skipped: 0" "$BUILD_DIR/maven.log"
grep -Fq "BUILD SUCCESS" "$BUILD_DIR/maven.log"
echo "EXERCISE PASS downtime tests=2 failures=0 errors=0 skipped=0 offline=true"
