<script setup lang="ts">
import { computed, reactive, ref } from 'vue'

type Priority = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'

type Draft = {
  assetId: string
  category: string
  description: string
  priority: Priority
  contact: string
  attachmentIds: string[]
}

type CreateReportRequest = {
  assetId: string
  category: string
  description: string
  priority: Priority
  contact: string | null
  attachmentIds: string[]
}

const ASSET_ID = '11111111-1111-4111-8111-111111111111'
const ATTACHMENT_A = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
const ATTACHMENT_B = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'

// Data source: these fixed choices make DOM, model, and payload observations reproducible.
const assets = [{ id: ASSET_ID, label: 'A-101 主轴泵' }]
const categories = ['MECHANICAL', 'ELECTRICAL']
const priorities: Array<{ value: Priority; label: string }> = [
  { value: 'LOW', label: '低' },
  { value: 'MEDIUM', label: '中' },
  { value: 'HIGH', label: '高' },
  { value: 'CRITICAL', label: '严重' },
]
const attachments = [
  { id: ATTACHMENT_A, name: '温度曲线.png' },
  { id: ATTACHMENT_B, name: '异响录音.wav' },
]

function createEmptyDraft(): Draft {
  return {
    assetId: '',
    category: '',
    description: '',
    priority: 'MEDIUM',
    contact: '',
    attachmentIds: [],
  }
}

// Data source: draft is the single editable source; errors and payload are derived snapshots.
const draft = reactive(createEmptyDraft())
const confirmed = ref(false)
const symptomDurationMinutes = ref<number | ''>('')
const errors = ref<Record<string, string>>({})
const submittedPayload = ref<CreateReportRequest | null>(null)

// Mapping: expose stable JSON solely so the chapter can compare model and request evidence.
const modelEvidence = computed(() => JSON.stringify({
  ...draft,
  attachmentIds: [...draft.attachmentIds],
  confirmed: confirmed.value,
  symptomDurationMinutes: symptomDurationMinutes.value,
}))
const payloadEvidence = computed(() => JSON.stringify(submittedPayload.value))

function validateDraft(): Record<string, string> {
  const next: Record<string, string> = {}
  if (!draft.assetId) next.assetId = '请选择设备'
  if (!draft.category) next.category = '请选择故障类别'
  if (draft.description.length < 10) next.description = '故障描述至少 10 个字符'
  if (draft.attachmentIds.length > 3) next.attachmentIds = '最多选择 3 个附件'
  if (!confirmed.value) next.confirmed = '请确认信息已经核对'
  return next
}

function buildPayload(): CreateReportRequest {
  // Mapping: list the API fields explicitly so UI-only state cannot cross the request boundary.
  return {
    assetId: draft.assetId,
    category: draft.category,
    description: draft.description,
    priority: draft.priority,
    contact: draft.contact === '' ? null : draft.contact,
    attachmentIds: [...draft.attachmentIds],
  }
}

function submitDraft() {
  errors.value = validateDraft()
  if (Object.keys(errors.value).length > 0) {
    submittedPayload.value = null
    return
  }

  // Side effect boundary: the example captures the request snapshot instead of sending a network request.
  submittedPayload.value = buildPayload()
}

function resetDraft() {
  // Side effect: reset every observable form surface from the same Vue-owned baseline.
  Object.assign(draft, createEmptyDraft())
  confirmed.value = false
  symptomDurationMinutes.value = ''
  errors.value = {}
  submittedPayload.value = null
}
</script>

<template>
  <form aria-labelledby="form-title" @submit.prevent="submitDraft">
    <h2 id="form-title">提交报告并创建初始工单</h2>

    <label for="asset">设备</label>
    <select
      id="asset"
      v-model="draft.assetId"
      name="assetId"
      required
      :aria-invalid="errors.assetId ? 'true' : undefined"
      aria-describedby="asset-error"
    >
      <option disabled value="">请选择设备</option>
      <option v-for="asset in assets" :key="asset.id" :value="asset.id">
        {{ asset.label }}
      </option>
    </select>
    <p v-if="errors.assetId" id="asset-error" role="alert">{{ errors.assetId }}</p>

    <label for="category">故障类别</label>
    <select
      id="category"
      v-model="draft.category"
      name="category"
      required
      :aria-invalid="errors.category ? 'true' : undefined"
      aria-describedby="category-error"
    >
      <option disabled value="">请选择类别</option>
      <option v-for="category in categories" :key="category" :value="category">
        {{ category }}
      </option>
    </select>
    <p v-if="errors.category" id="category-error" role="alert">{{ errors.category }}</p>

    <label for="description">故障描述</label>
    <textarea
      id="description"
      v-model.trim="draft.description"
      name="description"
      required
      minlength="10"
      maxlength="5000"
      :aria-invalid="errors.description ? 'true' : undefined"
      aria-describedby="description-help description-error"
    />
    <p id="description-help">描述现象、位置和发生时间，至少 10 个字符。</p>
    <p v-if="errors.description" id="description-error" role="alert">{{ errors.description }}</p>

    <fieldset>
      <legend>优先级</legend>
      <label v-for="priority in priorities" :key="priority.value">
        <input
          v-model="draft.priority"
          type="radio"
          name="priority"
          :value="priority.value"
        >
        {{ priority.label }}
      </label>
    </fieldset>

    <label for="contact">联系方式（可选）</label>
    <input id="contact" v-model.trim="draft.contact" name="contact" maxlength="200">

    <fieldset>
      <legend>已完成上传的附件</legend>
      <label v-for="attachment in attachments" :key="attachment.id">
        <input
          v-model="draft.attachmentIds"
          type="checkbox"
          name="attachmentIds"
          :value="attachment.id"
        >
        {{ attachment.name }}
      </label>
      <p v-if="errors.attachmentIds" role="alert">{{ errors.attachmentIds }}</p>
    </fieldset>

    <label for="duration">症状持续分钟（仅本地观察，不提交）</label>
    <input
      id="duration"
      v-model.number="symptomDurationMinutes"
      name="symptomDurationMinutes"
      type="number"
      min="0"
      step="1"
    >

    <label>
      <input
        v-model="confirmed"
        name="confirmed"
        type="checkbox"
        :aria-invalid="errors.confirmed ? 'true' : undefined"
      >
      我确认已核对设备和描述
    </label>
    <p v-if="errors.confirmed" role="alert">{{ errors.confirmed }}</p>

    <button type="submit">提交</button>
    <button type="button" @click="resetDraft">重置</button>

    <output data-testid="model">{{ modelEvidence }}</output>
    <output data-testid="payload">{{ payloadEvidence }}</output>
  </form>
</template>

