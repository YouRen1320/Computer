import { readFile } from 'node:fs/promises'

// Responsibility: grade semantic, timing, keyboard, focus-return, and textual-feedback source evidence.
const source = await readFile(new URL('../src/WorkOrderDialog.vue', import.meta.url), 'utf8')
const required = new Map([
  ['teleport', '<Teleport to="body">'],
  ['dialog-role', 'role="dialog"'],
  ['modal-state', 'aria-modal="true"'],
  ['dialog-name', 'aria-labelledby='],
  ['explicit-label', '<label'],
  ['render-wait', 'await nextTick()'],
  ['focus-action', '.focus()'],
  ['escape-close', "event.key === 'Escape'"],
  ['tab-cycle', "event.key !== 'Tab'"],
  ['focus-return', 'returnTarget.value?.focus()'],
  ['validation-alert', 'role="alert"'],
  ['status-region', 'role="status"'],
  ['polite-live', 'aria-live="polite"'],
])
const missing = [...required].filter(([, token]) => !source.includes(token)).map(([name]) => name)
if (missing.length > 0) {
  console.error(`EXPECTED_DYNAMIC_A11Y evidence=${missing.join(',')}`)
  process.exit(9)
}
console.log('PASS dynamic-a11y semantic=green focus=sequenced keyboard=bounded feedback=textual at=UNVERIFIED')
