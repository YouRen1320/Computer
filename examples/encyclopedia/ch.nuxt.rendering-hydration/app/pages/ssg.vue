<script setup lang="ts">
// 同一公开 DTO 在构建期产生静态 HTML/payload，不包含任何会话或服务端 secret。
const { data } = await useAsyncData(
  'work-orders:ssg:v1',
  () => $fetch('/api/work-orders'),
  { deep: false },
)
</script>

<template><main><h1>SSG 工单</h1><ul><li v-for="order in data" :key="order.id">{{ order.title }}</li></ul></main></template>

