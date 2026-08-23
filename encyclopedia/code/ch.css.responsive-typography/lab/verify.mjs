import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const cases = JSON.parse(await readFile(new URL('./cases.json', import.meta.url), 'utf8'))
// Mapping: 先检查几何溢出声明，再检查文字增长，最后检查资源 slot 提示。
function diagnose(value) {
  if (/^\d+px$/.test(value.containerWidth) || value.childMinInlineSize !== '0') return 'RESPONSIVE_OVERFLOW_RISK'
  if (value.buttonBlockSize.startsWith('height:') || value.buttonOverflow === 'hidden' || value.fontSize === '12px') return 'TEXT_CLIPPING_RISK'
  if (value.sizes === '100vw' && value.wideSlot !== '100vw') return 'OVERSIZED_ASSET_HINT'
  return 'HEALTHY'
}
assert.equal(diagnose(cases.healthy), 'HEALTHY')
const expected = { 'fixed-layout': 'RESPONSIVE_OVERFLOW_RISK', 'text-clipping': 'TEXT_CLIPPING_RISK', 'oversized-resource': 'OVERSIZED_ASSET_HINT' }
for (const fault of cases.faults) assert.equal(diagnose(fault), expected[fault.id])
console.log('CSS_RESPONSIVE_TYPOGRAPHY_LAB_PASS cases=4 faults=3 evidence=offline-diagnostic-oracle')
