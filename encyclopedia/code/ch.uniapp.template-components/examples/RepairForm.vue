<script setup lang="ts">
import { reactive } from 'vue'
import { normalizeRepairForm } from './form-model.mjs'

const emit = defineEmits<{ submit: [command: unknown] }>()
const form = reactive({
  deviceId: '',
  description: '',
  priorityText: '3',
  acceptedTerms: false
})

function onDescriptionInput(event: { detail: { value: string } }) {
  // 数据来源：宿主 input 事件；detail.value 是本组件的跨端事件合同。
  form.description = String(event.detail.value).slice(0, 500)
}

function onTermsChange(event: { detail: { value: string[] } }) {
  // checkbox-group 提供选中值数组；UI 数组映射为领域布尔值。
  form.acceptedTerms = event.detail.value.includes('accepted')
}

function submit() {
  // 映射边界：UI 字符串先经运行时校验，再向父组件发命令。
  const command = normalizeRepairForm(form)
  if (command) emit('submit', command)
}
</script>

<template>
  <form class="repair-form" @submit.prevent="submit">
    <input v-model="form.deviceId" name="deviceId" placeholder="设备编号" />
    <textarea :value="form.description" maxlength="500" @input="onDescriptionInput" />
    <input v-model="form.priorityText" name="priority" type="number" />
    <checkbox-group @change="onTermsChange">
      <label>
        <checkbox value="accepted" :checked="form.acceptedTerms" />
        <text>我确认信息真实</text>
      </label>
    </checkbox-group>
    <button type="default" form-type="submit">提交报修</button>
  </form>
</template>

<style scoped>
.repair-form {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
  padding: 32rpx;
}
</style>
