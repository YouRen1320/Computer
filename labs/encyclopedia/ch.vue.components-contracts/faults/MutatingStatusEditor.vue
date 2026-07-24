<script setup lang="ts">
import type { Status, WorkOrder } from '../src/contracts'

const props = defineProps<{ order: WorkOrder }>()

function mutateParentObject(event: Event) {
  const next = (event.target as HTMLSelectElement).value as Status
  // Injected side effect: nested Prop mutation changes the parent object without any event contract.
  props.order.status = next
}
</script>

<template>
  <label>
    故障状态编辑器
    <select :value="props.order.status" @change="mutateParentObject">
      <option value="CREATED">已创建</option>
      <option value="IN_PROGRESS">处理中</option>
      <option value="RESOLVED">已完成</option>
    </select>
  </label>
</template>

