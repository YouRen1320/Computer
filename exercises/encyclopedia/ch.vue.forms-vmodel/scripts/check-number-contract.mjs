import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

// Responsibility: enforce the requested input mapping without executing or rewriting learner code.
const componentUrl = new URL('../src/DurationField.vue', import.meta.url)
const source = readFileSync(fileURLToPath(componentUrl), 'utf8')
const hasNumberMapping = /v-model\.number\s*=\s*["']symptomDurationMinutes["']/.test(source)

// Mapping: mirror the chapter's deterministic "30" observation to expose string drift.
const domValue = '30'
const modelValue = hasNumberMapping ? Number.parseFloat(domValue) : domValue

if (typeof modelValue !== 'number' || modelValue !== 30) {
  console.error(`EXPECTED_RED number-contract dom=${JSON.stringify(domValue)} model=${JSON.stringify(modelValue)} type=${typeof modelValue}`)
  console.error('Add an explicit v-model.number mapping; do not change this checker.')
  process.exit(1)
}

console.log('PASS forms-vmodel exercise dom="30" model=30 type=number')

