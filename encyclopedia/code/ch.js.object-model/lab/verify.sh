#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

node "$ROOT/src/object-contract.mjs" >"$TMP_DIR/baseline.stdout" 2>"$TMP_DIR/baseline.stderr"
cmp "$ROOT/expected.stdout" "$TMP_DIR/baseline.stdout"
test ! -s "$TMP_DIR/baseline.stderr"

this_exit=0
node "$ROOT/faults/this-binding-loss.mjs" >"$TMP_DIR/this.stdout" 2>"$TMP_DIR/this.stderr" || this_exit=$?
if (( this_exit == 0 )); then
  echo "FAIL object-model lab: this-binding fault did not fail" >&2
  exit 1
fi
grep -Fq "THIS_BINDING_LOSS_DETACHED_METHOD" "$TMP_DIR/this.stderr"
test ! -s "$TMP_DIR/this.stdout"

prototype_exit=0
node "$ROOT/faults/prototype-pollution.mjs" >"$TMP_DIR/prototype.stdout" 2>"$TMP_DIR/prototype.stderr" || prototype_exit=$?
if (( prototype_exit == 0 )); then
  echo "FAIL object-model lab: prototype-pollution fault did not fail" >&2
  exit 1
fi
grep -Fq "PROTOTYPE_POLLUTION_SHARED_BEHAVIOR_DRIFT" "$TMP_DIR/prototype.stderr"
test ! -s "$TMP_DIR/prototype.stdout"

shared_exit=0
node "$ROOT/faults/shared-instance-state.mjs" >"$TMP_DIR/shared.stdout" 2>"$TMP_DIR/shared.stderr" || shared_exit=$?
if (( shared_exit == 0 )); then
  echo "FAIL object-model lab: shared-instance-state fault did not fail" >&2
  exit 1
fi
grep -Fq "SHARED_INSTANCE_STATE_NOT_ISOLATED" "$TMP_DIR/shared.stderr"
test ! -s "$TMP_DIR/shared.stdout"

echo "PASS object-model lab baseline=0 this=$this_exit prototype=$prototype_exit shared=$shared_exit"
