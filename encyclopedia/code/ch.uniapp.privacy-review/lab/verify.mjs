// Responsibility: map local privacy cases to deterministic review findings and assert the expected matrix.
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
const data = JSON.parse(await readFile(new URL('./cases.json', import.meta.url), 'utf8'))
function diagnose(x) {
  const code = [...x.codeCapabilities].sort().join(',')
  const declared = [...x.declarations].sort().join(',')
  if (code !== declared) return 'PRIVACY_DECLARATION_DRIFT'
  if (x.log.includes(x.sentinel)) return 'SENSITIVE_LOCATION_IN_LOG'
  if (!x.optionalDenialCoreAvailable) return 'OPTIONAL_DENIAL_BLOCKS_CORE'
  return 'HEALTHY'
}
assert.equal(diagnose(data.healthy), 'HEALTHY')
const expected = { 'declaration-drift': 'PRIVACY_DECLARATION_DRIFT', 'location-log': 'SENSITIVE_LOCATION_IN_LOG', 'denial-blocks': 'OPTIONAL_DENIAL_BLOCKS_CORE' }
for (const fault of data.faults) assert.equal(diagnose(fault), expected[fault.id])
console.log('UNIAPP_PRIVACY_REVIEW_LAB_PASS cases=4 faults=3 evidence=offline-negative-oracle')
