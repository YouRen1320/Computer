<script setup lang="ts">
type Status = 'CREATED' | 'IN_PROGRESS' | 'COMPLETED'
type WorkOrder = { id: string; status: Status }

const props = defineProps<{ order: WorkOrder }>()

function changeStatus(event: Event) {
  const next = (event.target as HTMLSelectElement).value as Status
  // Injected side effect fault: the child changes the parent-owned object without an event.
  props.order.status = next
}
</script>

<template>
  <label>
    工单状态
    <select :value="props.order.status" @change="changeStatus">
      <option value="CREATED">已创建</option>
      <option value="IN_PROGRESS">处理中</option>
      <option value="COMPLETED">已完成</option>
    </select>
  </label>
</template>

