// Responsibility: verify computed invalidation, identity boundaries, readonly views, and rendered updates.
// Data source: deterministic work-order fixtures plus mounted WorkOrderStats interactions.
// Mapping: each state transition maps to one observable value, evaluation count, or DOM assertion.
// Side effects: mounts Vue components and triggers synthetic button events inside the test environment.

import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import { isReadonly } from 'vue'
import WorkOrderStats from '../src/WorkOrderStats.vue'
import { createWorkOrderStats, observeIdentityBoundaries, type WorkOrder } from '../src/work-order-stats'

const initialOrders: WorkOrder[] = [
  { id: 'WO-1', title: '主轴过热', status: 'CREATED', priority: 'HIGH' },
  { id: 'WO-2', title: '更换滤芯', status: 'RESOLVED', priority: 'LOW' },
]

describe('reactivity observations', () => {
  it('keeps a computed lazy and caches repeated reads', () => {
    const stats = createWorkOrderStats(initialOrders)
    expect(stats.evaluationCounts().open).toBe(0)
    expect(stats.openCount.value).toBe(1)
    expect(stats.openCount.value).toBe(1)
    expect(stats.evaluationCounts().open).toBe(1)
  })

  it('invalidates on a source write and reevaluates on the next read', () => {
    const stats = createWorkOrderStats(initialOrders)
    expect(stats.openCount.value).toBe(1)
    stats.addOrder({ id: 'WO-3', title: '电机异响', status: 'IN_PROGRESS', priority: 'CRITICAL' })
    expect(stats.evaluationCounts().open).toBe(1)
    expect(stats.openCount.value).toBe(2)
    expect(stats.evaluationCounts().open).toBe(2)
  })

  it('does not invalidate open count for an unrelated filter write', () => {
    const stats = createWorkOrderStats(initialOrders)
    expect(stats.openCount.value).toBe(1)
    stats.setStatusFilter('RESOLVED')
    expect(stats.openCount.value).toBe(1)
    expect(stats.evaluationCounts().open).toBe(1)
    expect(stats.visibleOrders.value.map(order => order.id)).toEqual(['WO-2'])
  })

  it('reproduces a destructured snapshot while toRef stays linked', () => {
    const evidence = observeIdentityBoundaries()
    expect(evidence.snapshot).toBe('CREATED')
    expect(evidence.proxyStatus).toBe('IN_PROGRESS')
    expect(evidence.linkedStatus).toBe('IN_PROGRESS')
  })

  it('records proxy identity and nested ref unwrapping boundaries', () => {
    const evidence = observeIdentityBoundaries()
    expect(evidence.proxyDiffersFromRaw).toBe(true)
    expect(evidence.repeatedProxyIsStable).toBe(true)
    expect(evidence.objectUnwrapped).toBe('WO-1')
    expect(evidence.arrayKeepsRefValue).toBe('WO-1')
  })

  it('exposes source views as readonly while owner commands remain writable', () => {
    const stats = createWorkOrderStats(initialOrders)
    expect(isReadonly(stats.orders)).toBe(true)
    expect(isReadonly(stats.filter)).toBe(true)
    stats.setStatusFilter('RESOLVED')
    expect(stats.filter.status).toBe('RESOLVED')
  })

  it('updates computed DOM results after source commands', async () => {
    const wrapper = mount(WorkOrderStats)
    expect(wrapper.get('[data-testid="open-count"]').text()).toBe('开放：1')
    expect(wrapper.findAll('li')).toHaveLength(2)
    await wrapper.get('button').trigger('click')
    expect(wrapper.get('[data-testid="open-count"]').text()).toBe('开放：2')
    expect(wrapper.findAll('li')).toHaveLength(3)
    await wrapper.findAll('button')[1].trigger('click')
    expect(wrapper.get('[data-testid="visible-count"]').text()).toBe('当前列表：1')
    expect(wrapper.get('li').text()).toBe('更换滤芯')
  })
})
