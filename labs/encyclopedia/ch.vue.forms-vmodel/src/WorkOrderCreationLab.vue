<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import { emptyDraft, toCreateReportRequest, type CreateReportRequest } from './form-contract'

const ASSET_ID = '11111111-1111-4111-8111-111111111111'
const ATTACHMENT_ID = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'

// Data source: fixed option values correspond to the request contract, not their display labels.
const assets = [{ id: ASSET_ID, label: 'A-101 主轴泵' }]
const attachments = [{ id: ATTACHMENT_ID, name: '温度曲线.png' }]
const draft = reactive(emptyDraft())
const confirmed = ref(false)
const symptomDurationMinutes = ref<number | ''>('')
const errors = ref<Record<string, string>>({})
const submittedPayload = ref<CreateReportRequest | null>(null)

// Mapping: outputs make all four observation surfaces machine-readable in the lab.
const modelEvidence = computed(() => JSON.stringify({
  ...draft,
  attachmentIds: [...draft.attachmentIds],
  confirmed: confirmed.value,
  symptomDurationMinutes: symptomDurationMinutes.value,
}))
const errorEvidence = computed(() => JSON.stringify(errors.value))
const payloadEvidence = computed(() => JSON.stringify(submittedPayload.value))

function validate() {
  const next: Record<string, string> = {}
  if (!draft.assetId) next.assetId = '请选择设备'
  if (!draft.category) next.category = '请选择类别'
  if (draft.description.length < 10) next.description = '描述至少 10 个字符'
  if (!confirmed.value) next.confirmed = '请确认信息'
  return next
}

function submit() {
  errors.value = validate()
  // Side effect boundary: capture a payload snapshot; real network ownership is out of scope.
  submittedPayload.value = Object.keys(errors.value).length === 0
    ? toCreateReportRequest(draft)
    : null
}

function reset() {
  // Side effect: reset model, errors, and evidence together so DOM follows one source.
  Object.assign(draft, emptyDraft())
  confirmed.value = false
  symptomDurationMinutes.value = ''
  errors.value = {}
  submittedPayload.value = null
}
</script>

<template>
  <form @submit.prevent="submit">
    <label for="lab-asset">设备</label>
    <select id="lab-asset" v-model="draft.assetId" name="assetId" required>
      <option disabled value="">请选择设备</option>
      <option v-for="asset in assets" :key="asset.id" :value="asset.id">{{ asset.label }}</option>
    </select>
    <p v-if="errors.assetId" role="alert">{{ errors.assetId }}</p>

    <label for="lab-category">类别</label>
    <select id="lab-category" v-model="draft.category" name="category" required>
      <option disabled value="">请选择类别</option>
      <option value="MECHANICAL">机械</option>
      <option value="ELECTRICAL">电气</option>
    </select>

    <label for="lab-description">描述</label>
    <textarea
      id="lab-description"
      v-model.trim="draft.description"
      name="description"
      required
      minlength="10"
      :aria-invalid="errors.description ? 'true' : undefined"
    />
    <p v-if="errors.description" role="alert">{{ errors.description }}</p>

    <fieldset>
      <legend>优先级</legend>
      <label><input v-model="draft.priority" name="priority" type="radio" value="LOW">低</label>
      <label><input v-model="draft.priority" name="priority" type="radio" value="MEDIUM">中</label>
      <label><input v-model="draft.priority" name="priority" type="radio" value="HIGH">高</label>
      <label><input v-model="draft.priority" name="priority" type="radio" value="CRITICAL">严重</label>
    </fieldset>

    <label for="lab-contact">联系方式</label>
    <input id="lab-contact" v-model.trim="draft.contact" name="contact" maxlength="200">

    <fieldset>
      <legend>附件</legend>
      <label v-for="attachment in attachments" :key="attachment.id">
        <input
          v-model="draft.attachmentIds"
          name="attachmentIds"
          type="checkbox"
          :value="attachment.id"
        >{{ attachment.name }}
      </label>
    </fieldset>

    <label for="lab-duration">持续分钟（不提交）</label>
    <input id="lab-duration" v-model.number="symptomDurationMinutes" type="number" min="0">

    <label>
      <input v-model="confirmed" name="confirmed" type="checkbox">我已核对
    </label>
    <p v-if="errors.confirmed" role="alert">{{ errors.confirmed }}</p>

    <button type="submit">提交</button>
    <button data-testid="reset" type="button" @click="reset">重置</button>

    <output data-testid="model">{{ modelEvidence }}</output>
    <output data-testid="errors">{{ errorEvidence }}</output>
    <output data-testid="payload">{{ payloadEvidence }}</output>
  </form>
</template>

