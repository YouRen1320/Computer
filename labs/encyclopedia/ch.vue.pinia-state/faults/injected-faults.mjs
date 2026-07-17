// 故障夹具只描述可诊断症状，验证器必须把它们映射到首个可信证据。
export const injectedFaults = [
  {
    marker: 'STATE_OWNERSHIP_AMBIGUITY',
    evidence: 'component.statuses and store.statuses are both writable sources',
  },
  {
    marker: 'STORE_TO_REFS_MISSING',
    evidence: 'plain destructuring freezes the observed primitive at extraction time',
  },
  {
    marker: 'STORE_SESSION_LEAK',
    evidence: 'member B starts with member A filters before any B action',
  },
]

