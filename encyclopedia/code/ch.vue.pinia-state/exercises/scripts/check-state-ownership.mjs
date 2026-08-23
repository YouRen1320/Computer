import assert from 'node:assert/strict'
import { createStateModel } from '../src/state-model.mjs'

// 公共 oracle 固定验收唯一所有者、派生值和完整会话重置。
const model = createStateModel()
try {
  assert.deepEqual(model.localStatuses, model.store.statuses)
  model.resetForSessionBoundary()
  assert.equal(model.store.memberId, null)
  assert.equal(model.store.activeFilterCount, model.store.statuses.length)
} catch (error) {
  console.error(`STATE_OWNERSHIP_AMBIGUITY_EXERCISE: ${error.message}`)
  process.exit(1)
}

console.log('VUE_PINIA_STATE_EXERCISE_PASS')

