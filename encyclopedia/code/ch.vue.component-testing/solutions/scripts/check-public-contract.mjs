import { readFile } from 'node:fs/promises'

// Responsibility: enforce the same observable-contract rubric as the public exercise.
const source = await readFile(new URL('../src/WorkOrderSearch.test.ts', import.meta.url), 'utf8')
const missing = []
if (!source.includes('flushPromises')) missing.push('import-flushPromises')
if (!source.includes('await flushPromises()')) missing.push('await-external-promises')
if (!source.includes('[role="status"]')) missing.push('loading-public-dom')
if (!source.includes('[aria-label="工单结果"]')) missing.push('result-public-dom')
if (!source.includes("wrapper.emitted('select')")) missing.push('public-event-payload')
if (source.includes('wrapper.vm')) missing.push('remove-wrapper-vm')
if (!/trigger\(['"]click['"]\)/.test(source)) missing.push('user-action')
if (missing.length > 0) {
  console.error(`EXPECTED_COMPONENT_CONTRACT evidence=${missing.join(',')}`)
  process.exit(7)
}
console.log('PASS component-contract dom=public async=awaited event=minimal')
