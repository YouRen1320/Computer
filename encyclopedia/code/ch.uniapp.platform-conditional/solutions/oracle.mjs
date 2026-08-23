import assert from 'node:assert/strict'
// Responsibility: validate the private answer.json with the public platform-adapter contract; violations exit nonzero.
import { readFile } from 'node:fs/promises'

const input = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
assert.deepEqual(input.targetsBuilt, ['h5', 'mp-weixin'])
assert.deepEqual(input.modules.h5, ['h5-adapter'])
assert.deepEqual(input.modules['mp-weixin'], ['weixin-adapter'])
assert.equal(input.branchHits.length, 4)
assert.equal(input.fallbacks['h5:share'], 'copy-link')
assert.equal(input.fallbacks['mp-weixin:file'], 'text-only-report')
console.log('UNIAPP_PLATFORM_CONDITIONAL_PRIVATE_PASS checks=6')
