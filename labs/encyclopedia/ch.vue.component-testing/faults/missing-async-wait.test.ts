import { mount } from '@vue/test-utils'
import { expect, it } from 'vitest'
import WorkOrderSearch from '../src/WorkOrderSearch.vue'

// Injected fault: resolved gateway promises are asserted before the external-promise queue is drained.
it('incorrectly expects the result synchronously', () => {
  const wrapper = mount(WorkOrderSearch, { props: { gateway: { list: async () => [{ id: 'WO-X', title: '晚到', status: 'CREATED' as const }] } } })
  expect(wrapper.text()).toContain('WO-X')
})
