<script setup lang="ts">
import { computed, onMounted, onUnmounted, onUpdated, ref, watch } from 'vue'
import { loadOrders, type StatusFilter, type WorkOrderResult } from './controlled-loader'

// Data source: the selected filter is the only reactive trigger for external loading.
const filter = ref<StatusFilter>('ALL')
const orders = ref<WorkOrderResult[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const filterLabel = ref<HTMLElement | null>(null)

// Data source: a non-reactive trace observes lifecycle without triggering update loops.
const trace: string[] = []
let runSequence = 0
let latestRun = 0

const statusText = computed(() => {
  if (loading.value) return '正在加载工单'
  if (error.value) return error.value
  return `已加载 ${orders.value.length} 张工单`
})

watch(filter, async (next, _previous, onCleanup) => {
  const run = ++runSequence
  latestRun = run
  const controller = new AbortController()
  trace.push(`start:${run}:${next}`)

  onCleanup(() => {
    // Side effect cleanup: invalidate exactly the controller owned by this watcher run.
    trace.push(`cleanup:${run}:${next}`)
    controller.abort()
  })

  loading.value = true
  error.value = null
  try {
    const result = await loadOrders(next, controller.signal, event => trace.push(event))
    // Mapping: only the latest non-aborted result may enter current component state.
    if (run !== latestRun || controller.signal.aborted) return
    orders.value = result
    trace.push(`commit:${run}:${next}`)
  } catch (cause) {
    if (cause instanceof DOMException && cause.name === 'AbortError') {
      trace.push(`abort:${run}:${next}`)
      return
    }
    if (run === latestRun) error.value = '加载失败，请重试'
  } finally {
    if (run === latestRun) loading.value = false
  }
}, { immediate: true })

watch(filter, (next) => {
  // Mapping: default flush intentionally records the owner DOM before its update.
  trace.push(`pre-dom:${next}:${filterLabel.value?.textContent ?? 'missing'}`)
})

watch(filter, (next) => {
  // Mapping: post flush records the owner DOM after Vue has patched the new filter.
  trace.push(`post-dom:${next}:${filterLabel.value?.textContent ?? 'missing'}`)
}, { flush: 'post' })

onMounted(() => {
  trace.push('mounted')
})

onUpdated(() => {
  // Side effect observation: trace is deliberately non-reactive to avoid update recursion.
  trace.push('updated')
})

onUnmounted(() => {
  trace.push('unmounted')
})

// Responsibility: expose read-only evidence for tests without granting mutation access.
defineExpose({
  getTrace: () => [...trace],
  getOrders: () => orders.value.map(order => ({ ...order })),
})
</script>

<template>
  <section aria-labelledby="effect-title">
    <h2 id="effect-title">按状态加载工单</h2>
    <label for="effect-filter">状态筛选</label>
    <select id="effect-filter" v-model="filter">
      <option value="ALL">全部</option>
      <option value="CREATED">已创建</option>
      <option value="COMPLETED">已完成</option>
    </select>

    <p ref="filterLabel" data-testid="filter-label">筛选：{{ filter }}</p>
    <p data-testid="status" role="status" aria-live="polite">{{ statusText }}</p>
    <ul>
      <li v-for="order in orders" :key="order.id">{{ order.id }} {{ order.title }}</li>
    </ul>
  </section>
</template>
