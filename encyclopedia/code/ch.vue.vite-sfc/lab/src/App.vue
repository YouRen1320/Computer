<script setup lang="ts">
// 该静态证据标签由组件产生，dev/build/preview 三条链应保留相同语义。
const evidenceMarker: string = 'FACTORYCARE_VITE_CHAIN_OK'
</script>

<template>
  <main class="shell" data-evidence="FACTORYCARE_VITE_CHAIN_OK">
    <p class="eyebrow">FactoryCare · G4 入口实验</p>
    <h1>Vue SFC 三条链已连接</h1>
    <p>{{ evidenceMarker }}</p>
  </main>
</template>

<style scoped>
.shell {
  max-width: 52rem;
  margin-inline: auto;
  padding: 2rem;
  color: #172033;
  background: #f7f9fc;
}

.eyebrow {
  color: #176b47;
  font-weight: 700;
}
</style>
