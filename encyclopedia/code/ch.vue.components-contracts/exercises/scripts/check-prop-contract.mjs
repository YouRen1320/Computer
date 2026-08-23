import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

// Responsibility: enforce one-way ownership and the exact status-change request contract.
const sourceUrl = new URL('../src/StatusEditor.vue', import.meta.url)
const source = readFileSync(fileURLToPath(sourceUrl), 'utf8')
const mutatesProp = /props\.order\.status\s*=/.test(source)
const declaresEvent = /['"]request-status-change['"]\s*:\s*\[payload/.test(source)
const emitsEvent = /emit\s*\(\s*['"]request-status-change['"]\s*,\s*\{[\s\S]*?orderId\s*:\s*props\.order\.id[\s\S]*?nextStatus\s*:\s*next/.test(source)

// Mapping: a valid correction removes the write and exposes both identity and requested value.
if (mutatesProp || !declaresEvent || !emitsEvent) {
  console.error(`EXPECTED_RED prop-contract mutatesProp=${mutatesProp} declaresEvent=${declaresEvent} emitsExactPayload=${emitsEvent}`)
  console.error('Emit request-status-change({ orderId, nextStatus }); do not modify props.order.')
  process.exit(1)
}

console.log('PASS components-contracts exercise prop=readonly event=request-status-change payload=exact')

