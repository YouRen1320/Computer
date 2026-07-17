// 预算明确绑定 200 行工单、一次 active 切换和一次按需面板失败场景。
export const budget = {
  entryBytes: 180 * 1024,
  updatedRows: 2,
  recoveryMilliseconds: 5_000,
}

export const baseline = {
  entryBytes: 260 * 1024,
  updatedRows: 200,
  recoveryMilliseconds: Number.POSITIVE_INFINITY,
  behaviorTests: true,
  accessibilityChecks: false,
}

export const optimized = {
  entryBytes: 142 * 1024,
  updatedRows: 2,
  recoveryMilliseconds: 1_200,
  behaviorTests: true,
  accessibilityChecks: true,
}

// 每个注入故障都携带首个可信证据，而不是只给“页面卡”结论。
export const injectedFaults = [
  { marker: 'DEEP_WATCH_RENDER_STORM', evidence: '200 rows update after one filter key changes' },
  { marker: 'LAZY_BOUNDARY_STATIC_IMPORT', evidence: 'evidence module remains in entry dependency graph' },
  { marker: 'ASYNC_COMPONENT_NO_RECOVERY', evidence: 'rejected loader leaves no error or retry state' },
]

