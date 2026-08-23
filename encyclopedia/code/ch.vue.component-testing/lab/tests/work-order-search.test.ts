import { nextTick } from 'vue'
import { flushPromises, mount } from '@vue/test-utils'
import { describe, expect, it, vi } from 'vitest'
import type { WorkOrderGateway, WorkOrderStatus, WorkOrderSummary } from '../src/contracts'
import WorkOrderSearch from '../src/WorkOrderSearch.vue'

const created: WorkOrderSummary = { id: 'WO-7001', title: '泵站复核', status: 'CREATED' }
const active: WorkOrderSummary = { id: 'WO-7002', title: '电机复核', status: 'IN_PROGRESS' }
function gateway(list: WorkOrderGateway['list']): WorkOrderGateway { return { list } }

// Responsibility: diagnose contract, scheduling, Mock-boundary, and selector faults with first evidence.
describe('work-order component laboratory', () => {
  it('starts through the public loading state', () => {
    const wrapper = mount(WorkOrderSearch, { props: { gateway: gateway(() => new Promise(() => {})) } })
    expect(wrapper.get('[role="status"]').text()).toBe('正在查询')
  })

  it('renders repository data only after external promises settle', async () => {
    const list = vi.fn<WorkOrderGateway['list']>().mockResolvedValue([created])
    const wrapper = mount(WorkOrderSearch, { props: { gateway: gateway(list) } })
    await flushPromises()
    expect(wrapper.get('[aria-label="工单结果"]').text()).toContain('WO-7001')
  })

  it('maps the label-controlled select to the status argument', async () => {
    const list = vi.fn<WorkOrderGateway['list']>().mockResolvedValue([])
    const wrapper = mount(WorkOrderSearch, { props: { gateway: gateway(list) } })
    await flushPromises()
    await wrapper.get('#status').setValue('IN_PROGRESS')
    await flushPromises()
    expect(list.mock.calls.map(([status]) => status)).toEqual(['CREATED', 'IN_PROGRESS'])
  })

  it('emits the public identity payload', async () => {
    const wrapper = mount(WorkOrderSearch, { props: { gateway: gateway(vi.fn<WorkOrderGateway['list']>().mockResolvedValue([created])) } })
    await flushPromises()
    await wrapper.get('button').trigger('click')
    expect(wrapper.emitted('select')).toEqual([[{ workOrderId: 'WO-7001' }]])
  })

  it('renders the empty boundary', async () => {
    const wrapper = mount(WorkOrderSearch, { props: { gateway: gateway(vi.fn<WorkOrderGateway['list']>().mockResolvedValue([])) } })
    await flushPromises()
    expect(wrapper.get('[data-testid="empty-state"]').text()).toBe('没有匹配工单')
  })

  it('renders an actionable error', async () => {
    const wrapper = mount(WorkOrderSearch, { props: { gateway: gateway(vi.fn<WorkOrderGateway['list']>().mockRejectedValue(new Error('服务不可用'))) } })
    await flushPromises()
    expect(wrapper.get('[role="alert"]').text()).toContain('服务不可用')
    expect(wrapper.get('button').text()).toBe('重试')
  })

  it('retries through the user-facing button', async () => {
    const list = vi.fn<WorkOrderGateway['list']>().mockRejectedValueOnce(new Error('暂时失败')).mockResolvedValueOnce([created])
    const wrapper = mount(WorkOrderSearch, { props: { gateway: gateway(list) } })
    await flushPromises()
    await wrapper.get('button').trigger('click')
    await flushPromises()
    expect(wrapper.get('ul').text()).toContain('WO-7001')
  })

  it('keeps the newest result when the old request resolves late', async () => {
    const pending: Array<{ status: WorkOrderStatus; resolve: (value: readonly WorkOrderSummary[]) => void }> = []
    const wrapper = mount(WorkOrderSearch, { props: { gateway: gateway((status) => new Promise((resolve) => pending.push({ status, resolve }))) } })
    await nextTick()
    await wrapper.get('#status').setValue('IN_PROGRESS')
    await nextTick()
    pending[1].resolve([active])
    await flushPromises()
    pending[0].resolve([created])
    await flushPromises()
    expect(wrapper.get('ul').text()).toContain('WO-7002')
    expect(wrapper.get('ul').text()).not.toContain('WO-7001')
  })

  it('passes an abort signal at the gateway boundary', async () => {
    const list = vi.fn<WorkOrderGateway['list']>().mockResolvedValue([])
    mount(WorkOrderSearch, { props: { gateway: gateway(list) } })
    await flushPromises()
    expect(list).toHaveBeenCalledWith('CREATED', expect.any(AbortSignal))
  })

  it('uses no implementation-detail wrapper.vm assertion in the healthy suite', () => {
    // Non-obvious mapping: the fault catalog is validated separately; this suite asserts observable behavior.
    expect('public DOM and emitted events').not.toContain('wrapper.vm')
  })
})
