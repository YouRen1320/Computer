import { nextTick } from 'vue'
import { flushPromises, mount } from '@vue/test-utils'
import { afterEach, describe, expect, it, vi } from 'vitest'
import AccessibleWorkOrderDialog from '../src/AccessibleWorkOrderDialog.vue'
import RouteFocusRegion from '../src/RouteFocusRegion.vue'

afterEach(() => { document.body.innerHTML = '' })
const gateway = (save = vi.fn(async () => {})) => ({ save })

// Responsibility: assert semantic DOM, focus state, keyboard events, and live-region text without claiming AT output.
describe('accessible dialog contract', () => {
  it('teleports one labelled modal dialog', async () => {
    mount(AccessibleWorkOrderDialog, { attachTo: document.body, props: { open: true, gateway: gateway() } })
    await nextTick()
    const dialog = document.body.querySelector('[role="dialog"]')
    expect(dialog?.getAttribute('aria-modal')).toBe('true')
    expect(dialog?.getAttribute('aria-labelledby')).toBe('work-order-dialog-title')
  })

  it('focuses the first field after conditional rendering', async () => {
    mount(AccessibleWorkOrderDialog, { attachTo: document.body, props: { open: true, gateway: gateway() } })
    await nextTick()
    expect(document.activeElement?.id).toBe('work-order-title')
  })

  it('closes through Escape', async () => {
    const wrapper = mount(AccessibleWorkOrderDialog, { attachTo: document.body, props: { open: true, gateway: gateway() } })
    await nextTick()
    document.body.querySelector<HTMLElement>('[role="dialog"]')?.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true, cancelable: true }))
    await nextTick()
    expect(wrapper.emitted('close')).toEqual([[]])
  })

  it('wraps Tab from the last control to the first', async () => {
    mount(AccessibleWorkOrderDialog, { attachTo: document.body, props: { open: true, gateway: gateway() } })
    await nextTick()
    const controls = [...document.body.querySelectorAll<HTMLElement>('[data-dialog-focus]')]
    controls.at(-1)?.focus()
    controls.at(-1)?.dispatchEvent(new KeyboardEvent('keydown', { key: 'Tab', bubbles: true, cancelable: true }))
    expect(document.activeElement).toBe(controls[0])
  })

  it('wraps Shift+Tab from the first control to the last', async () => {
    mount(AccessibleWorkOrderDialog, { attachTo: document.body, props: { open: true, gateway: gateway() } })
    await nextTick()
    const controls = [...document.body.querySelectorAll<HTMLElement>('[data-dialog-focus]')]
    controls[0].focus()
    controls[0].dispatchEvent(new KeyboardEvent('keydown', { key: 'Tab', shiftKey: true, bubbles: true, cancelable: true }))
    expect(document.activeElement).toBe(controls.at(-1))
  })

  it('exposes an associated validation alert and restores field focus', async () => {
    mount(AccessibleWorkOrderDialog, { attachTo: document.body, props: { open: true, gateway: gateway() } })
    await nextTick()
    document.body.querySelector<HTMLButtonElement>('.actions button')?.click()
    await nextTick()
    const input = document.body.querySelector<HTMLInputElement>('#work-order-title')
    expect(document.body.querySelector('[role="alert"]')?.textContent).toContain('请输入工单标题')
    expect(input?.getAttribute('aria-describedby')).toBe('work-order-title-error')
    expect(document.activeElement).toBe(input)
  })

  it('writes async completion into the persistent polite status region', async () => {
    const save = vi.fn(async () => {})
    mount(AccessibleWorkOrderDialog, { attachTo: document.body, props: { open: true, gateway: gateway(save) } })
    await nextTick()
    const input = document.body.querySelector<HTMLInputElement>('#work-order-title')!
    input.value = '液压站复核'
    input.dispatchEvent(new Event('input', { bubbles: true }))
    document.body.querySelector<HTMLButtonElement>('.actions button')?.click()
    await flushPromises()
    const status = document.body.querySelector('[role="status"]')
    expect(status?.getAttribute('aria-live')).toBe('polite')
    expect(status?.textContent).toContain('已保存工单：液压站复核')
    expect(save).toHaveBeenCalledWith({ title: '液压站复核' })
  })

  it('returns focus to the invoking control after close commits', async () => {
    const trigger = document.createElement('button')
    document.body.append(trigger)
    trigger.focus()
    const wrapper = mount(AccessibleWorkOrderDialog, { attachTo: document.body, props: { open: false, gateway: gateway() } })
    await wrapper.setProps({ open: true })
    await nextTick()
    await wrapper.setProps({ open: false })
    await nextTick()
    expect(document.activeElement).toBe(trigger)
  })
})

describe('route focus contract', () => {
  it('focuses the newly committed heading when the route key changes', async () => {
    const wrapper = mount(RouteFocusRegion, { attachTo: document.body, props: { pageKey: 'queue', heading: '待处理工单' } })
    await wrapper.setProps({ pageKey: 'history', heading: '工单历史' })
    await nextTick()
    expect(document.activeElement?.textContent).toBe('工单历史')
    expect(document.activeElement?.getAttribute('tabindex')).toBe('-1')
  })
})
