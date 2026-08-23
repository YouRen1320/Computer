import { result } from '../src/performance-budget.mjs'

// 公共 oracle 固定阈值，失败项必须靠实现修复而不是删改验证器。
const failures = []
if (result.entryBytes > 180 * 1024) failures.push('entry')
if (result.updatedRows > 2) failures.push('renders')
if (result.recoveryMilliseconds > 5_000) failures.push('recovery')
if (!result.behaviorTests) failures.push('behavior')
if (!result.accessibilityChecks) failures.push('accessibility')

if (failures.length > 0) {
  console.error(`PERFORMANCE_BUDGET_REGRESSION_EXERCISE: ${failures.join(',')}`)
  process.exit(1)
}

console.log('VUE_PERFORMANCE_EXERCISE_PASS')

