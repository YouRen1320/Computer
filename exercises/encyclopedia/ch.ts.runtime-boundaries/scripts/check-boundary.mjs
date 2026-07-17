import assert from 'node:assert/strict'
import { parsePayload } from '../src/parse-payload.mjs'

// 公共 oracle 要求合法通过，缺失/额外/错误类型稳定失败。
const valid = { id: 'WO-1', status: 'ASSIGNED', priority: 4 }
try {
  assert.equal(parsePayload(valid).ok, true)
  assert.equal(parsePayload({ id: 'WO-1', priority: 4 }).ok, false)
  assert.equal(parsePayload({ ...valid, internalCost: 99 }).ok, false)
  assert.equal(parsePayload({ ...valid, priority: '4' }).ok, false)
} catch (error) {
  console.error(`UNVALIDATED_RUNTIME_DATA_EXERCISE: ${error.message}`)
  process.exit(1)
}
console.log('TS_RUNTIME_BOUNDARIES_EXERCISE_PASS')

