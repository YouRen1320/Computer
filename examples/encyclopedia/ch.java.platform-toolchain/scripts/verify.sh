#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
CLASSES_DIR="${BUILD_DIR}/classes"
SOURCE_FILE="${ROOT_DIR}/src/com/factorycare/learning/ToolchainSmoke.java"
MAIN_CLASS="com.factorycare.learning.ToolchainSmoke"
EXPECTED_OUTPUT="FactoryCare toolchain OK"

rm -rf -- "${BUILD_DIR}"
mkdir -p -- "${CLASSES_DIR}" "${BUILD_DIR}/empty"

JAVA_PATH="$(command -v java)"
JAVAC_PATH="$(command -v javac)"
JAVA_VERSION="$(${JAVA_PATH} -version 2>&1 | head -n 1)"
JAVAC_VERSION="$(${JAVAC_PATH} -version 2>&1 | head -n 1)"

case "${JAVA_VERSION}" in
  *'version "25.'*|*'version "25"'*) ;;
  *)
    printf 'Expected java 25.x, got: %s\n' "${JAVA_VERSION}" >&2
    exit 2
    ;;
esac

case "${JAVAC_VERSION}" in
  "javac 25"*) ;;
  *)
    printf 'Expected javac 25.x, got: %s\n' "${JAVAC_VERSION}" >&2
    exit 2
    ;;
esac

"${JAVAC_PATH}" --release 25 -d "${CLASSES_DIR}" "${SOURCE_FILE}"
COMPILE_EXIT=0

CLASS_FILE="${CLASSES_DIR}/com/factorycare/learning/ToolchainSmoke.class"
test -s "${CLASS_FILE}"

MAJOR_VERSION="$(${JAVAC_PATH%/javac}/javap -classpath "${CLASSES_DIR}" -verbose "${MAIN_CLASS}" | awk '/major version:/ {print $3; exit}')"
test "${MAJOR_VERSION}" = "69"

set +e
PROGRAM_OUTPUT="$(${JAVA_PATH} -cp "${CLASSES_DIR}" "${MAIN_CLASS}" 2>"${BUILD_DIR}/run.stderr")"
RUN_EXIT=$?
set -e
test "${RUN_EXIT}" -eq 0
test "${PROGRAM_OUTPUT}" = "${EXPECTED_OUTPUT}"
test ! -s "${BUILD_DIR}/run.stderr"

set +e
"${JAVAC_PATH}" --release 99 -d "${CLASSES_DIR}" "${SOURCE_FILE}" >"${BUILD_DIR}/bad-release.stdout" 2>"${BUILD_DIR}/bad-release.stderr"
BAD_RELEASE_EXIT=$?
set -e
test "${BAD_RELEASE_EXIT}" -ne 0
test -s "${BUILD_DIR}/bad-release.stderr"
grep -q '99' "${BUILD_DIR}/bad-release.stderr"

set +e
"${JAVA_PATH}" -cp "${BUILD_DIR}/empty" "${MAIN_CLASS}" >"${BUILD_DIR}/bad-classpath.stdout" 2>"${BUILD_DIR}/bad-classpath.stderr"
BAD_CLASSPATH_EXIT=$?
set -e
test "${BAD_CLASSPATH_EXIT}" -ne 0
test -s "${BUILD_DIR}/bad-classpath.stderr"
grep -q "${MAIN_CLASS}" "${BUILD_DIR}/bad-classpath.stderr"

cat >"${BUILD_DIR}/verification-report.txt" <<REPORT
java_path=${JAVA_PATH}
javac_path=${JAVAC_PATH}
java_version=${JAVA_VERSION}
javac_version=${JAVAC_VERSION}
compile_exit=${COMPILE_EXIT}
class_file=${CLASS_FILE}
class_major_version=${MAJOR_VERSION}
run_output=${PROGRAM_OUTPUT}
run_exit=${RUN_EXIT}
bad_release_exit=${BAD_RELEASE_EXIT}
bad_classpath_exit=${BAD_CLASSPATH_EXIT}
REPORT

printf '%s\n' "${PROGRAM_OUTPUT}"
printf 'PASS: compile=%s run=%s major=%s bad_release=%s bad_classpath=%s\n' \
  "${COMPILE_EXIT}" "${RUN_EXIT}" "${MAJOR_VERSION}" "${BAD_RELEASE_EXIT}" "${BAD_CLASSPATH_EXIT}"
printf 'report=%s\n' "${BUILD_DIR}/verification-report.txt"
