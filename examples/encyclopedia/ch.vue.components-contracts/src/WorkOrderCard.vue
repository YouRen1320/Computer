<script setup lang="ts">
import type { WorkOrder } from './work-order'

const props = defineProps<{
  order: Readonly<WorkOrder>
  selected?: boolean
}>()

const emit = defineEmits<{
  select: [payload: { orderId: string }]
}>()

function selectOrder() {
  // Mapping: emit the smallest stable identity; the parent remains the selection owner.
  emit('select', { orderId: props.order.id })
}
</script>

<template>
  <article :data-order-id="props.order.id">
    <header>
      <slot name="title" :order="props.order">
        <h3>{{ props.order.title }}</h3>
      </slot>
    </header>

    <div data-testid="metadata-region">
      <slot name="metadata" :order="props.order">
        <p>优先级：{{ props.order.priority }}</p>
      </slot>
    </div>

    <button
      type="button"
      :aria-pressed="props.selected ?? false"
      @click="selectOrder"
    >
      选择 {{ props.order.id }}
    </button>

    <div data-testid="actions-region">
      <slot name="actions" :order-id="props.order.id" :status="props.order.status">
        <span>无可用操作</span>
      </slot>
    </div>
  </article>
</template>

