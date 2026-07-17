import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
const data = JSON.parse(await readFile(new URL('./cases.json', import.meta.url), 'utf8'))
function diagnose(x) {
  if (new Set(x.keys).size !== 1) return 'IDEMPOTENCY_KEY_RECREATED'
  if (!Number.isInteger(x.maxAttempts) || x.attempts > x.maxAttempts || (x.attempts > 0 && !x.nextAttemptAt && x.poisonState !== 'dead-letter')) return 'UNBOUNDED_RETRY'
  if (x.poisonState === 'pending' && !x.independentProcessed) return 'POISON_HEAD_BLOCKS_QUEUE'
  return 'HEALTHY'
}
assert.equal(diagnose(data.healthy), 'HEALTHY')
const expected = { 'random-key': 'IDEMPOTENCY_KEY_RECREATED', 'retry-forever': 'UNBOUNDED_RETRY', 'head-poison': 'UNBOUNDED_RETRY' }
for (const fault of data.faults) assert.equal(diagnose(fault), expected[fault.id])
// 单独确认队头故障在达到预算并隔离后仍需允许独立命令。
assert.equal(diagnose({
  ...data.faults[2], attempts: 3, maxAttempts: 5,
  nextAttemptAt: '2026-07-17T00:03:00Z', poisonState: 'pending'
}), 'POISON_HEAD_BLOCKS_QUEUE')
console.log('UNIAPP_OFFLINE_IDEMPOTENCY_LAB_PASS cases=4 faults=3 evidence=offline-fault-oracle')
