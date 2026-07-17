import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import WorkOrderCreationLab from '../src/WorkOrderCreationLab.vue'
import DomOnlyReset from '../faults/DomOnlyReset.vue'

const ASSET_ID = '11111111-1111-4111-8111-111111111111'
const ATTACHMENT_ID = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'

// Mapping: parse the lab's explicit evidence channels to compare model, errors, and payload.
function evidence(wrapper: ReturnType<typeof mount>, id: string) {
  return JSON.parse(wrapper.get(`[data-testid="${id}"]`).text())
}

async function validInput(wrapper: ReturnType<typeof mount>) {
  // Data source: a reusable case makes each state transition comparable.
  await wrapper.get('#lab-asset').setValue(ASSET_ID)
  await wrapper.get('#lab-category').setValue('MECHANICAL')
  await wrapper.get('#lab-description').setValue('主轴温度持续升高并伴随异响')
  await wrapper.get('input[value="HIGH"]').setValue(true)
  await wrapper.get('#lab-contact').setValue('operator@example.test')
  await wrapper.get(`input[value="${ATTACHMENT_ID}"]`).setValue(true)
  await wrapper.get('#lab-duration').setValue('45')
  await wrapper.get('input[name="confirmed"]').setValue(true)
}

describe('form state matrix', () => {
  it('aligns initial DOM and model', () => {
    const wrapper = mount(WorkOrderCreationLab)
    expect((wrapper.get('#lab-description').element as HTMLTextAreaElement).value).toBe('')
    expect(evidence(wrapper, 'model')).toMatchObject({ priority: 'MEDIUM', attachmentIds: [] })
  })

  it('trims text at the input mapping boundary', async () => {
    const wrapper = mount(WorkOrderCreationLab)
    await wrapper.get('#lab-description').setValue('  主轴温度持续升高并伴随异响  ')
    expect(evidence(wrapper, 'model').description).toBe('主轴温度持续升高并伴随异响')
  })

  it('converts a number control to a number', async () => {
    const wrapper = mount(WorkOrderCreationLab)
    await wrapper.get('#lab-duration').setValue('45')
    expect(evidence(wrapper, 'model').symptomDurationMinutes).toBe(45)
    expect(typeof evidence(wrapper, 'model').symptomDurationMinutes).toBe('number')
  })

  it('maps attachment checked state to its UUID value', async () => {
    const wrapper = mount(WorkOrderCreationLab)
    const checkbox = wrapper.get(`input[value="${ATTACHMENT_ID}"]`)
    await checkbox.setValue(true)
    expect((checkbox.element as HTMLInputElement).checked).toBe(true)
    expect(evidence(wrapper, 'model').attachmentIds).toEqual([ATTACHMENT_ID])
  })

  it('preserves native invalid evidence for empty required controls', () => {
    const wrapper = mount(WorkOrderCreationLab)
    expect((wrapper.get('form').element as HTMLFormElement).checkValidity()).toBe(false)
  })

  it('blocks an invalid payload and exposes recoverable errors', async () => {
    const wrapper = mount(WorkOrderCreationLab)
    await wrapper.get('form').trigger('submit')
    expect(evidence(wrapper, 'payload')).toBeNull()
    expect(evidence(wrapper, 'errors')).toMatchObject({ assetId: '请选择设备', confirmed: '请确认信息' })
    expect(wrapper.get('#lab-description').attributes('aria-invalid')).toBe('true')
  })

  it('creates an exact API payload without UI-only state', async () => {
    const wrapper = mount(WorkOrderCreationLab)
    await validInput(wrapper)
    await wrapper.get('form').trigger('submit')
    const payload = evidence(wrapper, 'payload')
    expect(Object.keys(payload).sort()).toEqual([
      'assetId', 'attachmentIds', 'category', 'contact', 'description', 'priority',
    ])
    expect(payload).toMatchObject({ assetId: ASSET_ID, priority: 'HIGH', attachmentIds: [ATTACHMENT_ID] })
  })

  it('keeps the submitted attachment snapshot stable', async () => {
    const wrapper = mount(WorkOrderCreationLab)
    await validInput(wrapper)
    await wrapper.get('form').trigger('submit')
    await wrapper.get(`input[value="${ATTACHMENT_ID}"]`).setValue(false)
    expect(evidence(wrapper, 'payload').attachmentIds).toEqual([ATTACHMENT_ID])
    expect(evidence(wrapper, 'model').attachmentIds).toEqual([])
  })

  it('resets DOM, model, errors, and payload together', async () => {
    const wrapper = mount(WorkOrderCreationLab)
    await validInput(wrapper)
    await wrapper.get('form').trigger('submit')
    await wrapper.get('[data-testid="reset"]').trigger('click')
    expect((wrapper.get('#lab-description').element as HTMLTextAreaElement).value).toBe('')
    expect(evidence(wrapper, 'model')).toMatchObject({ description: '', confirmed: false, symptomDurationMinutes: '' })
    expect(evidence(wrapper, 'errors')).toEqual({})
    expect(evidence(wrapper, 'payload')).toBeNull()
  })

  it('reproduces the first DOM/model divergence in a DOM-only reset', async () => {
    const wrapper = mount(DomOnlyReset)
    await wrapper.get('#fault-description').setValue('模型中保留的旧描述')
    await wrapper.get('button').trigger('click')
    expect((wrapper.get('#fault-description').element as HTMLInputElement).value).toBe('')
    expect(wrapper.get('[data-testid="fault-model"]').text()).toBe('模型中保留的旧描述')
  })
})

