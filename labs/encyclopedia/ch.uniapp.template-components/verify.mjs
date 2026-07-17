// Responsibility: map local component cases to cross-target contract diagnoses and assert the expected matrix.
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const cases = JSON.parse(await readFile(new URL('./cases.json', import.meta.url), 'utf8'))

function diagnose(input) {
  if (input.tags.some((tag) => ['div', 'select'].includes(tag))) return 'WEB_DOM_COMPONENT'
  if (input.inputValuePath !== 'detail.value') return 'HOST_EVENT_DRIFT'
  if (input.spacingUnit !== 'rpx') return 'RESPONSIVE_UNIT_DRIFT'
  if (input.modelProp !== 'modelValue' || input.modelEvent !== 'update:modelValue') return 'MODEL_CONTRACT_DRIFT'
  return 'PASS'
}

for (const input of cases) assert.equal(diagnose(input), input.expected, input.name)
console.log(`UNIAPP_TEMPLATE_COMPONENTS_LAB_PASS cases=${cases.length} faults=4 evidence=offline-oracle`)
