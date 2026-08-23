<script setup lang="ts">
// Vue 向错误组件提供失败对象；界面只显示安全摘要，不回显内部路径。
defineProps<{ error?: unknown }>()
</script>

<template>
  <section role="alert" aria-labelledby="async-error-title">
    <h2 id="async-error-title">证据面板加载失败</h2>
    <p>请检查网络后重试，主工单页面仍可使用。</p>
  </section>
</template>

