import assert from 'node:assert/strict'
import { injectedFaults } from '../faults/injected-faults.mjs'
import { createHydrationSnapshot, matrix } from '../src/render-matrix.mjs'

// 矩阵明确首个 HTML、两侧请求和水合方式，不允许用最终截图代替过程证据。
assert.deepEqual(matrix.map((row) => row.mode), ['ssr', 'ssg', 'csr'])
assert.deepEqual(matrix.map((row) => row.htmlHasData), [true, true, false])
assert.deepEqual(matrix.map((row) => row.browserFetches), [0, 0, 1])

const snapshot = createHydrationSnapshot({
  seed: 'seed-2026-07-17',
  isoTime: '2026-07-17T00:00:00.000Z',
  orders: [{ id: 'WO-101' }, { id: 'WO-102' }],
})
assert.equal(snapshot.serverHtml, snapshot.clientFirstHtml)
assert.equal(JSON.parse(JSON.stringify(snapshot.payload)).seed, 'seed-2026-07-17')

assert.deepEqual(injectedFaults.map((fault) => fault.marker), [
  'SERVER_BROWSER_API_LEAK',
  'HYDRATION_RANDOM_MISMATCH',
  'HYDRATION_TIMEZONE_MISMATCH',
])
assert.ok(injectedFaults.every((fault) => fault.stage && fault.evidence.length > 20))

console.log('NUXT_RENDERING_HYDRATION_LAB_PASS matrix=3 faults=3')

