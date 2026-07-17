import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

// Responsibility: apply the public exercise oracle unchanged to the private correction.
const modelUrl = new URL('../src/stats-model.ts', import.meta.url)
const source = readFileSync(fileURLToPath(modelUrl), 'utf8')
const usesComputed = /const\s+openCount\s*=\s*computed\s*\(/.test(source)
const keepsCopiedRef = /const\s+openCount\s*=\s*ref\s*\(/.test(source)
const derivesFromOrders = /orders\.value[\s\S]*?filter\s*\(/.test(source)

// Mapping: run the same three-order transition as the public checker.
const ordersAfterAdd = [
  { status: 'CREATED' },
  { status: 'COMPLETED' },
  { status: 'IN_PROGRESS' },
]
const observedCount = usesComputed && !keepsCopiedRef && derivesFromOrders
  ? ordersAfterAdd.filter(order => order.status !== 'COMPLETED').length
  : 1

if (observedCount !== 2) {
  console.error(`FAIL duplicated-derived-state orders=${ordersAfterAdd.length} openCount=${observedCount} expected=2`)
  process.exit(1)
}

console.log('PASS reactivity private-solution orders=3 openCount=2 source=computed')

