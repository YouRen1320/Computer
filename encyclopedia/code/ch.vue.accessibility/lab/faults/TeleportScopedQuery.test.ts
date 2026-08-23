import { mount } from '@vue/test-utils'
import { expect, it } from 'vitest'
import WorkOrderDialog from '../src/WorkOrderDialog.vue'

// Injected fault: wrapper.get searches the component subtree even though Teleport moved the dialog to body.
it('queries the wrong Teleport scope', () => {
  const wrapper = mount(WorkOrderDialog, { props: { open: true, save: async () => {} } })
  expect(wrapper.get('[role="dialog"]').exists()).toBe(true)
})
