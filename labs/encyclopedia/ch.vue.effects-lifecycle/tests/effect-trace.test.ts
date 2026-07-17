import { mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { nextTick } from 'vue'
import EffectLab from '../src/EffectLab.vue'
import MissingCleanupPanel from '../faults/MissingCleanupPanel.vue'
import WrongWatchSource from '../faults/WrongWatchSource.vue'

type EffectEvidence = {
  getTrace: () => string[]
  getOrders: () => Array<{ id: string }>
  activeResources: () => number
}

async function advance(milliseconds: number) {
  // Mapping: flush timers, promise continuations, and the Vue DOM queue deterministically.
  await vi.advanceTimersByTimeAsync(milliseconds)
  await nextTick()
}

describe('lifecycle trace and cleanup counter', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it('opens one immediate resource and mounts', () => {
    const wrapper = mount(EffectLab)
    const evidence = wrapper.vm as unknown as EffectEvidence
    expect(evidence.activeResources()).toBe(1)
    expect(evidence.getTrace()).toEqual(expect.arrayContaining(['start:1:ALL', 'resource-open:ALL', 'mounted']))
  })

  it('closes a normally resolved resource', async () => {
    const wrapper = mount(EffectLab)
    const evidence = wrapper.vm as unknown as EffectEvidence
    await advance(40)
    expect(evidence.activeResources()).toBe(0)
    expect(evidence.getOrders().map(order => order.id)).toEqual(['WO-1', 'WO-2'])
    expect(evidence.getTrace()).toContain('resource-close:resolve:ALL')
  })

  it('aborts the previous resource before opening the replacement', async () => {
    const wrapper = mount(EffectLab)
    const evidence = wrapper.vm as unknown as EffectEvidence
    await wrapper.get('#lab-filter').setValue('CREATED')
    const trace = evidence.getTrace()
    expect(trace.indexOf('resource-close:abort:ALL')).toBeLessThan(trace.indexOf('resource-open:CREATED'))
    expect(evidence.activeResources()).toBe(1)
  })

  it('allows only the latest filter to commit', async () => {
    const wrapper = mount(EffectLab)
    const evidence = wrapper.vm as unknown as EffectEvidence
    await wrapper.get('#lab-filter').setValue('CREATED')
    await advance(10)
    await advance(100)
    expect(evidence.getOrders().map(order => order.id)).toEqual(['WO-1'])
    expect(evidence.getTrace()).toContain('commit:2:CREATED')
    expect(evidence.getTrace()).not.toContain('commit:1:ALL')
  })

  it('records old DOM in pre flush and new DOM in post flush', async () => {
    const wrapper = mount(EffectLab)
    const evidence = wrapper.vm as unknown as EffectEvidence
    await wrapper.get('#lab-filter').setValue('COMPLETED')
    expect(evidence.getTrace()).toContain('pre:COMPLETED:筛选：ALL')
    expect(evidence.getTrace()).toContain('post:COMPLETED:筛选：COMPLETED')
  })

  it('cleans on unmount and prevents later commits', async () => {
    const wrapper = mount(EffectLab)
    const evidence = wrapper.vm as unknown as EffectEvidence
    wrapper.unmount()
    expect(evidence.activeResources()).toBe(0)
    await advance(100)
    expect(evidence.getTrace()).toContain('unmounted')
    expect(evidence.getTrace()).not.toContain('commit:1:ALL')
  })

  it('keeps lifecycle observation non-reactive and finite', async () => {
    const wrapper = mount(EffectLab)
    const evidence = wrapper.vm as unknown as EffectEvidence
    await advance(40)
    const updated = evidence.getTrace().filter(event => event === 'updated').length
    expect(updated).toBeGreaterThan(0)
    expect(updated).toBeLessThan(5)
  })

  it('exposes accessible loading and resolved feedback', async () => {
    const wrapper = mount(EffectLab)
    expect(wrapper.get('[data-testid="feedback"]').attributes('aria-live')).toBe('polite')
    expect(wrapper.get('[data-testid="feedback"]').text()).toBe('正在加载工单')
    await advance(40)
    expect(wrapper.get('[data-testid="feedback"]').text()).toBe('结果 2 张')
  })

  it('reproduces stale overwrite when cleanup is missing', async () => {
    const wrapper = mount(MissingCleanupPanel)
    const evidence = wrapper.vm as unknown as Pick<EffectEvidence, 'getTrace' | 'activeResources'>
    await wrapper.get('#fault-filter').setValue('CREATED')
    expect(evidence.activeResources()).toBe(2)
    await advance(10)
    expect(wrapper.get('[data-testid="fault-result"]').text()).toBe('WO-1')
    await advance(30)
    expect(wrapper.get('[data-testid="fault-result"]').text()).toBe('WO-1,WO-2')
    expect(evidence.getTrace().slice(-2)).toEqual(['commit:CREATED', 'commit:ALL'])
  })

  it('reproduces a property value passed as the wrong watch source', async () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => undefined)
    const wrapper = mount(WrongWatchSource)
    const evidence = wrapper.vm as unknown as { getRuns: () => number }
    await wrapper.get('button').trigger('click')
    await nextTick()
    expect(wrapper.get('[data-testid="wrong-source"]').text()).toBe('CREATED')
    expect(evidence.getRuns()).toBe(0)
    expect(warn.mock.calls.flat().join(' ')).toContain('Invalid watch source')
    warn.mockRestore()
  })
})
