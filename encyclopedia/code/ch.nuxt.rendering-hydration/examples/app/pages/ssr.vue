<script setup lang="ts">
// 稳定 key 与无副作用 handler 让服务器结果进入 payload，水合时无需重复获取。
const { data, status, error } = await useAsyncData(
  'work-orders:ssr:v1',
  (_nuxtApp, { signal }) => $fetch('/api/work-orders', { signal }),
  { deep: false, dedupe: 'cancel' },
)
</script>

<template>
  <main><h1>SSR 工单</h1><p v-if="error" role="alert">加载失败</p><p v-else-if="status === 'pending'" role="status">加载中</p><ul v-else><li v-for="order in data" :key="order.id">{{ order.title }}</li></ul></main>
</template>

