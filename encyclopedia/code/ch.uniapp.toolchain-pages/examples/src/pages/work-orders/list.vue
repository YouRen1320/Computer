<script setup lang="ts">
function openDetail(id: string) {
  // 数据来源：列表项稳定 ID；编码只保护 URL 结构，详情页仍须校验。
  uni.navigateTo({ url: `/pages/work-orders/detail?id=${encodeURIComponent(id)}` })
}
</script>

<template>
  <view class="page">
    <button type="button" @click="openDetail('WO-1001')">WO-1001</button>
  </view>
</template>
