// 注入故障包含失败阶段和首个可信证据，避免只给笼统 hydration 结论。
export const injectedFaults = [
  { marker: 'SERVER_BROWSER_API_LEAK', stage: 'server-render', evidence: 'localStorage is read in universal setup' },
  { marker: 'HYDRATION_RANDOM_MISMATCH', stage: 'hydrate', evidence: 'server/client seed values differ' },
  { marker: 'HYDRATION_TIMEZONE_MISMATCH', stage: 'hydrate', evidence: 'same ISO instant formats to different first-frame text' },
]

