import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

// Responsibility: use the same public oracle against the private repaired specimen.
const source = readFileSync(fileURLToPath(new URL('../src/useWorkOrderQuery.ts', import.meta.url)), 'utf8')
const functionAt = source.indexOf('export function useWorkOrderQuery')
const statusAt = source.indexOf('const status = ref')
const stateInsideFunction = functionAt >= 0 && statusAt > functionAt
const ownsAbortController = /const\s+controller\s*=\s*new\s+AbortController\(\)/.test(source)
const registersCleanup = /onCleanup\s*\(\s*\(\)\s*=>\s*controller\.abort\(\)\s*\)/.test(source)
const passesSignal = /repository\.search\s*\(\s*nextStatus\s*,\s*controller\.signal\s*\)/.test(source)
const readonlyOutputs = /status\s*:\s*readonly\(status\)/.test(source) && /orders\s*:\s*readonly\(orders\)/.test(source)

if (!stateInsideFunction || !ownsAbortController || !registersCleanup || !passesSignal || !readonlyOutputs) {
  console.error('FAIL private composable contract')
  process.exit(1)
}
console.log('PASS composables-di solution instances=isolated cleanup=abort outputs=readonly')

