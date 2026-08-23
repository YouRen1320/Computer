// Responsibility: validate the private answer.json with the public component/form contract; violations exit nonzero.
import { readFile } from 'node:fs/promises'

const input = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
const problems = []
if (input.tags.some((tag) => ['div', 'select'].includes(tag))) problems.push('dom-tag')
if (input.inputValuePath !== 'detail.value') problems.push('event-path')
if (input.spacingUnit !== 'rpx') problems.push('spacing-unit')
if (input.modelProp !== 'modelValue' || input.modelEvent !== 'update:modelValue') problems.push('model-pair')
if (problems.length) {
  console.error(`UNIAPP_TEMPLATE_COMPONENTS_PRIVATE_FAIL problems=${problems.join(',')}`)
  process.exit(1)
}
console.log('UNIAPP_TEMPLATE_COMPONENTS_PRIVATE_PASS')
