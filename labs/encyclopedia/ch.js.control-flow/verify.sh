#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

run_case() {
  local name="$1"
  local score="$2"
  local retry_count="$3"
  local expected_file="$4"
  local expected_exit="$5"
  local actual_exit=0

  node "$ROOT/src/priority.mjs" "$score" "$retry_count" >"$TMP_DIR/$name.stdout" 2>"$TMP_DIR/$name.stderr" || actual_exit=$?
  if (( actual_exit != expected_exit )); then
    echo "FAIL control-flow lab case=$name expected_exit=$expected_exit actual_exit=$actual_exit" >&2
    exit 1
  fi
  cmp "$ROOT/expected/$expected_file" "$TMP_DIR/$name.stdout"
  test ! -s "$TMP_DIR/$name.stderr"
}

# 绿色边界表覆盖零、一次、多次、相邻阈值、上下界和非法输入。
run_case zero 80 0 zero.stdout 0
run_case one 50 1 one.stdout 0
run_case many 49 3 many.stdout 0
run_case threshold_79 79 0 p2-zero.stdout 0
run_case lower_edge 0 0 p3-zero.stdout 0
run_case upper_edge 100 0 zero.stdout 0
run_case invalid_score 101 1 invalid-score.stdout 2
run_case non_number bad 1 invalid-score.stdout 2
run_case invalid_retry 80 -1 invalid-retry.stdout 2

truthiness_exit=0
node "$ROOT/faults/truthiness-zero.mjs" >"$TMP_DIR/truthiness.stdout" 2>"$TMP_DIR/truthiness.stderr" || truthiness_exit=$?
if (( truthiness_exit == 0 )); then
  echo "FAIL control-flow lab: truthiness fault did not fail" >&2
  exit 1
fi
grep -Fq 'TRUTHINESS_REJECTED_VALID_ZERO' "$TMP_DIR/truthiness.stderr"
test ! -s "$TMP_DIR/truthiness.stdout"

branch_exit=0
node "$ROOT/faults/missing-branch.mjs" >"$TMP_DIR/branch.stdout" 2>"$TMP_DIR/branch.stderr" || branch_exit=$?
if (( branch_exit == 0 )); then
  echo "FAIL control-flow lab: missing branch fault did not fail" >&2
  exit 1
fi
grep -Fq 'MISSING_P2_BRANCH_AT_BOUNDARY' "$TMP_DIR/branch.stderr"
test ! -s "$TMP_DIR/branch.stdout"

loop_exit=0
node "$ROOT/faults/off-by-one.mjs" >"$TMP_DIR/loop.stdout" 2>"$TMP_DIR/loop.stderr" || loop_exit=$?
if (( loop_exit == 0 )); then
  echo "FAIL control-flow lab: off-by-one fault did not fail" >&2
  exit 1
fi
grep -Fq 'OFF_BY_ONE_ZERO_EXECUTED_ONCE' "$TMP_DIR/loop.stderr"
test ! -s "$TMP_DIR/loop.stdout"

echo "PASS control-flow lab cases=9 truthiness=$truthiness_exit branch=$branch_exit off_by_one=$loop_exit"
