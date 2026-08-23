import { defineComponent, h, nextTick, ref } from 'vue'
import { describe, expect, it } from 'vitest'
import WorkOrderList from '../src/WorkOrderList.vue'
import { fixtureOrders, type WorkOrderListItem } from '../src/work-orders'
import { createMemoryRoot, findAll, findByProp, invokeClick, memoryRenderer, nodeText } from './memory-renderer'

function mountList(initial: WorkOrderListItem[]) {
  // 可替换 ref 是测试数据源；Root 只把每次最新数组交给受测模板。
  const orders = ref(initial)
  const Root = defineComponent({
    setup: () => () => h(WorkOrderList, { orders: orders.value }),
  })
  const root = createMemoryRoot()
  const warnings: string[] = []
  const app = memoryRenderer.createApp(Root)
  app.config.warnHandler = (message) => warnings.push(message)
  app.mount(root)
  return { root, orders, warnings }
}

describe('WorkOrderList template directives', () => {
  it('renders the deterministic three-item list', () => {
    const { root } = mountList(fixtureOrders)
    const items = findAll(root, (node) => node.type === 'li')
    expect(items).toHaveLength(3)
    expect(nodeText(root)).toContain('WO-2026-002')
    expect(nodeText(root)).toContain('状态：处理中')
  })

  it('switches to the empty branch for zero items', async () => {
    const { root, orders } = mountList(fixtureOrders)
    orders.value = []
    await nextTick()
    expect(findAll(root, (node) => node.type === 'li')).toHaveLength(0)
    expect(nodeText(findByProp(root, 'data-testid', 'empty')!)).toContain('没有工单')
  })

  it('filters CLOSED through a semantic button event', async () => {
    const { root } = mountList(fixtureOrders)
    invokeClick(findByProp(root, 'data-filter', 'CLOSED')!)
    await nextTick()
    const items = findAll(root, (node) => node.type === 'li')
    expect(items).toHaveLength(1)
    expect(items[0].props['data-order-id']).toBe('wo-c')
  })

  it('binds selection text and aria-pressed', async () => {
    const { root } = mountList(fixtureOrders)
    const button = findByProp(root, 'data-select-id', 'wo-b')!
    invokeClick(button)
    await nextTick()
    expect(button.props['aria-pressed']).toBe(true)
    expect(nodeText(findByProp(root, 'data-testid', 'selected')!)).toContain('WO-2026-002')
  })

  it('preserves the same business node across reorder with id key', async () => {
    const { root, orders } = mountList(fixtureOrders)
    const before = findByProp(root, 'data-order-id', 'wo-b')
    orders.value = [fixtureOrders[1], fixtureOrders[0], fixtureOrders[2]]
    await nextTick()
    expect(findByProp(root, 'data-order-id', 'wo-b')).toBe(before)
  })

  it('emits no key warning', () => {
    const { warnings } = mountList(fixtureOrders)
    expect(warnings.filter((message) => /key/iu.test(message))).toEqual([])
  })
})
