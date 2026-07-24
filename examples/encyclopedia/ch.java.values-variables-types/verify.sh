#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/factorycare-values-example.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM

case "$(javac -version 2>&1 | head -n 1)" in "javac 25"*) ;; *) echo "FAIL: javac 25.x required" >&2; exit 2 ;; esac
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "FAIL: java 25.x required" >&2; exit 2 ;; esac
case "$(mvn -v 2>&1)" in *'Java version: 25.'*|*'Java version: 25,'*) ;; *) echo "FAIL: Maven must run on JDK 25.x" >&2; exit 2 ;; esac

mvn -q -f "$ROOT_DIR/pom.xml" clean package
java -cp "$ROOT_DIR/target/classes" com.factorycare.learning.DeviceSnapshot >"$WORK_DIR/snapshot.txt"
diff -u "$ROOT_DIR/expected-output.txt" "$WORK_DIR/snapshot.txt"

java -cp "$ROOT_DIR/target/classes" com.factorycare.learning.FieldDefaultBoundary >"$WORK_DIR/defaults.txt"
printf '%s\n' 'ticketCount=0, enabled=false, note=null' >"$WORK_DIR/defaults-expected.txt"
diff -u "$WORK_DIR/defaults-expected.txt" "$WORK_DIR/defaults.txt"

echo "EXAMPLE_GREEN: Maven build, snapshot output, scope blocks, and field defaults are verified."
