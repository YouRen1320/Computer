import { flushPromises, mount } from '@vue/test-utils'
import { expect, it } from 'vitest'
import WorkOrderSearch from './WorkOrderSearch.vue'

// Responsibility: prove the user-visible async lifecycle and minimal public event payload.
it('loads and selects a work order', async () => {
  const wrapper = mount(WorkOrderSearch, {
    props: { gateway: { list: async () => [{ id: 'WO-9001', title: '轴承复核', status: 'CREATED' }] } },
  })
  expect(wrapper.get('[role="status"]').text()).toContain('正在查询')
  await flushPromises()
  expect(wrapper.get('[aria-label="工单结果"]').text()).toContain('WO-9001')
  await wrapper.get('button').trigger('click')
  expect(wrapper.emitted('select')).toEqual([[{ workOrderId: 'WO-9001' }]])
})
