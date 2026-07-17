import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

// Responsibility: verify that the learner removed the duplicated writable count at its source.
const modelUrl = new URL('../src/stats-model.ts', import.meta.url)
const source = readFileSync(fileURLToPath(modelUrl), 'utf8')
const usesComputed = /const\s+openCount\s*=\s*computed\s*\(/.test(source)
const keepsCopiedRef = /const\s+openCount\s*=\s*ref\s*\(/.test(source)
const derivesFromOrders = /orders\.value[\s\S]*?filter\s*\(/.test(source)

// Mapping: simulate the fixed transition table from one open order to three total orders.
const ordersAfterAdd = [
  { status: 'CREATED' },
  { status: 'COMPLETED' },
  { status: 'IN_PROGRESS' },
]
const initialCopiedCount = 1
const observedCount = usesComputed && !keepsCopiedRef && derivesFromOrders
  ? ordersAfterAdd.filter(order => order.status !== 'COMPLETED').length
  : initialCopiedCount

if (observedCount !== 2) {
  console.error(`EXPECTED_RED duplicated-derived-state orders=${ordersAfterAdd.length} openCount=${observedCount} expected=2`)
  console.error('Replace the copied ref with a computed derivation; do not add manual synchronization.')
  process.exit(1)
}

console.log('PASS reactivity exercise orders=3 openCount=2 source=computed')

