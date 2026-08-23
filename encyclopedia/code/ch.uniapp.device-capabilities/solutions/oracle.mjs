import assert from 'node:assert/strict'
// Responsibility: validate the private answer.json with the public permission/device contract; violations exit nonzero.
import { readFile } from 'node:fs/promises'

const input = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
assert.equal(input.permissionResult.kind, 'denied')
assert.equal(input.locationPayloadCreated, false)
assert.equal(input.permissionRequestCount, 1)
assert.equal(input.scanCancelResult.kind, 'cancelled')
assert.equal(input.unavailableLocationResult.kind, 'unsupported')
assert.match(input.upload.attachmentId, /^ATT-/)
assert.match(input.commit.idempotencyKey, /^idem-/)
assert.equal(input.finalState, 'commit-failed')
console.log('UNIAPP_DEVICE_CAPABILITIES_PRIVATE_PASS checks=8')
