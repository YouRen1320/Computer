import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const cases = JSON.parse(await readFile(new URL('./cases.json', import.meta.url), 'utf8'))
// 证据顺序：先检查跨端合同，再检查副作用身份、产品降级和发布来源。
function diagnose(value) {
  if (value.assetResponseKeys.sort().join(',') !== 'assetId,displayName' || value.clientContractDigest !== value.releaseContractDigest) return 'CROSS_CLIENT_CONTRACT_DRIFT'
  if (!value.operationId || value.firstKey !== value.retryKey) return 'DUPLICATE_WORK_ORDER_RISK'
  if (value.cameraDenied && (!value.manualCodeAvailable || !value.textOnlySubmitAvailable)) return 'PERMISSION_FALLBACK_MISSING'
  if (value.releaseBuildId !== value.evidenceBuildId) return 'FABRICATED_RELEASE_EVIDENCE'
  return 'HEALTHY'
}

assert.equal(diagnose(cases.healthy), 'HEALTHY')
const expected = {
  'contract-drift': 'CROSS_CLIENT_CONTRACT_DRIFT',
  'duplicate-key-change': 'DUPLICATE_WORK_ORDER_RISK',
  'permission-no-fallback': 'PERMISSION_FALLBACK_MISSING',
  'release-evidence-mismatch': 'FABRICATED_RELEASE_EVIDENCE'
}
for (const fault of cases.faults) assert.equal(diagnose(fault), expected[fault.id])
console.log('UNIAPP_FACTORYCARE_REPORTER_LAB_PASS cases=5 faults=4 evidence=offline-negative-oracle')
