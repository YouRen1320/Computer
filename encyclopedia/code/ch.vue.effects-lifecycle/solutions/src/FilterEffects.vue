<script setup lang="ts">
import { ref, watch } from 'vue'

// Data source: filter is the explicit request key for each watcher run.
const filter = ref<'ALL' | 'CREATED'>('ALL')
const result = ref('')

watch(filter, async (next, _previous, onCleanup) => {
  const controller = new AbortController()
  // Side effect cleanup: invalidate only the request controller owned by this run.
  onCleanup(() => controller.abort())
  const query = next === 'ALL' ? '' : `?status=${next}`
  const response = await fetch(`/api/v1/work-orders${query}`, {
    signal: controller.signal,
  })
  result.value = await response.text()
}, { immediate: true })
</script>

<template>
  <label for="filter">状态筛选</label>
  <select id="filter" v-model="filter">
    <option value="ALL">全部</option>
    <option value="CREATED">已创建</option>
  </select>
  <output>{{ result }}</output>
</template>
