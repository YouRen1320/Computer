import { defineComponent, effectScope, isReadonly, nextTick } from 'vue'
import { flushPromises, mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import WorkOrderQueryPanel from '../src/WorkOrderQueryPanel.vue'
import { demoOrders, workOrderRepositoryKey } from '../src/contracts'
import { createControlledRepository, createImmediateRepository } from '../src/repository'
import { useWorkOrderQuery } from '../src/useWorkOrderQuery'

function mountPanels(repository: ReturnType<typeof createControlledRepository>['repository']) {
  const Host = defineComponent({
    components: { WorkOrderQueryPanel },
    template: '<WorkOrderQueryPanel panel-id="left"/><WorkOrderQueryPanel panel-id="right"/>',
  })
  return mount(Host, { global: { provide: { [workOrderRepositoryKey as symbol]: repository } } })
}

// Responsibility: prove the public state/effect/DI contract without inspecting component internals.
describe('useWorkOrderQuery contract', () => {
  it('creates isolated state for two component instances', async () => {
    const controlled = createControlledRepository()
    const wrapper = mountPanels(controlled.repository)
    await nextTick()
    const panels = wrapper.findAll('section')
    await panels[0].get('select').setValue('RESOLVED')
    expect((panels[0].get('select').element as HTMLSelectElement).value).toBe('RESOLVED')
    expect((panels[1].get('select').element as HTMLSelectElement).value).toBe('CREATED')
    expect(controlled.trace.filter((entry) => entry.event === 'start').map((entry) => entry.status))
      .toEqual(['CREATED', 'CREATED', 'RESOLVED'])
    wrapper.unmount()
    await flushPromises()
  })

  it('aborts invalidated work and reaches zero effects on unmount', async () => {
    const controlled = createControlledRepository()
    const wrapper = mountPanels(controlled.repository)
    await nextTick()
    expect(controlled.activeCount()).toBe(2)
    await wrapper.findAll('select')[0].setValue('IN_PROGRESS')
    expect(controlled.activeCount()).toBe(2)
    expect(controlled.trace.some((entry) => entry.event === 'abort')).toBe(true)
    wrapper.unmount()
    await flushPromises()
    expect(controlled.activeCount()).toBe(0)
  })

  it('keeps the panel contract when the injected repository is replaced', async () => {
    const callsA: Array<'CREATED' | 'IN_PROGRESS' | 'RESOLVED'> = []
    const callsB: Array<'CREATED' | 'IN_PROGRESS' | 'RESOLVED'> = []
    const mountWith = (repository: ReturnType<typeof createImmediateRepository>) => mount(WorkOrderQueryPanel, {
      props: { panelId: 'replaceable' },
      global: { provide: { [workOrderRepositoryKey as symbol]: repository } },
    })
    const first = mountWith(createImmediateRepository(demoOrders, callsA))
    const second = mountWith(createImmediateRepository(demoOrders.slice(0, 1), callsB))
    await flushPromises()
    expect(first.get('h2').text()).toBe(second.get('h2').text())
    expect(callsA).toEqual(['CREATED'])
    expect(callsB).toEqual(['CREATED'])
    first.unmount()
    second.unmount()
  })

  it('returns readonly observable refs and explicit commands', () => {
    const scope = effectScope()
    const query = scope.run(() => useWorkOrderQuery(createImmediateRepository(demoOrders)))!
    expect(isReadonly(query.status)).toBe(true)
    expect(isReadonly(query.orders)).toBe(true)
    expect(query.setStatus).toEqual(expect.any(Function))
    scope.stop()
  })

  it('maps successful repository results into the observable list', async () => {
    const scope = effectScope()
    const query = scope.run(() => useWorkOrderQuery(createImmediateRepository(demoOrders), 'IN_PROGRESS'))!
    await flushPromises()
    expect(query.orders.value.map((order) => order.id)).toEqual(['WO-1002'])
    expect(query.loading.value).toBe(false)
    scope.stop()
  })

  it('reloads the same status without duplicating mutable state', async () => {
    const calls: Array<'CREATED' | 'IN_PROGRESS' | 'RESOLVED'> = []
    const scope = effectScope()
    const query = scope.run(() => useWorkOrderQuery(createImmediateRepository(demoOrders, calls)))!
    await flushPromises()
    query.reload()
    await flushPromises()
    expect(calls).toEqual(['CREATED', 'CREATED'])
    scope.stop()
  })

  it('fails fast when the repository dependency is absent', () => {
    expect(() => mount(WorkOrderQueryPanel, { props: { panelId: 'missing' } })).toThrowError(
      'WorkOrderRepository provider is required',
    )
  })
})

