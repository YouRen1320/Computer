import { mount } from '@vue/test-utils'
import { expect, it } from 'vitest'
import WorkOrderSearch from '../src/WorkOrderSearch.vue'

// Injected fault: this test couples to a ref name, so a harmless refactor breaks it.
it('incorrectly checks a private ref', () => {
  const wrapper = mount(WorkOrderSearch, { props: { gateway: { list: async () => [] } } })
  expect((wrapper.vm as unknown as { loading: boolean }).loading).toBe(true)
})
