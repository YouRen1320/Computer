<script setup lang="ts">
// 该低频面板是独立动态 chunk，只展示安全的构建证据摘要。
const evidence = [
  '入口原始 JS ≤ 180 KiB',
  '证据面板形成动态 chunk',
  '加载失败存在有限重试与错误界面',
]
</script>

<template>
  <section aria-labelledby="evidence-title">
    <h2 id="evidence-title">验证证据</h2>
    <ul><li v-for="item in evidence" :key="item">{{ item }}</li></ul>
  </section>
</template>

