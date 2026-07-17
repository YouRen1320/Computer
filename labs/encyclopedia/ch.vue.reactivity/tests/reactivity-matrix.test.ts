// Responsibility: verify the reactivity transition matrix and reproduce copied-derived-state drift.
// Data source: deterministic seed and added work orders plus the lab's injected fault module.
// Mapping: each mutation maps to expected dependency evaluations, identities, warnings, or DOM text.
// Side effects: mounts Vue components, triggers events, spies on console.warn, and restores the spy.

import { mount } from '@vue/test-utils'
import { describe, expect, it, vi } from 'vitest'
import StatsLab from '../src/StatsLab.vue'
import { createCopiedCountFault } from '../faults/copied-derived-state'
import { createStatsModel, observeDestructuring, observeProxyIdentity, type WorkOrder } from '../src/stats-model'

const seed: WorkOrder[] = [
  { id: 'WO-1', title: '主轴过热', status: 'CREATED', priority: 'HIGH' },
  { id: 'WO-2', title: '滤芯更换', status: 'COMPLETED', priority: 'LOW' },
  { id: 'WO-3', title: '电机异响', status: 'IN_PROGRESS', priority: 'CRITICAL' },
]

const added: WorkOrder = {
  id: 'WO-4', title: '润滑油不足', status: 'CREATED', priority: 'MEDIUM',
}

describe('reactivity state transition matrix', () => {
  it('starts computed getters lazy', () => {
    const model = createStatsModel(seed)
    expect(model.evaluations()).toEqual({ open: 0, critical: 0, visible: 0 })
  })

  it('caches repeated computed reads for one dependency version', () => {
    const model = createStatsModel(seed)
    expect(model.openCount.value).toBe(2)
    expect(model.openCount.value).toBe(2)
    expect(model.evaluations().open).toBe(1)
  })

  it('invalidates on source write but reevaluates only when read', () => {
    const model = createStatsModel(seed)
    expect(model.openCount.value).toBe(2)
    model.addOrder(added)
    expect(model.evaluations().open).toBe(1)
    expect(model.openCount.value).toBe(3)
    expect(model.evaluations().open).toBe(2)
  })

  it('keeps filter writes out of order-only dependencies', () => {
    const model = createStatsModel(seed)
    expect(model.openCount.value).toBe(2)
    expect(model.visibleOrders.value).toHaveLength(3)
    model.setFilter('COMPLETED')
    expect(model.openCount.value).toBe(2)
    expect(model.evaluations().open).toBe(1)
    expect(model.visibleOrders.value.map(order => order.id)).toEqual(['WO-2'])
    expect(model.evaluations().visible).toBe(2)
  })

  it('records stable raw and proxy identity relationships', () => {
    expect(observeProxyIdentity()).toEqual({
      rawDiffersFromProxy: true,
      sameRawReturnsSameProxy: true,
      proxyInputStaysStable: true,
    })
  })

  it('reproduces a stale destructured primitive and a linked toRef', () => {
    expect(observeDestructuring()).toEqual({
      snapshot: 'CREATED',
      proxyValue: 'IN_PROGRESS',
      linkedValue: 'IN_PROGRESS',
    })
  })

  it('rejects consumer writes through the readonly filter view', () => {
    const model = createStatsModel(seed)
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => undefined)
    ;(model.filterView as { status: string }).status = 'COMPLETED'
    expect(model.filterView.status).toBe('ALL')
    expect(warn).toHaveBeenCalled()
    warn.mockRestore()
  })

  it('stably reproduces copied derived-state drift', () => {
    const faulty = createCopiedCountFault(seed)
    expect(faulty.openCount.value).toBe(2)
    faulty.addOrder(added)
    expect(faulty.orders.value).toHaveLength(4)
    expect(faulty.openCount.value).toBe(2)
  })

  it('keeps computed count correct across add, completion, and replacement paths', () => {
    const model = createStatsModel(seed)
    model.addOrder(added)
    expect(model.openCount.value).toBe(3)
    model.completeOrder('WO-1')
    expect(model.openCount.value).toBe(2)
    model.replaceOrders([{ id: 'WO-X', title: '新工单', status: 'CREATED', priority: 'LOW' }])
    expect(model.openCount.value).toBe(1)
    expect(model.criticalCount.value).toBe(0)
  })

  it('updates DOM derivations after source and filter commands', async () => {
    const wrapper = mount(StatsLab)
    expect(wrapper.get('[data-testid="open"]').text()).toBe('开放：2')
    expect(wrapper.findAll('li')).toHaveLength(3)
    await wrapper.get('[data-testid="add"]').trigger('click')
    expect(wrapper.get('[data-testid="open"]').text()).toBe('开放：3')
    await wrapper.get('[data-testid="complete"]').trigger('click')
    expect(wrapper.get('[data-testid="open"]').text()).toBe('开放：2')
    await wrapper.get('[data-testid="filter"]').trigger('click')
    expect(wrapper.get('[data-testid="visible"]').text()).toBe('可见：2')
    expect(wrapper.findAll('li').map(item => item.text())).toEqual(['WO-1 主轴过热', 'WO-2 滤芯更换'])
  })
})
