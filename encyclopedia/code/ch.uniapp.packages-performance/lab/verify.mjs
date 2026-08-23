// Responsibility: map local package/performance cases to the first trustworthy diagnosis offline.
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { findPackageCycle } from '../../../examples/encyclopedia/ch.uniapp.packages-performance/performance-model.mjs'
const data = JSON.parse(await readFile(new URL('./cases.json', import.meta.url), 'utf8'))
function diagnose(x) {
  if (findPackageCycle(x.graph)) return 'PACKAGE_DEPENDENCY_CYCLE'
  if (x.cache.schemaVersion !== x.currentSchemaVersion && x.cache.accepted) return 'STALE_CACHE_ACCEPTED'
  if (x.preloadBeforeInteractiveBytes > 0 && x.coldStartP50 > x.coldStartBudget) return 'PRELOAD_COLD_START_REGRESSION'
  return 'HEALTHY'
}
assert.equal(diagnose(data.healthy), 'HEALTHY')
const expected = { 'package-cycle': 'PACKAGE_DEPENDENCY_CYCLE', 'stale-cache': 'STALE_CACHE_ACCEPTED', 'preload-regression': 'PRELOAD_COLD_START_REGRESSION' }
for (const fault of data.faults) assert.equal(diagnose(fault), expected[fault.id])
console.log('UNIAPP_PACKAGES_PERFORMANCE_LAB_PASS cases=4 faults=3 evidence=offline-budget-oracle')
