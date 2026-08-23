import assert from 'node:assert/strict'
// Responsibility: validate the private answer.json with the public offline/idempotency contract; violations exit nonzero.
import { readFile } from 'node:fs/promises'
const a = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
assert.equal(new Set(a.replayKeys).size, 1)
assert.ok(a.attemptCount <= a.maxAttempts)
assert.ok(a.nextAttemptAt)
assert.equal(a.http401State, 'blocked-auth')
assert.equal(a.http409State, 'conflict')
assert.equal(a.poisonState, 'dead-letter')
assert.equal(a.independentProcessed, true)
assert.equal(a.sentWhenOwnerMismatched, false)
console.log('UNIAPP_OFFLINE_IDEMPOTENCY_PRIVATE_PASS checks=8')
