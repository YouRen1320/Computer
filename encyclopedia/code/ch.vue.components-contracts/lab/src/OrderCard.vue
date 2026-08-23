<script setup lang="ts">
import type { WorkOrder } from './contracts'

const props = defineProps<{
  order: Readonly<WorkOrder>
  selected: boolean
}>()

const emit = defineEmits<{
  select: [payload: { orderId: string }]
}>()

function requestSelection() {
  // Mapping: report only the stable identity so the parent owns selection mutation.
  emit('select', { orderId: props.order.id })
}
</script>

<template>
  <article :data-order-id="props.order.id">
    <slot name="title" :order="props.order">
      <h3>{{ props.order.title }}</h3>
    </slot>

    <slot name="metadata" :order="props.order">
      <p>状态：{{ props.order.status }}；优先级：{{ props.order.priority }}</p>
    </slot>

    <button
      type="button"
      :aria-pressed="props.selected"
      @click="requestSelection"
    >选择 {{ props.order.id }}</button>

    <slot name="actions" :order-id="props.order.id" :status="props.order.status">
      <span>无可用操作</span>
    </slot>
  </article>
</template>

