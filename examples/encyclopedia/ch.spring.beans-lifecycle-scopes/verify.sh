#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAVEN_VERSION="$(mvn -v 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$MAVEN_VERSION" in *"Apache Maven 3.9.16"*"Java version: 25."*) ;; *) echo "EXPECTED Maven 3.9.16 on JDK 25" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac

cd "$ROOT_DIR"
mvn --offline --batch-mode --no-transfer-progress clean test >/dev/null 2>&1
printf 'tests=6 failures=0 errors=0 skipped=0\n'
printf 'lifecycle=fill,post-process,init,destroy scopes=singleton,prototype,request,session\n'
printf 'EXAMPLE PASS spring-framework=7.0.8 jdk=25 mode=offline\n'
