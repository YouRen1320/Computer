import type { Component } from 'vue'
import { defineComponent, h, nextTick, ref } from 'vue'
import { describe, expect, it } from 'vitest'
import IndexKeyList from '../faults/IndexKeyList.vue'
import WorkOrderBoard from '../src/WorkOrderBoard.vue'
import { fixtureOrders, type WorkOrderListItem } from '../src/work-orders'
import { createMemoryRoot, findAll, findByProp, invokeClick, memoryRenderer, nodeText } from './memory-renderer'

function mountComponent(component: Component, initial: WorkOrderListItem[]) {
  // ref 驱动确定性输入替换；Root 不增加被测模板之外的列表规则。
  const orders = ref(initial)
  const Root = defineComponent({ setup: () => () => h(component, { orders: orders.value }) })
  const root = createMemoryRoot()
  const warnings: string[] = []
  const app = memoryRenderer.createApp(Root)
  app.config.warnHandler = (message) => warnings.push(message)
  app.mount(root)
  return { root, orders, warnings }
}

describe('FactoryCare directive DOM matrix', () => {
  it('renders the source-empty branch', () => {
    const { root } = mountComponent(WorkOrderBoard, [])
    expect(findAll(root, (node) => node.type === 'li')).toHaveLength(0)
    expect(nodeText(findByProp(root, 'data-testid', 'empty')!)).toContain('没有工单')
  })

  it('renders one item with bound identity and status text', () => {
    const { root } = mountComponent(WorkOrderBoard, [fixtureOrders[0]])
    const items = findAll(root, (node) => node.type === 'li')
    expect(items).toHaveLength(1)
    expect(items[0].props['data-order-id']).toBe('wo-a')
    expect(nodeText(items[0])).toContain('状态：已创建')
  })

  it('renders all three items in input order', () => {
    const { root } = mountComponent(WorkOrderBoard, fixtureOrders)
    expect(findAll(root, (node) => node.type === 'li').map((node) => node.props['data-order-id']))
      .toEqual(['wo-a', 'wo-b', 'wo-c'])
  })

  it('filters CLOSED and binds aria-pressed', async () => {
    const { root } = mountComponent(WorkOrderBoard, fixtureOrders)
    const filter = findByProp(root, 'data-filter', 'CLOSED')!
    invokeClick(filter)
    await nextTick()
    expect(filter.props['aria-pressed']).toBe(true)
    expect(findAll(root, (node) => node.type === 'li').map((node) => node.props['data-order-id']))
      .toEqual(['wo-c'])
  })

  it('shows filtered-empty even when source has items', async () => {
    const { root } = mountComponent(WorkOrderBoard, [fixtureOrders[0]])
    invokeClick(findByProp(root, 'data-filter', 'CLOSED')!)
    await nextTick()
    expect(findAll(root, (node) => node.type === 'li')).toHaveLength(0)
    expect(nodeText(findByProp(root, 'data-testid', 'empty')!)).toContain('切换筛选')
  })

  it('selects a card without inventing a work-order transition', async () => {
    const { root } = mountComponent(WorkOrderBoard, fixtureOrders)
    invokeClick(findByProp(root, 'data-order-id', 'wo-b')!)
    await nextTick()
    expect(nodeText(findByProp(root, 'data-testid', 'selected')!)).toContain('WO-2026-102')
  })

  it('stops a detail click before the card selection handler', async () => {
    const { root } = mountComponent(WorkOrderBoard, fixtureOrders)
    const event = invokeClick(findByProp(root, 'data-detail-id', 'wo-b')!)
    await nextTick()
    expect(event.stopped).toBe(true)
    expect(event.prevented).toBe(false)
    expect(nodeText(findByProp(root, 'data-testid', 'details')!)).toContain('WO-2026-102')
  })

  it('keeps the wo-b node object across reorder with id key', async () => {
    const { root, orders } = mountComponent(WorkOrderBoard, fixtureOrders)
    const before = findByProp(root, 'data-order-id', 'wo-b')
    orders.value = [fixtureOrders[1], fixtureOrders[0], fixtureOrders[2]]
    await nextTick()
    expect(findByProp(root, 'data-order-id', 'wo-b')).toBe(before)
  })

  it('observes real identity drift in the injected index-key component', async () => {
    const { root, orders } = mountComponent(IndexKeyList, fixtureOrders)
    const before = findByProp(root, 'data-order-id', 'wo-b')
    orders.value = [fixtureOrders[1], fixtureOrders[0], fixtureOrders[2]]
    await nextTick()
    expect(findByProp(root, 'data-order-id', 'wo-b')).not.toBe(before)
  })

  it('keeps healthy rendering free of key warnings', () => {
    const { warnings } = mountComponent(WorkOrderBoard, fixtureOrders)
    expect(warnings.filter((message) => /key/iu.test(message))).toEqual([])
  })
})
