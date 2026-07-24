#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
test -s answers.md
grep -Eq '^#{1,4} ' answers.md
printf '%s\n' 'SOLUTION_GREEN private answer structure is present'
