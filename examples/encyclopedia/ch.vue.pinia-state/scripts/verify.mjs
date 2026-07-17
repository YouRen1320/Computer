import assert from 'node:assert/strict'
import { createViewHarness } from '../src/work-order-view-store.mjs'

// 行为链同时证明同实例同步、派生值、ref 提取、重置和跨实例隔离。
const first = createViewHarness()
assert.equal(first.filterPanel, first.listPanel)
first.filterPanel.setStatuses(['ASSIGNED', 'ASSIGNED', 'IN_PROGRESS'])
first.filterPanel.setAssignee(42)
assert.deepEqual(first.listPanel.statuses, ['ASSIGNED', 'IN_PROGRESS'])
assert.equal(first.refs.activeFilterCount.value, 3)
first.filterPanel.toggleCompact()
assert.equal(first.refs.compact.value, true)

const second = createViewHarness()
assert.deepEqual(second.listPanel.statuses, [])
assert.equal(second.refs.activeFilterCount.value, 0)
assert.equal(second.refs.compact.value, false)

first.filterPanel.resetForSessionBoundary()
assert.deepEqual(first.listPanel.statuses, [])
assert.equal(first.refs.activeFilterCount.value, 0)
assert.equal(first.refs.compact.value, false)

console.log('VUE_PINIA_STATE_EXAMPLE_PASS assertions=10')

