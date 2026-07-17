import assert from 'node:assert/strict'
import { result } from '../src/performance-budget.mjs'

// 私有 oracle 与公开练习保持相同阈值，防止通过放宽标准制造绿灯。
assert.ok(result.entryBytes <= 180 * 1024)
assert.ok(result.updatedRows <= 2)
assert.ok(result.recoveryMilliseconds <= 5_000)
assert.equal(result.behaviorTests, true)
assert.equal(result.accessibilityChecks, true)

console.log('VUE_PERFORMANCE_PRIVATE_PASS assertions=5')

