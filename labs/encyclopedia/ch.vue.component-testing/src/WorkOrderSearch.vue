<script setup lang="ts">
import { ref, shallowRef, watch } from 'vue'
import type { WorkOrderGateway, WorkOrderStatus, WorkOrderSummary } from './contracts'

const props = defineProps<{ gateway: WorkOrderGateway }>()
const emit = defineEmits<{ select: [payload: { workOrderId: string }] }>()

// Responsibility: expose query outcomes as a stable public DOM/event contract.
const status = ref<WorkOrderStatus>('CREATED')
const orders = shallowRef<readonly WorkOrderSummary[]>([])
const error = shallowRef<Error | null>(null)
const loading = ref(false)
const retryToken = ref(0)
let generation = 0

watch([status, retryToken], async ([nextStatus], _old, onCleanup) => {
  const controller = new AbortController()
  const mine = ++generation
  loading.value = true
  error.value = null
  // Important side effect: cancel stale I/O and ignore a late response from an older filter.
  onCleanup(() => controller.abort())
  try {
    const result = await props.gateway.list(nextStatus, controller.signal)
    if (mine === generation) orders.value = result
  } catch (cause) {
    const aborted = cause instanceof DOMException && cause.name === 'AbortError'
    if (!aborted && mine === generation) error.value = cause instanceof Error ? cause : new Error(String(cause))
  } finally {
    if (mine === generation) loading.value = false
  }
}, { immediate: true })

function retry() { retryToken.value += 1 }
function open(id: string) { emit('select', { workOrderId: id }) }
</script>

<template>
  <section aria-labelledby="search-heading">
    <h1 id="search-heading">工单查询实验</h1>
    <label for="status">状态</label>
    <select id="status" v-model="status">
      <option value="CREATED">待处理</option>
      <option value="IN_PROGRESS">处理中</option>
      <option value="RESOLVED">已完成</option>
    </select>
    <p v-if="loading" role="status">正在查询</p>
    <div v-else-if="error" role="alert"><p>{{ error.message }}</p><button type="button" @click="retry">重试</button></div>
    <p v-else-if="orders.length === 0" data-testid="empty-state">没有匹配工单</p>
    <ul v-else aria-label="工单结果">
      <li v-for="order in orders" :key="order.id">
        {{ order.id }} · {{ order.title }}
        <button type="button" @click="open(order.id)">打开工单 {{ order.id }}</button>
      </li>
    </ul>
  </section>
</template>
