import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import CreateReportForm from '../src/CreateReportForm.vue'

const ASSET_ID = '11111111-1111-4111-8111-111111111111'
const ATTACHMENT_A = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'

// Mapping: tests read the explicit evidence output instead of reaching into component internals.
function modelOf(wrapper: ReturnType<typeof mount>) {
  return JSON.parse(wrapper.get('[data-testid="model"]').text())
}

async function fillValidForm(wrapper: ReturnType<typeof mount>) {
  // Data source: one deterministic input set is reused across payload and reset observations.
  await wrapper.get('#asset').setValue(ASSET_ID)
  await wrapper.get('#category').setValue('MECHANICAL')
  await wrapper.get('#description').setValue('主轴温度持续升高并伴随异响')
  await wrapper.get('input[value="HIGH"]').setValue(true)
  await wrapper.get('#contact').setValue('13800000000')
  await wrapper.get(`input[value="${ATTACHMENT_A}"]`).setValue(true)
  await wrapper.get('#duration').setValue('30')
  await wrapper.get('input[name="confirmed"]').setValue(true)
}

describe('CreateReportForm', () => {
  it('starts with one Vue-owned baseline in DOM and model', () => {
    const wrapper = mount(CreateReportForm)
    expect((wrapper.get('#asset').element as HTMLSelectElement).value).toBe('')
    expect((wrapper.get('#description').element as HTMLTextAreaElement).value).toBe('')
    expect(modelOf(wrapper)).toMatchObject({ priority: 'MEDIUM', attachmentIds: [], confirmed: false })
    expect(wrapper.get('[data-testid="payload"]').text()).toBe('null')
  })

  it('maps text and number controls to deliberate model types', async () => {
    const wrapper = mount(CreateReportForm)
    await wrapper.get('#description').setValue('  主轴温度持续升高并伴随异响  ')
    await wrapper.get('#duration').setValue('30')
    expect(modelOf(wrapper).description).toBe('主轴温度持续升高并伴随异响')
    expect(modelOf(wrapper).symptomDurationMinutes).toBe(30)
    expect(typeof modelOf(wrapper).symptomDurationMinutes).toBe('number')
  })

  it('uses checkbox values to maintain an attachment id array', async () => {
    const wrapper = mount(CreateReportForm)
    const checkbox = wrapper.get(`input[value="${ATTACHMENT_A}"]`)
    await checkbox.setValue(true)
    expect((checkbox.element as HTMLInputElement).checked).toBe(true)
    expect(modelOf(wrapper).attachmentIds).toEqual([ATTACHMENT_A])
    await checkbox.setValue(false)
    expect(modelOf(wrapper).attachmentIds).toEqual([])
  })

  it('keeps native required evidence alongside client errors', async () => {
    const wrapper = mount(CreateReportForm)
    const form = wrapper.get('form').element as HTMLFormElement
    expect(form.checkValidity()).toBe(false)
    await wrapper.get('form').trigger('submit')
    expect(wrapper.get('#asset').attributes('aria-invalid')).toBe('true')
    expect(wrapper.text()).toContain('故障描述至少 10 个字符')
    expect(wrapper.get('[data-testid="payload"]').text()).toBe('null')
  })

  it('projects only the authoritative CreateReportRequest fields', async () => {
    const wrapper = mount(CreateReportForm)
    await fillValidForm(wrapper)
    await wrapper.get('form').trigger('submit')
    const payload = JSON.parse(wrapper.get('[data-testid="payload"]').text())
    expect(payload).toEqual({
      assetId: ASSET_ID,
      category: 'MECHANICAL',
      description: '主轴温度持续升高并伴随异响',
      priority: 'HIGH',
      contact: '13800000000',
      attachmentIds: [ATTACHMENT_A],
    })
    expect(payload).not.toHaveProperty('confirmed')
    expect(payload).not.toHaveProperty('symptomDurationMinutes')
    expect(payload).not.toHaveProperty('tenantId')
  })

  it('captures attachment ids as a payload snapshot', async () => {
    const wrapper = mount(CreateReportForm)
    await fillValidForm(wrapper)
    await wrapper.get('form').trigger('submit')
    await wrapper.get(`input[value="${ATTACHMENT_A}"]`).setValue(false)
    expect(JSON.parse(wrapper.get('[data-testid="payload"]').text()).attachmentIds).toEqual([ATTACHMENT_A])
    expect(modelOf(wrapper).attachmentIds).toEqual([])
  })

  it('resets DOM, model, errors, and payload from one baseline', async () => {
    const wrapper = mount(CreateReportForm)
    await fillValidForm(wrapper)
    await wrapper.get('form').trigger('submit')
    await wrapper.get('button[type="button"]').trigger('click')
    expect((wrapper.get('#description').element as HTMLTextAreaElement).value).toBe('')
    expect((wrapper.get('#duration').element as HTMLInputElement).value).toBe('')
    expect(modelOf(wrapper)).toMatchObject({
      assetId: '', category: '', description: '', priority: 'MEDIUM',
      attachmentIds: [], confirmed: false, symptomDurationMinutes: '',
    })
    expect(wrapper.find('[role="alert"]').exists()).toBe(false)
    expect(wrapper.get('[data-testid="payload"]').text()).toBe('null')
  })
})

