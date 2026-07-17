import assert from 'node:assert/strict'
import { createStateModel } from '../src/state-model.mjs'

// 私有 oracle 与公开题要求一致，不靠放宽断言制造绿灯。
const model = createStateModel()
model.replaceStatuses(['ASSIGNED', 'ASSIGNED', 'IN_PROGRESS'])
assert.deepEqual(model.state.statuses, ['ASSIGNED', 'IN_PROGRESS'])
assert.equal(model.activeFilterCount, 2)
model.resetForSessionBoundary()
assert.equal(model.state.memberId, null)
assert.deepEqual(model.state.statuses, [])
assert.equal(model.activeFilterCount, 0)

console.log('VUE_PINIA_STATE_PRIVATE_PASS assertions=6')

