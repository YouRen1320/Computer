#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ ! -f submission.md ]]; then
  printf '%s\n' 'EXPECTED_RED submission.md is not present; complete the public exercise first' >&2
  exit 41
fi
for heading in 预测 实验 失败 修复 复述; do
  if ! grep -Eq "^## .*$heading" submission.md; then
    printf 'EXPECTED_RED submission.md is missing a %s section\n' "$heading" >&2
    exit 41
  fi
done
printf '%s\n' 'EXERCISE_GREEN evidence loop is structurally complete'
