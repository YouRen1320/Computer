// Responsibility: verify the example's observable cross-target contract from local source and fixture data.
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { normalizeRepairForm } from './form-model.mjs'

const card = await readFile(new URL('./WorkOrderCard.vue', import.meta.url), 'utf8')
const form = await readFile(new URL('./RepairForm.vue', import.meta.url), 'utf8')
const targets = JSON.parse(await readFile(new URL('./targets.json', import.meta.url), 'utf8'))

for (const source of [card, form]) {
  assert.doesNotMatch(source, /<(?:div|select)\b|\b(?:document|window)\s*[.[]/)
}
assert.match(card, /<view\b/)
assert.match(card, /<text\b/)
assert.match(card, /update:selected/)
assert.match(form, /event\.detail\.value/)
assert.match(form, /form-type="submit"/)
assert.match(`${card}\n${form}`, /\d+rpx/)
assert.deepEqual(targets.h5, targets['mp-weixin'])

assert.deepEqual(normalizeRepairForm({
  deviceId: ' DEV-A100 ', description: ' 电机出现异响 ', priorityText: '4', acceptedTerms: true
}), { deviceId: 'DEV-A100', description: '电机出现异响', priority: 4 })
assert.equal(normalizeRepairForm({
  deviceId: 'DEV-A100', description: '短', priorityText: '4', acceptedTerms: true
}), null)
assert.equal(normalizeRepairForm({
  deviceId: 'DEV-A100', description: '电机出现异响', priorityText: '9', acceptedTerms: true
}), null)

console.log('UNIAPP_TEMPLATE_COMPONENTS_EXAMPLE_PASS checks=12 evidence=offline-contract')
