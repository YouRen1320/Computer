<script setup lang="ts">
import type { WorkOrderStatus } from './work-order'

// Data source: status stays controlled by the parent through component v-model.
const status = defineModel<WorkOrderStatus>({ required: true })
</script>

<template>
  <label>
    工单状态
    <select v-model="status" data-testid="status-editor">
      <option value="CREATED">已创建</option>
      <option value="IN_PROGRESS">处理中</option>
      <option value="COMPLETED">已完成</option>
    </select>
  </label>
</template>

