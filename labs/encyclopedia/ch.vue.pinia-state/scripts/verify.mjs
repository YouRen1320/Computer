import assert from 'node:assert/strict'
import { injectedFaults } from '../faults/injected-faults.mjs'
import { stateOwnerTable } from '../src/state-owner-table.mjs'
import { createLabSession } from '../src/view-store.mjs'

// 先验证四类状态各有唯一、非空的所有者。
assert.deepEqual(
  new Set(stateOwnerTable.map((entry) => entry.kind)),
  new Set(['local', 'shared-client', 'derived', 'server']),
)
assert.ok(stateOwnerTable.every((entry) => entry.owner && entry.lifetime))
assert.equal(new Set(stateOwnerTable.map((entry) => entry.name)).size, stateOwnerTable.length)

// 再验证同实例同步、storeToRefs 更新、reset 以及新容器隔离。
const sessionA = createLabSession()
sessionA.filterPanel.enterSession(101)
sessionA.filterPanel.replaceStatuses(['ASSIGNED', 'IN_PROGRESS'])
assert.deepEqual(sessionA.listPanel.statuses, ['ASSIGNED', 'IN_PROGRESS'])
assert.equal(sessionA.refs.activeFilterCount.value, 2)

const sessionB = createLabSession()
assert.equal(sessionB.listPanel.memberId, null)
assert.deepEqual(sessionB.listPanel.statuses, [])

sessionA.filterPanel.resetForSessionBoundary()
assert.equal(sessionA.listPanel.memberId, null)
assert.deepEqual(sessionA.listPanel.statuses, [])

const markers = injectedFaults.map((fault) => fault.marker)
assert.deepEqual(markers, [
  'STATE_OWNERSHIP_AMBIGUITY',
  'STORE_TO_REFS_MISSING',
  'STORE_SESSION_LEAK',
])
assert.ok(injectedFaults.every((fault) => fault.evidence.length > 20))

console.log('VUE_PINIA_STATE_LAB_PASS assertions=12 faults=3')

