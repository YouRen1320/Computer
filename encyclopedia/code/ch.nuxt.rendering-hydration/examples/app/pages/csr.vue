<script setup lang="ts">
// server:false 明确该路由在水合完成后由浏览器取数，并提供稳定初始 loading 状态。
const { data, status, error } = await useAsyncData(
  'work-orders:csr:v1',
  (_nuxtApp, { signal }) => $fetch('/api/work-orders', { signal }),
  { server: false, deep: false },
)
</script>

<template><main><h1>CSR 工单</h1><p v-if="error" role="alert">加载失败</p><p v-else-if="status !== 'success'" role="status">等待客户端数据</p><ul v-else><li v-for="order in data" :key="order.id">{{ order.title }}</li></ul></main></template>

