<script setup lang="ts">
import { ref, watch } from 'vue'

const props = defineProps<{ workOrderId: string }>()
const renderedOrderId = ref('')
const loadCount = ref(0)

// Important side effect: the same route component instance is reused when only the param changes.
watch(() => props.workOrderId, (nextId) => {
  renderedOrderId.value = nextId
  loadCount.value += 1
}, { immediate: true })
</script>

<template>
  <article>
    <h1 tabindex="-1" data-page-title>工单详情 {{ renderedOrderId }}</h1>
    <p data-testid="detail-id">参数：{{ renderedOrderId }}</p>
    <p data-testid="load-count">加载次数：{{ loadCount }}</p>
    <p>客户端守卫只控制导航体验；服务端仍须按会话、租户和资源授权。</p>
  </article>
</template>

