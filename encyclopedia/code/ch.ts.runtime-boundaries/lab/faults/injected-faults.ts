// 故障夹具记录失败阶段和首个可信证据，供诊断测试而非生产导入。
export const injectedFaults = [
  { marker: 'UNVALIDATED_RUNTIME_DATA', stage: 'schema', evidence: 'type assertion lets wrong priority reach domain code' },
  { marker: 'PARSE_FAILURE_IGNORED', stage: 'mapping', evidence: 'safeParse failure is replaced with an empty object' },
  { marker: 'QUALITY_GATE_BYPASS', stage: 'verify', evidence: 'typecheck exits nonzero while aggregate script exits zero' },
] as const

