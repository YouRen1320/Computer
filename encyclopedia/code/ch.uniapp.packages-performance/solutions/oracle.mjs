import assert from 'node:assert/strict'
// Responsibility: validate the private answer.json with the public package/performance contract; violations exit nonzero.
import { readFile } from 'node:fs/promises'
const a = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
assert.ok(a.report.mainBytes <= a.budget.mainBytes)
assert.ok(Object.values(a.report.subpackages).every((n) => n <= a.budget.subpackageBytes))
assert.ok(a.report.maxAssetBytes <= a.budget.singleAssetBytes)
assert.equal(a.cache.schemaVersion, a.cache.currentVersion)
assert.equal(a.preloadBeforeInteractiveBytes, 0)
assert.ok(a.samples.p50 <= a.budget.p50 && a.samples.p95 <= a.budget.p95)
assert.ok(Object.values(a.regressions).every(Boolean))
console.log('UNIAPP_PACKAGES_PERFORMANCE_PRIVATE_PASS checks=7')
