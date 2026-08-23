import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const cases = JSON.parse(await readFile(new URL('./cases.json', import.meta.url), 'utf8'))
// 诊断顺序体现证据优先级：先识别实际产物和环境，再判断灰度与监控。
function diagnose(x) {
  if (!x.commit || !x.artifactDigest) return 'RELEASE_PROVENANCE_LOSS'
  if (x.environment === 'production' && x.apiOrigin.includes('localhost')) return 'PRODUCTION_ENVIRONMENT_MIX'
  if (x.grayBuildId !== x.buildId || !x.stopCondition || !x.rollbackBuildId) return 'UNSAFE_GRAY_PLAN'
  if (x.eventBuildId !== x.buildId) return 'EVENT_RELEASE_MISMATCH'
  if (['authorization', 'token', 'coordinates', 'description'].some((key) => Object.hasOwn(x.event, key))) return 'SENSITIVE_MONITORING_FIELD'
  return 'HEALTHY'
}

assert.equal(diagnose(cases.healthy), 'HEALTHY')
const expected = {
  'environment-mix': 'PRODUCTION_ENVIRONMENT_MIX',
  'provenance-loss': 'RELEASE_PROVENANCE_LOSS',
  'no-stop-condition': 'UNSAFE_GRAY_PLAN',
  'sensitive-event': 'SENSITIVE_MONITORING_FIELD'
}
for (const fault of cases.faults) assert.equal(diagnose(fault), expected[fault.id])
console.log('UNIAPP_RELEASE_MONITORING_LAB_PASS cases=5 faults=4 evidence=offline-failure-oracle')
