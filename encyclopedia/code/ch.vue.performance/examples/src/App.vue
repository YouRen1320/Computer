<script setup lang="ts">
import { defineAsyncComponent, ref } from 'vue'
import AsyncError from './AsyncError.vue'
import AsyncLoading from './AsyncLoading.vue'

// 面板只在用户请求时加载；错误状态和有限重试防止动态 chunk 失败后白屏。
const EvidencePanel = defineAsyncComponent({
  loader: () => import('./EvidencePanel.vue'),
  loadingComponent: AsyncLoading,
  errorComponent: AsyncError,
  delay: 120,
  timeout: 5_000,
  onError(_error, retry, fail, attempts) {
    if (attempts <= 2) retry()
    else fail()
  },
})

const showEvidence = ref(false)
</script>

<template>
  <main>
    <h1>工单性能预算</h1>
    <p>主任务先可用，低频证据面板按需加载。</p>
    <button type="button" @click="showEvidence = !showEvidence">
      {{ showEvidence ? '关闭证据' : '加载证据' }}
    </button>
    <EvidencePanel v-if="showEvidence" />
  </main>
</template>

<style>
main { max-width: 48rem; margin: 2rem auto; padding: 1rem; font-family: system-ui, sans-serif; }
button { min-height: 44px; padding: 0.6rem 1rem; }
button:focus-visible { outline: 3px solid #0b63ce; outline-offset: 3px; }
</style>

