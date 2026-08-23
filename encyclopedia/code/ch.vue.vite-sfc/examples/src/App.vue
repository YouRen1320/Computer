<script setup lang="ts">
// 静态标记来自本地教学夹具，只用来证明脚本绑定进入根组件模板。
const entryMarker: string = 'VITE_SFC_ENTRY_OK'
</script>

<template>
  <main class="shell" data-entry-marker="VITE_SFC_ENTRY_OK">
    <p class="eyebrow">FactoryCare 学习切片</p>
    <h1>Vue 根组件已接入 Vite</h1>
    <p>{{ entryMarker }}</p>
  </main>
</template>

<style scoped>
.shell {
  max-width: 48rem;
  margin-inline: auto;
  padding: 2rem;
  color: #18212f;
  background: #f6f8fb;
}

.eyebrow {
  color: #176b47;
  font-weight: 700;
}
</style>
