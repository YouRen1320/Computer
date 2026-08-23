import { mount } from '@vue/test-utils'
import { expect, it } from 'vitest'
import WorkOrderSearch from './WorkOrderSearch.vue'

// Starter fault: private refs and synchronous timing cannot prove the user-visible async contract.
it('loads and selects a work order', () => {
  const wrapper = mount(WorkOrderSearch, {
    props: { gateway: { list: async () => [{ id: 'WO-9001', title: '轴承复核', status: 'CREATED' }] } },
  })
  expect((wrapper.vm as unknown as { loading: boolean }).loading).toBe(false)
  expect(wrapper.text()).toContain('WO-9001')
})
