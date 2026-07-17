// Responsibility: verify the example's deterministic testing and failure-classification contract offline.
import assert from 'node:assert/strict'
import { acceptLatest, mapUploadHostResponse, validateRepairDraft, validateReproBundle } from './testing-model.mjs'

assert.deepEqual(validateRepairDraft({ deviceCode: 'DEV-A1B2C3', description: '主轴在运行十分钟后出现明显异响' }), { valid: true, errors: {} })
assert.deepEqual(validateRepairDraft({ deviceCode: 'bad', description: '异响' }), {
  valid: false, errors: { deviceCode: 'INVALID_DEVICE_CODE', description: 'DESCRIPTION_TOO_SHORT' }
})
assert.deepEqual(mapUploadHostResponse({ statusCode: '200', data: '{"attachmentId":"ATT-9"}' }), {
  kind: 'ok', value: { attachmentId: 'ATT-9' }
})
assert.deepEqual(mapUploadHostResponse({ statusCode: 200, data: '{broken' }), { kind: 'contract-error' })
assert.deepEqual(mapUploadHostResponse({ statusCode: 401, data: '' }), { kind: 'unauthenticated' })
assert.deepEqual(acceptLatest('op-new', { operationId: 'op-old', value: 'stale' }), { accepted: false })
assert.deepEqual(acceptLatest('op-new', { operationId: 'op-new', value: 'fresh' }), { accepted: true, value: 'fresh' })

const bundle = {
  commit: 'abc123', target: 'mp-weixin', runtimeVersion: 'fixture-1', device: 'fixture-phone', os: 'fixture-os',
  buildId: 'build-7', mapBuildId: 'build-7', artifactChecksum: 'sha256:fixture', carrier: 'physical-device',
  claim: 'device-passed', steps: ['open', 'submit'], expected: 'conflict message', actual: 'conflict message'
}
assert.deepEqual(validateReproBundle(bundle), { valid: true, missing: [] })
assert.equal(validateReproBundle({ ...bundle, carrier: 'devtools' }).valid, false)
assert.equal(validateReproBundle({ ...bundle, mapBuildId: 'build-old' }).valid, false)
console.log('UNIAPP_TESTING_DEBUGGING_EXAMPLE_PASS checks=10 evidence=offline-layer-contract')
