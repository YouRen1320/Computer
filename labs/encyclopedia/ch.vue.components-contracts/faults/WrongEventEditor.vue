<script setup lang="ts">
import type { Status } from '../src/contracts'

const props = defineProps<{ modelValue: Status }>()

const emit = defineEmits<{
  'status-change': [value: Status]
}>()

function changeStatus(event: Event) {
  const next = (event.target as HTMLSelectElement).value as Status
  // Injected mapping fault: parent v-model listens for update:modelValue, not status-change.
  emit('status-change', next)
}
</script>

<template>
  <label>
    错名事件编辑器
    <select :value="props.modelValue" @change="changeStatus">
      <option value="CREATED">已创建</option>
      <option value="IN_PROGRESS">处理中</option>
      <option value="COMPLETED">已完成</option>
    </select>
  </label>
</template>

