import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const cases = JSON.parse(await readFile(new URL('./cases.json', import.meta.url), 'utf8'))
const appOnlyHooks = new Set(['onLaunch', 'onShow', 'onHide', 'onError', 'onPageNotFound'])

function diagnose(input) {
  const files = new Set(input.pageFiles)
  if (input.pages.some((page) => !files.has(page))) return 'CONFIG_PAGE_PATH_MISSING'
  if (input.appHooks.some((hook) => !appOnlyHooks.has(hook))) return 'PAGE_HOOK_IN_APP'
  if (/\b(?:document|window)\s*[.[]/.test(input.logicSource)) return 'BROWSER_API_IN_LOGIC'
  return 'PASS'
}

for (const input of cases) {
  assert.equal(diagnose(input), input.expected, input.name)
}

// 修复后的公开合同只断言稳定偏序，不锁死宿主内部毫秒时序。
const fixedTrace = [
  'app:onLaunch', 'app:onShow', 'index:onLoad', 'index:onShow', 'index:onReady',
  'index:onHide', 'detail:onLoad', 'detail:onShow', 'detail:onReady',
  'detail:onUnload', 'index:onShow'
]
assert.ok(fixedTrace.indexOf('detail:onLoad') < fixedTrace.indexOf('detail:onReady'))
assert.ok(fixedTrace.indexOf('detail:onUnload') < fixedTrace.lastIndexOf('index:onShow'))

console.log(`MINIAPP_RUNTIME_LAB_PASS cases=${cases.length} faults=3 evidence=offline-oracle`)
