<script setup lang="ts">
type Status = 'CREATED' | 'IN_PROGRESS' | 'RESOLVED'
type WorkOrder = { id: string; status: Status }

const props = defineProps<{ order: Readonly<WorkOrder> }>()

const emit = defineEmits<{
  'request-status-change': [payload: { orderId: string; nextStatus: Status }]
}>()

function changeStatus(event: Event) {
  const next = (event.target as HTMLSelectElement).value as Status
  // Mapping: report a minimal command request; the parent retains mutation authority.
  emit('request-status-change', {
    orderId: props.order.id,
    nextStatus: next,
  })
}
</script>

<template>
  <label>
    工单状态
    <select :value="props.order.status" @change="changeStatus">
      <option value="CREATED">已创建</option>
      <option value="IN_PROGRESS">处理中</option>
      <option value="RESOLVED">已完成</option>
    </select>
  </label>
</template>

