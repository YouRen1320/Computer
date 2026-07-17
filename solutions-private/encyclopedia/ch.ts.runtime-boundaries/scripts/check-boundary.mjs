import assert from 'node:assert/strict'
import { parsePayload } from '../src/parse-payload.mjs'

// 私有 oracle 与公开题保持完全相同的合法、缺失、额外、错误类型矩阵。
const valid = { id: 'WO-1', status: 'ASSIGNED', priority: 4 }
assert.equal(parsePayload(valid).ok, true)
assert.equal(parsePayload({ id: 'WO-1', priority: 4 }).ok, false)
assert.equal(parsePayload({ ...valid, internalCost: 99 }).ok, false)
assert.equal(parsePayload({ ...valid, priority: '4' }).ok, false)
console.log('TS_RUNTIME_BOUNDARIES_PRIVATE_PASS assertions=4')

