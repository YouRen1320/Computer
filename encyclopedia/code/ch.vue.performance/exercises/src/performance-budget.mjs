// 故意错误：首包、更新范围和恢复均超预算，且跳过无障碍回归。
export const result = {
  entryBytes: 260 * 1024,
  updatedRows: 200,
  recoveryMilliseconds: Number.POSITIVE_INFINITY,
  behaviorTests: true,
  accessibilityChecks: false,
}

