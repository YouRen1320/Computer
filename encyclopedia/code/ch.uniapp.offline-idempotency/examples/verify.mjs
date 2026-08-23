// Responsibility: verify offline-queue transitions and idempotency mappings without external side effects.
import assert from 'node:assert/strict'
import { applyOutcome, belongsTo, enqueue, selectDue, start } from './queue-model.mjs'
const context = { commandId: 'C-1', idempotencyKey: 'K-fixed', payloadHash: 'H-1', subjectHash: 'U-1', environment: 'test' }
const original = enqueue({ deviceCode: 'DEV-A1B2C3' }, context)
assert.equal(original.idempotencyKey, 'K-fixed')

let replay = start(structuredClone(original))
replay = applyOutcome(replay, { kind: 'temporary', code: 'RESPONSE_LOST' }, {
  maxAttempts: 3, nextAttemptAt: (attempt) => `2026-07-17T00:0${attempt}:00Z`
})
assert.equal(replay.idempotencyKey, 'K-fixed')
assert.equal(replay.state, 'waiting-retry')
replay = start(replay)
replay = applyOutcome(replay, { kind: 'duplicate-success', workOrderId: 'WO-9' }, {})
assert.equal(replay.workOrderId, 'WO-9')
assert.equal(replay.state, 'completed')

const authBlocked = applyOutcome(start(enqueue({}, { ...context, commandId: 'C-2' })), { kind: 'unauthenticated' }, {})
assert.equal(authBlocked.state, 'blocked-auth')
const conflict = applyOutcome(start(enqueue({}, { ...context, commandId: 'C-3' })), { kind: 'conflict', code: 'DEVICE_DISABLED' }, {})
assert.equal(conflict.state, 'conflict')
const dead = { ...enqueue({}, { ...context, commandId: 'C-0' }), state: 'dead-letter' }
const next = enqueue({}, { ...context, commandId: 'C-4' })
assert.equal(selectDue([dead, next], '2026-07-17T00:00:00Z').commandId, 'C-4')
assert.equal(belongsTo(next, { subjectHash: 'U-2', environment: 'test' }), false)
console.log('UNIAPP_OFFLINE_IDEMPOTENCY_EXAMPLE_PASS checks=9 evidence=offline-queue-replay')
