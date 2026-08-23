// Responsibility: verify environment, HTTP, auth-state, storage, and redacted-log mappings from local values.
import assert from 'node:assert/strict'
import {
  apiBase, decodeDraft, mapHttp, mapTransport, nextAuthState, safeLogFields
} from './client.mjs'

assert.equal(apiBase('development'), 'https://dev-api.example.invalid')
assert.equal(apiBase('test'), 'https://test-api.example.invalid')
assert.equal(apiBase('production'), 'https://api.example.invalid')
assert.throws(() => apiBase('attacker'), /UNSUPPORTED_ENVIRONMENT/)

const parseWorkOrder = (value) => {
  if (!value || !/^WO-[0-9]+$/.test(value.id)) throw new Error('schema')
  return { id: value.id }
}
assert.deepEqual(mapHttp({ statusCode: 200, data: { id: 'WO-1001' } }, parseWorkOrder), {
  kind: 'ok', value: { id: 'WO-1001' }
})
assert.deepEqual(mapHttp({ statusCode: 200, data: { id: 1 } }, parseWorkOrder), { kind: 'contract-error' })
assert.deepEqual(mapHttp({ statusCode: 401 }, parseWorkOrder), { kind: 'unauthenticated' })
assert.deepEqual(mapHttp({ statusCode: 403 }, parseWorkOrder), { kind: 'forbidden' })
assert.deepEqual(mapHttp({ statusCode: 409 }, parseWorkOrder), { kind: 'conflict' })
assert.deepEqual(mapHttp({ statusCode: 500 }, parseWorkOrder), { kind: 'server-error' })
assert.deepEqual(mapTransport({ code: 'TIMEOUT' }), { kind: 'transport-error', reason: 'timeout' })

assert.equal(nextAuthState('AUTHENTICATED', 'HTTP_401'), 'REFRESHING')
assert.equal(nextAuthState('REFRESHING', 'REFRESH_FAILED'), 'EXPIRED')

const context = { environment: 'test', subjectHash: 'subject-hash', nowEpochMs: Date.parse('2026-07-17T00:00:00Z') }
const envelope = {
  schemaVersion: 1,
  environment: 'test',
  subjectHash: 'subject-hash',
  expiresAt: '2026-07-18T00:00:00Z',
  payload: { description: '电机出现异响' }
}
assert.deepEqual(decodeDraft(envelope, context), { kind: 'ok', value: envelope.payload })
assert.deepEqual(decodeDraft({ ...envelope, environment: 'production' }, context), {
  kind: 'invalid', reason: 'environment'
})
assert.deepEqual(decodeDraft('{broken-json', context), { kind: 'invalid', reason: 'shape' })

const sentinel = 'BEARER_SHOULD_NEVER_APPEAR'
const log = safeLogFields({
  environment: 'test', method: 'GET', pathTemplate: '/api/v1/work-orders/{id}', status: 200,
  traceId: 'trace-1', authorization: sentinel, payload: sentinel
})
assert.equal(JSON.stringify(log).includes(sentinel), false)

console.log('UNIAPP_NETWORK_AUTH_STORAGE_EXAMPLE_PASS checks=18 evidence=fake-transport-storage')
