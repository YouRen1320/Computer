#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
submission="submission.md"
required_headings=(预测 实验 失败 修复 复述)
placeholder='TODO：请替换本行。'

if [[ ! -f "$submission" ]]; then
  printf '%s\n' 'UNKNOWN_STATE missing editable starter submission.md' >&2
  exit 43
fi

for heading in "${required_headings[@]}"; do
  if [[ $(grep -Fxc "## $heading" "$submission" || true) -ne 1 ]]; then
    printf 'UNKNOWN_STATE heading=%s expected=exactly-one\n' "$heading" >&2
    exit 43
  fi
done

placeholder_count=$(grep -Fxc "$placeholder" "$submission" || true)
if [[ $placeholder_count -eq 5 ]]; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.foundations.api-contract-basics oracle=editable-submission-starter'
  exit 41
fi
if [[ $placeholder_count -ne 0 ]]; then
  printf 'UNKNOWN_STATE partial-starter placeholder_count=%s expected=0-or-5\n' "$placeholder_count" >&2
  exit 43
fi

for heading in "${required_headings[@]}"; do
  content_count=$(awk -v target="## $heading" '
    $0 == target { inside = 1; next }
    inside && /^## / { inside = 0 }
    inside && $0 !~ /^[[:space:]]*$/ { count++ }
    END { print count + 0 }
  ' "$submission")
  if [[ $content_count -eq 0 ]]; then
    printf 'UNKNOWN_STATE heading=%s has-no-submission-content\n' "$heading" >&2
    exit 43
  fi
done

printf '%s\n' 'EXERCISE_GREEN evidence-loop-structure=complete semantic-review=required'
