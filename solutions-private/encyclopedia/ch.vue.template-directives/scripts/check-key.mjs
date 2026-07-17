import { readFile } from 'node:fs/promises'

// 私有检查器与公开矩阵使用相同输入，避免通过更换数据伪造绿色结果。
const source = await readFile(new URL('../src/WorkOrderList.vue', import.meta.url), 'utf8')
for (const marker of ['v-if=', 'v-else', 'v-for=', ':data-order-id=', '@click=', ':aria-label=']) {
  if (!source.includes(marker)) {
    console.error(`TEMPLATE_CONTRACT_FAILURE missing=${marker}`)
    process.exit(7)
  }
}

const keyExpression = source.match(/:key="([^"]+)"/u)?.[1]
const before = [{ id: 'wo-a' }, { id: 'wo-b' }]
const after = [{ id: 'wo-b' }, { id: 'wo-a' }]
const nodes = [{ token: 'alpha' }, { token: 'beta' }]
const oldByKey = new Map(before.map((order, index) => [keyExpression === 'order.id' ? order.id : index, nodes[index]]))
const patched = after.map((order, index) => oldByKey.get(keyExpression === 'order.id' ? order.id : index))

if (keyExpression !== 'order.id' || patched[0] !== nodes[1]) {
  console.error(`EXPECTED_STABLE_WORK_ORDER_KEY expression=${keyExpression ?? 'missing'}`)
  process.exit(8)
}

console.log('STABLE_WORK_ORDER_KEY_OK expression=order.id node=beta')
