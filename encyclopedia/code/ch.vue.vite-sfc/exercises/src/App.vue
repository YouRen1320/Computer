<script setup lang="ts">
// 根组件标记用于运行期 smoke，不应被复制到入口 HTML 伪造成功。
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
