// Responsibility: verify the example's permission, cancellation, and device-result contract from local fixtures.
import assert from 'node:assert/strict'
import { parseScannedDevice, reducePermission, reduceSubmission, validateLocation } from './device-model.mjs'

assert.deepEqual(reducePermission({ kind: 'unknown' }, {
  type: 'CHECK', capabilityAvailable: false, current: 'prompt'
}), { kind: 'unavailable', reason: 'capability' })
const requestable = reducePermission({ kind: 'unknown' }, {
  type: 'CHECK', capabilityAvailable: true, current: 'prompt'
})
assert.deepEqual(requestable, { kind: 'requestable' })
const requesting = reducePermission(requestable, { type: 'REQUEST' })
assert.deepEqual(requesting, { kind: 'requesting' })
assert.deepEqual(reducePermission(requesting, { type: 'DENIED', canAskAgain: true }), {
  kind: 'denied', canAskAgain: true
})
assert.deepEqual(reducePermission(requesting, { type: 'DENIED', canAskAgain: false }), {
  kind: 'settings-required', canAskAgain: false
})
assert.deepEqual(reducePermission({ kind: 'settings-required' }, {
  type: 'RETURNED_FROM_SETTINGS', current: 'granted'
}), { kind: 'granted' })

assert.deepEqual(parseScannedDevice(' dev-a1b2c3 '), { kind: 'ok', value: { deviceCode: 'DEV-A1B2C3' } })
assert.deepEqual(parseScannedDevice('javascript:alert(1)'), {
  kind: 'failed', code: 'INVALID_DEVICE_CODE', retryable: false
})
assert.equal(validateLocation({ latitude: 31.23, longitude: 118.75, coordinateSystem: 'gcj02' }).kind, 'ok')
assert.equal(validateLocation({ latitude: 131.23, longitude: 118.75, coordinateSystem: 'unknown' }).kind, 'failed')

let submission = reduceSubmission({ kind: 'idle' }, { type: 'UPLOAD_STARTED', operationId: 'op-1' })
submission = reduceSubmission(submission, { type: 'UPLOAD_COMPLETED', attachmentId: 'ATT-1' })
submission = reduceSubmission(submission, { type: 'COMMIT_STARTED', idempotencyKey: 'idem-1' })
submission = reduceSubmission(submission, { type: 'COMMIT_FAILED', retryable: true })
assert.deepEqual(submission, {
  kind: 'commit-failed', attachmentId: 'ATT-1', idempotencyKey: 'idem-1', retryable: true
})

console.log('UNIAPP_DEVICE_CAPABILITIES_EXAMPLE_PASS checks=11 evidence=permission-device-submission-model')
