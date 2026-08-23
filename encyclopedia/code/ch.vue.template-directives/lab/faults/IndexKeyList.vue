<script setup lang="ts">
import type { WorkOrderListItem } from '../src/work-orders'

// 故障组件专门复现“位置被误当作业务身份”，不得用于生产列表。
defineProps<{ orders: WorkOrderListItem[] }>()
</script>

<template>
  <ul aria-label="索引 key 故障列表">
    <li v-for="(order, index) in orders" :key="index" :data-order-id="order.id">
      {{ order.number }}
    </li>
  </ul>
</template>
