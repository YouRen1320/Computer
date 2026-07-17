#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# 保持锁文件目标 pnpm 11，同时允许本机 pnpm 10 做兼容性机械验证并清理产物。
export npm_config_manage_package_manager_versions=false
cleanup() { rm -rf node_modules .verify-dist; }
trap cleanup EXIT
pnpm install --offline --frozen-lockfile --ignore-scripts
pnpm run typecheck
pnpm run test
pnpm run build
printf '%s\n' 'TS_RUNTIME_BOUNDARIES_LAB_PASS gates=3 faults=3'
