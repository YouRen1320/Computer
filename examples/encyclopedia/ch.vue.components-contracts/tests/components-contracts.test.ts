import { h } from 'vue'
import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import WorkOrderBoard from '../src/WorkOrderBoard.vue'
import WorkOrderCard from '../src/WorkOrderCard.vue'
import WorkOrderFilterBar from '../src/WorkOrderFilterBar.vue'
import WorkOrderStatusEditor from '../src/WorkOrderStatusEditor.vue'
import { fixtureOrders } from '../src/work-order'

// Responsibility: observe only public Props, emitted payloads, slots, and parent DOM transitions.
describe('component contracts', () => {
  it('emits the filter component v-model update without mutating its prop', async () => {
    const wrapper = mount(WorkOrderFilterBar, { props: { modelValue: 'ALL' } })
    await wrapper.get('select').setValue('IN_PROGRESS')
    expect(wrapper.emitted('update:modelValue')).toEqual([['IN_PROGRESS']])
    expect(wrapper.props('modelValue')).toBe('ALL')
  })

  it('emits the status editor component v-model payload', async () => {
    const wrapper = mount(WorkOrderStatusEditor, { props: { modelValue: 'CREATED' } })
    await wrapper.get('select').setValue('COMPLETED')
    expect(wrapper.emitted('update:modelValue')).toEqual([['COMPLETED']])
    expect(wrapper.props('modelValue')).toBe('CREATED')
  })

  it('renders card fallback slots from readonly props', () => {
    const order = { ...fixtureOrders[0] }
    const wrapper = mount(WorkOrderCard, { props: { order } })
    expect(wrapper.get('h3').text()).toBe('主轴过热')
    expect(wrapper.get('[data-testid="metadata-region"]').text()).toBe('优先级：HIGH')
    expect(wrapper.get('[data-testid="actions-region"]').text()).toBe('无可用操作')
    expect(order.status).toBe('CREATED')
  })

  it('passes named scoped-slot data to parent-defined render functions', () => {
    const wrapper = mount(WorkOrderCard, {
      props: { order: { ...fixtureOrders[0] } },
      slots: {
        metadata: ({ order }: { order: { id: string } }) =>
          h('p', { 'data-testid': 'custom-metadata' }, `父模板读取 ${order.id}`),
        actions: ({ orderId, status }: { orderId: string; status: string }) =>
          h('span', { 'data-testid': 'custom-actions' }, `${orderId}:${status}`),
      },
    })
    expect(wrapper.get('[data-testid="custom-metadata"]').text()).toBe('父模板读取 WO-1')
    expect(wrapper.get('[data-testid="custom-actions"]').text()).toBe('WO-1:CREATED')
  })

  it('emits the card selection event with a minimal identity payload', async () => {
    const order = { ...fixtureOrders[0] }
    const wrapper = mount(WorkOrderCard, { props: { order, selected: false } })
    await wrapper.get('button').trigger('click')
    expect(wrapper.emitted('select')).toEqual([[{ orderId: 'WO-1' }]])
    expect(order).toEqual(fixtureOrders[0])
  })

  it('lets the board own filter and selection transitions', async () => {
    const wrapper = mount(WorkOrderBoard)
    await wrapper.get('[data-testid="filter-editor"]').setValue('COMPLETED')
    expect(wrapper.findAll('article')).toHaveLength(1)
    expect(wrapper.get('article').attributes('data-order-id')).toBe('WO-2')
    await wrapper.get('article button').trigger('click')
    expect(wrapper.get('[data-testid="selected"]').text()).toBe('已选择：WO-2')
    const evidence = JSON.parse(wrapper.get('[data-testid="parent-evidence"]').text())
    expect(evidence).toMatchObject({ filter: 'COMPLETED', selectedOrderId: 'WO-2' })
  })

  it('updates the parent source before passing the next status prop down', async () => {
    const wrapper = mount(WorkOrderBoard)
    const firstEditor = wrapper.findAll('[data-testid="status-editor"]')[0]
    await firstEditor.setValue('IN_PROGRESS')
    const evidence = JSON.parse(wrapper.get('[data-testid="parent-evidence"]').text())
    expect(evidence.orders[0].status).toBe('IN_PROGRESS')
    expect((wrapper.findAll('[data-testid="status-editor"]')[0].element as HTMLSelectElement).value)
      .toBe('IN_PROGRESS')
  })
})
