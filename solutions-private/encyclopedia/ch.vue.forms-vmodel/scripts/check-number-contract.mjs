import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

// Responsibility: apply the same oracle as the public red exercise to the private fix.
const componentUrl = new URL('../src/DurationField.vue', import.meta.url)
const source = readFileSync(fileURLToPath(componentUrl), 'utf8')
const hasNumberMapping = /v-model\.number\s*=\s*["']symptomDurationMinutes["']/.test(source)

// Mapping: a parseable DOM string must enter the corrected model as a number.
const domValue = '30'
const modelValue = hasNumberMapping ? Number.parseFloat(domValue) : domValue

if (typeof modelValue !== 'number' || modelValue !== 30) {
  console.error(`FAIL number-contract dom=${JSON.stringify(domValue)} model=${JSON.stringify(modelValue)} type=${typeof modelValue}`)
  process.exit(1)
}

console.log('PASS forms-vmodel private-solution dom="30" model=30 type=number')

