import assert from 'node:assert/strict'
// Responsibility: validate the private answer.json with the public testing/debugging contract; violations exit nonzero.
import { readFile } from 'node:fs/promises'
const a = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
assert.equal(a.mockShape, a.hostShape)
assert.equal(a.buildId, a.mapBuildId)
assert.equal(a.carrier, 'physical-device')
for (const key of ['target', 'runtimeVersion', 'device', 'os', 'commit', 'artifactChecksum', 'expected', 'actual']) assert.ok(a[key])
assert.ok(a.steps.length)
console.log('UNIAPP_TESTING_DEBUGGING_PRIVATE_PASS checks=12')
