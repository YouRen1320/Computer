import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const cases = JSON.parse(await readFile(new URL('./cases.json', import.meta.url), 'utf8'))
const requiredHits = ['h5:supported', 'h5:unsupported', 'mp-weixin:supported', 'mp-weixin:unsupported']

function diagnose(fixture) {
  // 映射：检查顺序对应“目标构建→产物模块→分支运行→降级合同”的证据链。
  if (!fixture.targetsBuilt.includes('h5') || !fixture.targetsBuilt.includes('mp-weixin')) return 'TARGET_NOT_BUILT'
  if (!fixture.modules['mp-weixin']?.includes('weixin-adapter')) return 'WRONG_MACRO_OR_MISSING_MODULE'
  if (!fixture.modules.h5?.includes('h5-adapter')) return 'WRONG_MACRO_OR_MISSING_MODULE'
  if (requiredHits.some((hit) => !fixture.branchHits.includes(hit))) return 'DEAD_BRANCH_NOT_EXECUTED'
  if (!fixture.fallbacks['h5:share'] || !fixture.fallbacks['mp-weixin:file']) return 'MISSING_CAPABILITY_FALLBACK'
  return 'HEALTHY'
}

assert.equal(diagnose(cases.healthy), 'HEALTHY')
const expected = {
  'wrong-macro': 'WRONG_MACRO_OR_MISSING_MODULE',
  'build-only': 'DEAD_BRANCH_NOT_EXECUTED',
  'missing-fallback': 'MISSING_CAPABILITY_FALLBACK'
}
for (const fixture of cases.faults) assert.equal(diagnose(fixture), expected[fixture.id])

console.log('UNIAPP_PLATFORM_CONDITIONAL_LAB_PASS cases=4 faults=3 evidence=offline-target-oracle')
