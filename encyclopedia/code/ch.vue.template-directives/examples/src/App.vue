<script setup lang="ts">
import WorkOrderList from './WorkOrderList.vue'
import { fixtureOrders } from './work-orders'

// 根组件只把固定教学数据交给列表；生产数据源属于服务端状态章节。
const orders = fixtureOrders
</script>

<template>
  <main><WorkOrderList :orders="orders" /></main>
</template>
