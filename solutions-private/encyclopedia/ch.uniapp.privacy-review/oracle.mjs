import assert from 'node:assert/strict'
// Responsibility: validate the private answer.json with the public privacy-review contract; violations exit nonzero.
import { readFile } from 'node:fs/promises'
const a = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
assert.deepEqual(a.codeCapabilities, a.declarations)
assert.equal(a.inventory.length, 3)
for (const item of a.inventory) for (const key of ['purpose', 'source', 'retention', 'deletion', 'owner']) assert.ok(item[key])
for (const sentinel of a.sentinels) assert.equal(a.log.includes(sentinel), false)
assert.ok(Object.values(a.denialCases).every(Boolean))
assert.ok(a.releaseCommit)
assert.equal(a.deviceEvidence, true)
console.log('UNIAPP_PRIVACY_REVIEW_PRIVATE_PASS checks=22')
