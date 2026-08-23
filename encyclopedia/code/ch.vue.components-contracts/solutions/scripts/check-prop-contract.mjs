import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

// Responsibility: apply the public one-way data-flow oracle unchanged to the private fix.
const sourceUrl = new URL('../src/StatusEditor.vue', import.meta.url)
const source = readFileSync(fileURLToPath(sourceUrl), 'utf8')
const mutatesProp = /props\.order\.status\s*=/.test(source)
const declaresEvent = /['"]request-status-change['"]\s*:\s*\[payload/.test(source)
const emitsEvent = /emit\s*\(\s*['"]request-status-change['"]\s*,\s*\{[\s\S]*?orderId\s*:\s*props\.order\.id[\s\S]*?nextStatus\s*:\s*next/.test(source)

// Mapping: require the same exact event name and two-field request payload as the exercise.
if (mutatesProp || !declaresEvent || !emitsEvent) {
  console.error(`FAIL prop-contract mutatesProp=${mutatesProp} declaresEvent=${declaresEvent} emitsExactPayload=${emitsEvent}`)
  process.exit(1)
}

console.log('PASS components-contracts private-solution prop=readonly event=request-status-change payload=exact')

