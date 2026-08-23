#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# 本机机械验证不自动向用户全局工具目录安装 packageManager 指定的 pnpm 11。
export npm_config_manage_package_manager_versions=false
cleanup() { rm -rf node_modules .verify-dist; }
trap cleanup EXIT
pnpm install --offline --frozen-lockfile --ignore-scripts
pnpm run format:check
pnpm run lint
pnpm run typecheck
pnpm run test
pnpm run build
printf '%s\n' 'TS_RUNTIME_BOUNDARIES_EXAMPLE_PASS gates=5'
