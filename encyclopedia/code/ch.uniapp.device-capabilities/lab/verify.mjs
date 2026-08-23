import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const cases = JSON.parse(await readFile(new URL('./cases.json', import.meta.url), 'utf8'))

function diagnose(fixture) {
  // 证据顺序：先保护领域结果，再检查副作用次数，最后检查两阶段提交状态。
  if (fixture.deniedResult.kind === 'ok' || fixture.locationPayloadCreated) return 'DENIAL_COLLAPSED_TO_EMPTY'
  if (fixture.permissionRequestCount > 1) return 'PERMISSION_REQUEST_LOOP'
  if (fixture.upload.succeeded && !fixture.commit.succeeded && fixture.finalState !== 'commit-failed') {
    return 'PARTIAL_UPLOAD_REPORTED_COMPLETE'
  }
  return 'HEALTHY'
}

assert.equal(diagnose(cases.healthy), 'HEALTHY')
const expected = {
  'denial-as-empty': 'DENIAL_COLLAPSED_TO_EMPTY',
  'permission-loop': 'PERMISSION_REQUEST_LOOP',
  'partial-commit': 'PARTIAL_UPLOAD_REPORTED_COMPLETE'
}
for (const fixture of cases.faults) assert.equal(diagnose(fixture), expected[fixture.id])
console.log('UNIAPP_DEVICE_CAPABILITIES_LAB_PASS cases=4 faults=3 evidence=offline-state-oracle')
