import { h, ref } from 'vue'
import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import ContractBoard from '../src/ContractBoard.vue'
import FilterBar from '../src/FilterBar.vue'
import OrderCard from '../src/OrderCard.vue'
import StatusEditor from '../src/StatusEditor.vue'
import MutatingStatusEditor from '../faults/MutatingStatusEditor.vue'
import WrongEventEditor from '../faults/WrongEventEditor.vue'
import { ordersFixture, type Status } from '../src/contracts'

describe('parent-child state matrix', () => {
  it('keeps filter prop unchanged until the parent handles the v-model event', async () => {
    const wrapper = mount(FilterBar, { props: { modelValue: 'ALL' } })
    await wrapper.get('select').setValue('CREATED')
    expect(wrapper.emitted('update:modelValue')).toEqual([['CREATED']])
    expect(wrapper.props('modelValue')).toBe('ALL')
  })

  it('emits a precise status editor model update', async () => {
    const wrapper = mount(StatusEditor, {
      props: { orderId: 'WO-1', modelValue: 'CREATED' },
    })
    await wrapper.get('select').setValue('IN_PROGRESS')
    expect(wrapper.emitted('update:modelValue')).toEqual([['IN_PROGRESS']])
  })

  it('renders card fallback content without mutating props', () => {
    const order = { ...ordersFixture[0] }
    const wrapper = mount(OrderCard, { props: { order, selected: false } })
    expect(wrapper.get('h3').text()).toBe('主轴过热')
    expect(wrapper.text()).toContain('状态：CREATED；优先级：HIGH')
    expect(wrapper.text()).toContain('无可用操作')
    expect(order).toEqual(ordersFixture[0])
  })

  it('emits selection with only the stable order identity', async () => {
    const wrapper = mount(OrderCard, {
      props: { order: { ...ordersFixture[0] }, selected: false },
    })
    await wrapper.get('button').trigger('click')
    expect(wrapper.emitted('select')).toEqual([[{ orderId: 'WO-1' }]])
  })

  it('passes named scoped-slot data to parent render functions', () => {
    const wrapper = mount(OrderCard, {
      props: { order: { ...ordersFixture[2] }, selected: false },
      slots: {
        title: ({ order }: { order: { id: string } }) => h('h4', `定制 ${order.id}`),
        metadata: ({ order }: { order: { priority: string } }) => h('p', `父作用域 ${order.priority}`),
        actions: ({ orderId, status }: { orderId: string; status: string }) => h('span', `${orderId}/${status}`),
      },
    })
    expect(wrapper.text()).toContain('定制 WO-3')
    expect(wrapper.text()).toContain('父作用域 CRITICAL')
    expect(wrapper.text()).toContain('WO-3/IN_PROGRESS')
  })

  it('lets the board own filtering after the child event', async () => {
    const wrapper = mount(ContractBoard)
    await wrapper.get('[data-testid="filter"]').setValue('RESOLVED')
    expect(wrapper.findAll('article')).toHaveLength(1)
    expect(wrapper.get('article').attributes('data-order-id')).toBe('WO-2')
    const evidence = JSON.parse(wrapper.get('[data-testid="evidence"]').text())
    expect(evidence.filter).toBe('RESOLVED')
  })

  it('updates parent selection and passes selected state back down', async () => {
    const wrapper = mount(ContractBoard)
    const firstCard = wrapper.findAll('article')[0]
    await firstCard.get('button').trigger('click')
    expect(wrapper.get('[data-testid="selection"]').text()).toBe('选择：WO-1')
    expect(wrapper.findAll('article')[0].get('button').attributes('aria-pressed')).toBe('true')
    expect(JSON.parse(wrapper.get('[data-testid="evidence"]').text()).events[0])
      .toEqual({ name: 'select', payload: { orderId: 'WO-1' } })
  })

  it('updates parent status only after update:modelValue', async () => {
    const wrapper = mount(ContractBoard)
    await wrapper.get('[data-editor-id="WO-1"]').setValue('IN_PROGRESS')
    const evidence = JSON.parse(wrapper.get('[data-testid="evidence"]').text())
    expect(evidence.orders[0].status).toBe('IN_PROGRESS')
    expect(evidence.events[0]).toEqual({
      name: 'update:modelValue',
      payload: { orderId: 'WO-1', next: 'IN_PROGRESS' },
    })
    expect(wrapper.get('[data-slot-order-id="WO-1"]').text()).toBe('HIGH / IN_PROGRESS')
  })

  it('detects nested Prop mutation because parent data changes without an event', async () => {
    const parentOrder = ref({ ...ordersFixture[0] })
    const wrapper = mount(MutatingStatusEditor, { props: { order: parentOrder.value } })
    await wrapper.get('select').setValue('RESOLVED')
    expect(parentOrder.value.status).toBe('RESOLVED')
    // Mapping: ignore native input/change bubbling and assert the missing component contract.
    expect(wrapper.emitted('request-status-change')).toBeUndefined()
    expect(wrapper.emitted('update:modelValue')).toBeUndefined()
  })

  it('detects an event-name drift because the parent model listener never runs', async () => {
    let parentStatus: Status = 'CREATED'
    const wrapper = mount(WrongEventEditor, {
      props: {
        modelValue: parentStatus,
        'onUpdate:modelValue': (next: Status) => { parentStatus = next },
      },
    })
    await wrapper.get('select').setValue('RESOLVED')
    expect(wrapper.emitted('status-change')).toEqual([['RESOLVED']])
    expect(wrapper.emitted('update:modelValue')).toBeUndefined()
    expect(parentStatus).toBe('CREATED')
  })
})
