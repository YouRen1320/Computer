import assert from 'node:assert/strict'
import { HttpError, createLatestLoader, deferred, parseJsonResponse, retry } from './latest-loader.mjs'

// 数据来源：受控响应 fixture 保留“404 仍是普通 Response”的关键 Fetch 语义。
function response(status, body) {
  let used = false
  return {
    ok: status >= 200 && status < 300,
    status,
    async readBody() {
      if (used) throw new Error('BODY_ALREADY_USED')
      used = true
      return body
    }
  }
}
assert.deepEqual(await parseJsonResponse(response(200, { id: 'wo-1' })), { id: 'wo-1' })
await assert.rejects(parseJsonResponse(response(404, { code: 'NOT_FOUND' })), (error) => error instanceof HttpError && error.status === 404)

const pending = new Map()
const loader = createLatestLoader((filter) => {
  const item = deferred()
  pending.set(filter, item)
  return item.promise // 故意忽略 signal，证明陈旧提交防线独立存在。
})
const a = loader.load('A')
const b = loader.load('B')
pending.get('B').resolve(['B'])
await b
assert.deepEqual(loader.state, { items: ['B'], loading: false, error: null })
pending.get('A').resolve(['A'])
await a
assert.deepEqual(loader.state, { items: ['B'], loading: false, error: null })

let attempts = 0
const sleeps = []
const result = await retry(async () => {
  attempts += 1
  if (attempts < 3) throw new HttpError(503, {})
  return 'ok'
}, {
  maxAttempts: 3,
  shouldRetry: (error) => error.status === 503,
  delay: (attempt) => 100 * 2 ** attempt,
  sleep: async (ms) => { sleeps.push(ms) }
})
assert.equal(result, 'ok')
assert.deepEqual(sleeps, [100, 200])
console.log('JS_FETCH_CANCELLATION_RACE_EXAMPLE_PASS checks=7 evidence=deterministic-memory-transport')
