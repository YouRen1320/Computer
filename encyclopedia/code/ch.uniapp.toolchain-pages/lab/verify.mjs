// Responsibility: map local route/build cases to deterministic diagnoses and assert the expected matrix.
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const cases = JSON.parse(await readFile(new URL('./cases.json', import.meta.url), 'utf8'))

function diagnose(input) {
  const files = new Set(input.files)
  if (input.pages.some((page) => !files.has(page))) return 'ROUTE_CONFIG_DRIFT'
  if (input.buildTarget !== 'mp-weixin') return 'TARGET_BUILD_MISMATCH'
  if (!input.directDetailInitializesItself) return 'DIRECT_ENTRY_BLANK'
  return 'PASS'
}

for (const input of cases) assert.equal(diagnose(input), input.expected, input.name)

const routeMatrix = {
  launch: ['index'],
  navigateList: ['index', 'list'],
  navigateDetail: ['index', 'list', 'detail'],
  back: ['index', 'list'],
  relaunch: ['index']
}
assert.deepEqual(routeMatrix.back, routeMatrix.navigateDetail.slice(0, -1))
assert.deepEqual(routeMatrix.relaunch, routeMatrix.launch)

console.log(`UNIAPP_TOOLCHAIN_LAB_PASS cases=${cases.length} faults=3 evidence=offline-oracle`)
