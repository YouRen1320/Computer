// Responsibility: verify package-budget and performance-model outputs from the checked-in fixture data.
import assert from 'node:assert/strict'
import { checkPackageBudget, decodeCache, findPackageCycle, summarizeSamples } from './performance-model.mjs'

const report = { mainBytes: 1400000, subpackages: { reporter: 900000, history: 800000 }, assets: [{ path: 'logo.webp', bytes: 80000 }] }
const budget = { mainBytes: 1500000, subpackageBytes: 1200000, singleAssetBytes: 180000 }
assert.deepEqual(checkPackageBudget(report, budget), { valid: true, problems: [] })
assert.equal(checkPackageBudget({ ...report, mainBytes: 1600000 }, budget).problems[0], 'MAIN_PACKAGE_BUDGET')
assert.equal(findPackageCycle({ main: ['core'], reporter: ['core'], history: ['core'], core: [] }), null)
assert.deepEqual(findPackageCycle({ reporter: ['history'], history: ['reporter'] }), ['reporter', 'history', 'reporter'])

const context = { schemaVersion: 2, environment: 'test', subjectHash: 'u1', now: '2026-07-17T00:00:00Z' }
const cache = { schemaVersion: 2, environment: 'test', subjectHash: 'u1', expiresAt: '2026-07-18T00:00:00Z', payload: ['WO-1'] }
assert.deepEqual(decodeCache(cache, context), { kind: 'ok', value: ['WO-1'] })
assert.deepEqual(decodeCache({ ...cache, schemaVersion: 1 }, context), { kind: 'invalid', reason: 'version' })
assert.deepEqual(decodeCache({ ...cache, environment: 'production' }, context), { kind: 'invalid', reason: 'environment' })
assert.deepEqual(summarizeSamples([1200, 1000, 1300, 1100, 1500]), { count: 5, min: 1000, p50: 1200, p95: 1500, max: 1500 })
console.log('UNIAPP_PACKAGES_PERFORMANCE_EXAMPLE_PASS checks=8 evidence=offline-package-cache-samples')
