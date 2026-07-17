import { readFile } from 'node:fs/promises'

// 检查器先核对模板责任，再用同一 key 表达式模拟 Vue 的同层身份匹配。
const source = await readFile(new URL('../src/WorkOrderList.vue', import.meta.url), 'utf8')
for (const marker of ['v-if=', 'v-else', 'v-for=', ':data-order-id=', '@click=', ':aria-label=']) {
  if (!source.includes(marker)) {
    console.error(`TEMPLATE_CONTRACT_FAILURE missing=${marker}`)
    process.exit(7)
  }
}

const keyExpression = source.match(/:key="([^"]+)"/u)?.[1]
if (!keyExpression) {
  console.error('EXPECTED_STABLE_WORK_ORDER_KEY missing-key')
  process.exit(8)
}

const before = [{ id: 'wo-a' }, { id: 'wo-b' }]
const after = [{ id: 'wo-b' }, { id: 'wo-a' }]
const nodes = [{ token: 'alpha' }, { token: 'beta' }]
const keyOf = (order, index) => keyExpression === 'order.id' ? order.id : index
const oldByKey = new Map(before.map((order, index) => [keyOf(order, index), nodes[index]]))
const patched = after.map((order, index) => ({ order, node: oldByKey.get(keyOf(order, index)) ?? { token: 'new' } }))
const oldB = nodes[1]
const newB = patched.find((entry) => entry.order.id === 'wo-b')?.node

if (newB !== oldB) {
  console.error(`EXPECTED_STABLE_WORK_ORDER_KEY expression=${keyExpression} oldB=${oldB.token} newB=${newB?.token ?? 'missing'}`)
  process.exit(8)
}

console.log(`STABLE_WORK_ORDER_KEY_OK expression=${keyExpression} node=${oldB.token}`)
