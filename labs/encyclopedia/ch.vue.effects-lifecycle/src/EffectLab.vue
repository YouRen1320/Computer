<script setup lang="ts">
import { computed, onMounted, onUnmounted, onUpdated, ref, watch } from 'vue'
import { createResourceLoader, type Filter, type Order } from './resource-loader'

// Data source: filter drives each external run; orders contain only the latest committed result.
const filter = ref<Filter>('ALL')
const orders = ref<Order[]>([])
const loading = ref(false)
const label = ref<HTMLElement | null>(null)
const trace: string[] = []
const loader = createResourceLoader()
let sequence = 0
let latest = 0

const feedback = computed(() => loading.value ? '正在加载工单' : `结果 ${orders.value.length} 张`)

watch(filter, async (next, _previous, onCleanup) => {
  const run = ++sequence
  latest = run
  const controller = new AbortController()
  trace.push(`start:${run}:${next}`)
  onCleanup(() => {
    // Side effect cleanup: release the resource before this run loses ownership.
    trace.push(`cleanup:${run}:${next}`)
    controller.abort()
  })

  loading.value = true
  try {
    const result = await loader.list(next, controller.signal, event => trace.push(event))
    // Mapping: result ownership must still match both the newest run and non-aborted signal.
    if (run !== latest || controller.signal.aborted) return
    orders.value = result
    trace.push(`commit:${run}:${next}`)
  } catch (cause) {
    if (cause instanceof DOMException && cause.name === 'AbortError') {
      trace.push(`abort:${run}:${next}`)
      return
    }
    trace.push(`error:${run}:${next}`)
  } finally {
    if (run === latest) loading.value = false
  }
}, { immediate: true })

watch(filter, (next) => {
  // Mapping: pre flush should observe the previous owner DOM label.
  trace.push(`pre:${next}:${label.value?.textContent ?? 'missing'}`)
})

watch(filter, (next) => {
  // Mapping: post flush should observe the patched owner DOM label.
  trace.push(`post:${next}:${label.value?.textContent ?? 'missing'}`)
}, { flush: 'post' })

onMounted(() => trace.push('mounted'))
onUpdated(() => {
  // Side effect observation: a plain array prevents lifecycle tracing from causing a render loop.
  trace.push('updated')
})
onUnmounted(() => trace.push('unmounted'))

// Responsibility: tests receive snapshots, not mutation access to component state.
defineExpose({
  getTrace: () => [...trace],
  getOrders: () => orders.value.map(order => ({ ...order })),
  activeResources: () => loader.active(),
})
</script>

<template>
  <section aria-labelledby="lab-title">
    <h2 id="lab-title">副作用所有权</h2>
    <label for="lab-filter">状态筛选</label>
    <select id="lab-filter" v-model="filter">
      <option value="ALL">全部</option>
      <option value="CREATED">已创建</option>
      <option value="RESOLVED">已完成</option>
    </select>
    <p ref="label" data-testid="label">筛选：{{ filter }}</p>
    <p data-testid="feedback" role="status" aria-live="polite">{{ feedback }}</p>
    <ul>
      <li v-for="order in orders" :key="order.id">{{ order.id }} {{ order.title }}</li>
    </ul>
  </section>
</template>
