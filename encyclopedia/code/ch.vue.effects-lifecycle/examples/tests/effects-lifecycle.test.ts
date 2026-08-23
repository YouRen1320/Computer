import { mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { nextTick } from 'vue'
import FilterEffectPanel from '../src/FilterEffectPanel.vue'

type ExposedPanel = {
  getTrace: () => string[]
  getOrders: () => Array<{ id: string; status: string }>
}

// Mapping: flush controlled timers, promise continuations, and Vue's DOM queue in one step.
async function advance(milliseconds: number) {
  await vi.advanceTimersByTimeAsync(milliseconds)
  await nextTick()
}

describe('watch and lifecycle evidence', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it('starts the immediate watcher and records mount', () => {
    const wrapper = mount(FilterEffectPanel)
    const panel = wrapper.vm as unknown as ExposedPanel
    expect(panel.getTrace()).toEqual(expect.arrayContaining(['start:1:ALL', 'mounted']))
    expect(wrapper.get('[data-testid="status"]').text()).toBe('正在加载工单')
  })

  it('cleans the old run before the new filter can commit', async () => {
    const wrapper = mount(FilterEffectPanel)
    const panel = wrapper.vm as unknown as ExposedPanel
    await wrapper.get('#effect-filter').setValue('CREATED')
    const trace = panel.getTrace()
    expect(trace.indexOf('cleanup:1:ALL')).toBeLessThan(trace.indexOf('start:2:CREATED'))
    expect(trace).toContain('resource-abort:ALL')
  })

  it('commits only the latest result after a rapid switch', async () => {
    const wrapper = mount(FilterEffectPanel)
    const panel = wrapper.vm as unknown as ExposedPanel
    await wrapper.get('#effect-filter').setValue('CREATED')
    await advance(10)
    await advance(100)
    expect(panel.getOrders()).toEqual([{ id: 'WO-1', title: '主轴过热', status: 'CREATED' }])
    expect(panel.getTrace()).toContain('commit:2:CREATED')
    expect(panel.getTrace()).not.toContain('commit:1:ALL')
  })

  it('updates the visible list and accessible loading status', async () => {
    const wrapper = mount(FilterEffectPanel)
    expect(wrapper.get('[data-testid="status"]').attributes('role')).toBe('status')
    await wrapper.get('#effect-filter').setValue('CREATED')
    await advance(10)
    expect(wrapper.get('[data-testid="status"]').text()).toBe('已加载 1 张工单')
    expect(wrapper.findAll('li')).toHaveLength(1)
    expect(wrapper.get('li').text()).toContain('WO-1')
  })

  it('distinguishes pre-update and post-update owner DOM', async () => {
    const wrapper = mount(FilterEffectPanel)
    const panel = wrapper.vm as unknown as ExposedPanel
    await wrapper.get('#effect-filter').setValue('CREATED')
    expect(panel.getTrace()).toContain('pre-dom:CREATED:筛选：ALL')
    expect(panel.getTrace()).toContain('post-dom:CREATED:筛选：CREATED')
  })

  it('records updated after reactive DOM work', async () => {
    const wrapper = mount(FilterEffectPanel)
    const panel = wrapper.vm as unknown as ExposedPanel
    await advance(40)
    expect(panel.getTrace()).toContain('commit:1:ALL')
    expect(panel.getTrace()).toContain('updated')
    expect(wrapper.findAll('li')).toHaveLength(2)
  })

  it('cleans the active run on unmount and never commits afterwards', async () => {
    const wrapper = mount(FilterEffectPanel)
    const panel = wrapper.vm as unknown as ExposedPanel
    wrapper.unmount()
    const afterUnmount = panel.getTrace()
    expect(afterUnmount.indexOf('cleanup:1:ALL')).toBeLessThan(afterUnmount.indexOf('unmounted'))
    await advance(100)
    expect(panel.getTrace()).not.toContain('commit:1:ALL')
    expect(panel.getTrace().at(-1)).toBe('abort:1:ALL')
  })
})
