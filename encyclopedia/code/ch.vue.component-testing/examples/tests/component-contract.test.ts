import { nextTick } from 'vue'
import { flushPromises, mount } from '@vue/test-utils'
import { describe, expect, it, vi } from 'vitest'
import type { WorkOrderGateway, WorkOrderStatus, WorkOrderSummary } from '../src/contracts'
import WorkOrderDetail from '../src/WorkOrderDetail.vue'
import WorkOrderFilter from '../src/WorkOrderFilter.vue'
import WorkOrderSearch from '../src/WorkOrderSearch.vue'

const createdOrder: WorkOrderSummary = { id: 'WO-5001', title: '主轴振动复核', status: 'CREATED' }
const inProgressOrder: WorkOrderSummary = { id: 'WO-5002', title: '液压站压力复核', status: 'IN_PROGRESS' }

function gatewayFrom(list: WorkOrderGateway['list']): WorkOrderGateway { return { list } }

// Responsibility: assert public DOM/events and controlled async boundaries, never wrapper.vm internals.
describe('FactoryCare component contracts', () => {
  it('emits the exact filter event after a user-visible select action', async () => {
    const wrapper = mount(WorkOrderFilter, { props: { modelValue: 'CREATED' } })
    await wrapper.get('select').setValue('IN_PROGRESS')
    expect(wrapper.emitted('update:modelValue')).toEqual([['IN_PROGRESS']])
  })

  it('renders loading then repository results after promises settle', async () => {
    const list = vi.fn<WorkOrderGateway['list']>().mockResolvedValue([createdOrder])
    const wrapper = mount(WorkOrderSearch, { props: { gateway: gatewayFrom(list) } })
    expect(wrapper.get('[role="status"]').text()).toBe('正在查询工单')
    await flushPromises()
    expect(wrapper.get('[aria-label="工单结果"]').text()).toContain('WO-5001')
    expect(list).toHaveBeenCalledWith('CREATED', expect.any(AbortSignal))
  })

  it('shows an actionable error and succeeds through the public retry button', async () => {
    const list = vi.fn<WorkOrderGateway['list']>()
      .mockRejectedValueOnce(new Error('网络暂不可用'))
      .mockResolvedValueOnce([createdOrder])
    const wrapper = mount(WorkOrderSearch, { props: { gateway: gatewayFrom(list) } })
    await flushPromises()
    expect(wrapper.get('[role="alert"]').text()).toContain('网络暂不可用')
    await wrapper.get('button').trigger('click')
    await flushPromises()
    expect(wrapper.get('[aria-label="工单结果"]').text()).toContain('WO-5001')
    expect(list).toHaveBeenCalledTimes(2)
  })

  it('maps a filter action to a new repository call', async () => {
    const list = vi.fn<WorkOrderGateway['list']>().mockResolvedValue([])
    const wrapper = mount(WorkOrderSearch, { props: { gateway: gatewayFrom(list) } })
    await flushPromises()
    await wrapper.get('select').setValue('IN_PROGRESS')
    await flushPromises()
    expect(list.mock.calls.map(([status]) => status)).toEqual(['CREATED', 'IN_PROGRESS'])
  })

  it('does not let a late old response overwrite the current filter result', async () => {
    const requests: Array<{ status: WorkOrderStatus; resolve: (orders: readonly WorkOrderSummary[]) => void }> = []
    const gateway = gatewayFrom((status) => new Promise((resolve) => requests.push({ status, resolve })))
    const wrapper = mount(WorkOrderSearch, { props: { gateway } })
    await nextTick()
    await wrapper.get('select').setValue('IN_PROGRESS')
    await nextTick()
    requests[1].resolve([inProgressOrder])
    await flushPromises()
    expect(wrapper.get('ul').text()).toContain('WO-5002')
    requests[0].resolve([createdOrder])
    await flushPromises()
    expect(wrapper.get('ul').text()).toContain('WO-5002')
    expect(wrapper.get('ul').text()).not.toContain('WO-5001')
  })

  it('emits a minimal identity payload from the visible open action', async () => {
    const wrapper = mount(WorkOrderSearch, {
      props: { gateway: gatewayFrom(vi.fn<WorkOrderGateway['list']>().mockResolvedValue([createdOrder])) },
    })
    await flushPromises()
    await wrapper.get('button').trigger('click')
    expect(wrapper.emitted('select')).toEqual([[{ workOrderId: 'WO-5001' }]])
  })

  it('renders a boundary empty state without inventing a result', async () => {
    const wrapper = mount(WorkOrderSearch, {
      props: { gateway: gatewayFrom(vi.fn<WorkOrderGateway['list']>().mockResolvedValue([])) },
    })
    await flushPromises()
    expect(wrapper.get('[data-testid="empty-state"]').text()).toBe('没有符合条件的工单')
    expect(wrapper.find('ul').exists()).toBe(false)
  })

  it('renders the detail from its public readonly prop', () => {
    const wrapper = mount(WorkOrderDetail, { props: { order: createdOrder } })
    expect(wrapper.get('h2').text()).toBe('工单详情 WO-5001')
    expect(wrapper.text()).toContain('状态：CREATED')
  })
})
