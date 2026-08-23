<script setup lang="ts">
import type { WorkOrderStatus } from './contracts'

const props = defineProps<{ modelValue: WorkOrderStatus }>()
const emit = defineEmits<{ 'update:modelValue': [value: WorkOrderStatus] }>()

// Responsibility: map a visible form control to the exact parent-owned status event contract.
function update(event: Event) {
  emit('update:modelValue', (event.target as HTMLSelectElement).value as WorkOrderStatus)
}
</script>

<template>
  <label for="status-filter">工单状态</label>
  <select id="status-filter" :value="props.modelValue" @change="update">
    <option value="CREATED">已创建</option>
    <option value="IN_PROGRESS">处理中</option>
    <option value="RESOLVED">已完成</option>
  </select>
</template>
