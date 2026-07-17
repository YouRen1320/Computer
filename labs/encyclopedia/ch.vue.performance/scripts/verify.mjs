import assert from 'node:assert/strict'
import { baseline, budget, injectedFaults, optimized } from '../src/performance-scenario.mjs'

// 同一预算先证明基线失败，再证明修复满足性能和回归约束。
assert.ok(baseline.entryBytes > budget.entryBytes)
assert.ok(baseline.updatedRows > budget.updatedRows)
assert.ok(baseline.recoveryMilliseconds > budget.recoveryMilliseconds)

assert.ok(optimized.entryBytes <= budget.entryBytes)
assert.ok(optimized.updatedRows <= budget.updatedRows)
assert.ok(optimized.recoveryMilliseconds <= budget.recoveryMilliseconds)
assert.equal(optimized.behaviorTests, true)
assert.equal(optimized.accessibilityChecks, true)

assert.deepEqual(injectedFaults.map((fault) => fault.marker), [
  'DEEP_WATCH_RENDER_STORM',
  'LAZY_BOUNDARY_STATIC_IMPORT',
  'ASYNC_COMPONENT_NO_RECOVERY',
])
assert.ok(injectedFaults.every((fault) => fault.evidence.length > 20))

console.log('VUE_PERFORMANCE_LAB_PASS budgets=3 regressions=2 faults=3')

