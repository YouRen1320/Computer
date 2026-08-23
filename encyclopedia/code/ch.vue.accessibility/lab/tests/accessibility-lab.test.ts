import { nextTick } from 'vue'
import { flushPromises, mount } from '@vue/test-utils'
import { afterEach, describe, expect, it, vi } from 'vitest'
import RouteHeading from '../src/RouteHeading.vue'
import WorkOrderDialog from '../src/WorkOrderDialog.vue'

afterEach(() => { document.body.innerHTML = '' })

// Responsibility: reproduce the oracle through semantic DOM, keyboard events, async text, and focus state.
describe('accessible work-order lab oracle', () => {
  it('renders one modal with an accessible-name reference', async () => {
    mount(WorkOrderDialog, { attachTo: document.body, props: { open: true, save: async () => {} } })
    await nextTick()
    const modal = document.body.querySelector('[role="dialog"]')
    expect(modal?.getAttribute('aria-modal')).toBe('true')
    expect(document.getElementById(modal?.getAttribute('aria-labelledby') ?? '')?.textContent).toBe('登记维修工单')
  })

  it('focuses the field after Teleport renders', async () => {
    mount(WorkOrderDialog, { attachTo: document.body, props: { open: true, save: async () => {} } })
    await nextTick()
    expect(document.activeElement?.id).toBe('title')
  })

  it('emits close from Escape', async () => {
    const wrapper = mount(WorkOrderDialog, { attachTo: document.body, props: { open: true, save: async () => {} } })
    await nextTick()
    document.querySelector<HTMLElement>('[role="dialog"]')?.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true, cancelable: true }))
    expect(wrapper.emitted('close')).toEqual([[]])
  })

  it('cycles forward from last to first', async () => {
    mount(WorkOrderDialog, { attachTo: document.body, props: { open: true, save: async () => {} } })
    await nextTick()
    const controls = [...document.querySelectorAll<HTMLElement>('[data-focus]')]
    controls.at(-1)?.focus()
    controls.at(-1)?.dispatchEvent(new KeyboardEvent('keydown', { key: 'Tab', bubbles: true, cancelable: true }))
    expect(document.activeElement).toBe(controls[0])
  })

  it('cycles backward from first to last', async () => {
    mount(WorkOrderDialog, { attachTo: document.body, props: { open: true, save: async () => {} } })
    await nextTick()
    const controls = [...document.querySelectorAll<HTMLElement>('[data-focus]')]
    controls[0].focus()
    controls[0].dispatchEvent(new KeyboardEvent('keydown', { key: 'Tab', shiftKey: true, bubbles: true, cancelable: true }))
    expect(document.activeElement).toBe(controls.at(-1))
  })

  it('associates a visible validation alert with the field', async () => {
    mount(WorkOrderDialog, { attachTo: document.body, props: { open: true, save: async () => {} } })
    await nextTick()
    document.querySelector<HTMLButtonElement>('button[data-focus]')?.click()
    await nextTick()
    expect(document.querySelector('[role="alert"]')?.textContent).toBe('标题不能为空')
    expect(document.querySelector('#title')?.getAttribute('aria-describedby')).toBe('title-error')
  })

  it('publishes async completion through persistent polite status text', async () => {
    const save = vi.fn(async () => {})
    mount(WorkOrderDialog, { attachTo: document.body, props: { open: true, save } })
    await nextTick()
    const field = document.querySelector<HTMLInputElement>('#title')!
    field.value = '主轴振动复核'; field.dispatchEvent(new Event('input', { bubbles: true }))
    document.querySelector<HTMLButtonElement>('button[data-focus]')?.click()
    await flushPromises()
    expect(document.querySelector('[role="status"]')?.textContent).toBe('保存成功：主轴振动复核')
    expect(save).toHaveBeenCalledWith('主轴振动复核')
  })

  it('turns a rejected save into a visible alert and field focus', async () => {
    mount(WorkOrderDialog, { attachTo: document.body, props: { open: true, save: async () => { throw new Error('网络失败') } } })
    await nextTick()
    const field = document.querySelector<HTMLInputElement>('#title')!
    field.value = '液压异常'; field.dispatchEvent(new Event('input', { bubbles: true }))
    document.querySelector<HTMLButtonElement>('button[data-focus]')?.click()
    await flushPromises()
    expect(document.querySelector('[role="alert"]')?.textContent).toBe('网络失败')
    expect(document.activeElement).toBe(field)
  })

  it('restores the invoking control after close', async () => {
    const trigger = document.createElement('button'); document.body.append(trigger); trigger.focus()
    const wrapper = mount(WorkOrderDialog, { attachTo: document.body, props: { open: false, save: async () => {} } })
    await wrapper.setProps({ open: true }); await nextTick(); await wrapper.setProps({ open: false }); await nextTick()
    expect(document.activeElement).toBe(trigger)
  })

  it('moves route context to the newly committed heading', async () => {
    const wrapper = mount(RouteHeading, { attachTo: document.body, props: { routeKey: 'queue', text: '工单队列' } })
    await wrapper.setProps({ routeKey: 'history', text: '工单历史' }); await nextTick()
    expect(document.activeElement?.textContent).toBe('工单历史')
  })
})
