import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const cases = JSON.parse(await readFile(new URL('./cases.json', import.meta.url), 'utf8'))
// 诊断顺序：先 HTTP/body 边界，再状态身份、重试预算和底层取消传播。
function diagnose(value) {
  if (!value.checksHttpOk || value.responseBodyReads !== 1) return 'FETCH_HTTP_BOUNDARY_BROKEN'
  if (!value.guardsItems || !value.guardsError || !value.guardsLoading) return 'STALE_RESPONSE_OVERWRITE'
  if (value.maxAttempts < 1 || value.delayPolicy === 'immediate' || value.retry404) return 'RETRY_STORM_POLICY'
  if (!value.abortSignalPassed) return 'UNCANCELLED_REQUEST'
  return 'HEALTHY'
}
assert.equal(diagnose(cases.healthy), 'HEALTHY')
const expected = { 'http-as-success': 'FETCH_HTTP_BOUNDARY_BROKEN', 'stale-finally': 'STALE_RESPONSE_OVERWRITE', 'retry-storm': 'RETRY_STORM_POLICY', 'not-cancelled': 'UNCANCELLED_REQUEST' }
for (const fault of cases.faults) assert.equal(diagnose(fault), expected[fault.id])
console.log('JS_FETCH_CANCELLATION_RACE_LAB_PASS cases=5 faults=4 evidence=offline-policy-oracle')
