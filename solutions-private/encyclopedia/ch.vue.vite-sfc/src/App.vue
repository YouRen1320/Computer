<script setup lang="ts">
// 根组件标记只由 Vue 模板产生，用于区分真实挂载与入口静态文本。
const marker = 'FACTORYCARE_ROOT_MOUNTED'
</script>

<template>
  <main>
    <h1>FactoryCare Vue 管理端</h1>
    <p>{{ marker }}</p>
  </main>
</template>

<style scoped>
main { padding: 2rem; }
</style>
