import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
const data = JSON.parse(await readFile(new URL('./cases.json', import.meta.url), 'utf8'))
function diagnose(x) {
  // 顺序按最低成本证据：先合同，再构建映射，最后声明载体。
  if (x.mockShape !== x.hostShape) return 'MOCK_HOST_CONTRACT_DRIFT'
  if (x.buildId !== x.mapBuildId) return 'SOURCE_MAP_BUILD_MISMATCH'
  if (x.claim === 'device-passed' && x.carrier !== 'physical-device') return 'DEVICE_EVIDENCE_MISSING'
  return 'HEALTHY'
}
assert.equal(diagnose(data.healthy), 'HEALTHY')
const expected = { 'mock-drift': 'MOCK_HOST_CONTRACT_DRIFT', 'map-mismatch': 'SOURCE_MAP_BUILD_MISMATCH', 'simulator-claim': 'DEVICE_EVIDENCE_MISSING' }
for (const fault of data.faults) assert.equal(diagnose(fault), expected[fault.id])
console.log('UNIAPP_TESTING_DEBUGGING_LAB_PASS cases=4 faults=3 evidence=offline-repro-oracle')
