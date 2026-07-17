<script setup lang="ts">
function openWorkOrders() {
  // 路由副作用：目标页必须同时在 pages.json 注册。
  uni.navigateTo({ url: '/pages/work-orders/list' })
}
</script>

<template>
  <view class="page">
    <text>FactoryCare</text>
    <button type="button" @click="openWorkOrders">查看工单</button>
  </view>
</template>
