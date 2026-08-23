<script setup lang="ts">
import type { Status } from './contracts'

defineProps<{ orderId: string }>()

// Data source: the status model remains parent-controlled and has no child default.
const status = defineModel<Status>({ required: true })
</script>

<template>
  <label>
    {{ orderId }} 状态
    <select v-model="status" :data-editor-id="orderId">
      <option value="CREATED">已创建</option>
      <option value="IN_PROGRESS">处理中</option>
      <option value="RESOLVED">已完成</option>
    </select>
  </label>
</template>

