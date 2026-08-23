<script setup lang="ts">
import type { WorkOrderSummary } from './contracts'

// Responsibility: render only the public detail prop contract; retrieval belongs to the parent boundary.
defineProps<{ order: WorkOrderSummary }>()
</script>

<template>
  <article aria-labelledby="detail-title">
    <h2 id="detail-title">工单详情 {{ order.id }}</h2>
    <p>{{ order.title }}</p>
    <p>状态：{{ order.status }}</p>
  </article>
</template>
