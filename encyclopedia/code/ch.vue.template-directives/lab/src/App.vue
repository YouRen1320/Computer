<script setup lang="ts">
import WorkOrderBoard from './WorkOrderBoard.vue'
import { fixtureOrders } from './work-orders'

// 根组件只装配确定性夹具；网络加载和错误态属于服务端状态章节。
const orders = fixtureOrders
</script>

<template>
  <main><WorkOrderBoard :orders="orders" /></main>
</template>
