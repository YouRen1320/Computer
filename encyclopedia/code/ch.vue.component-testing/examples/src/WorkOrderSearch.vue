<script setup lang="ts">
import { onScopeDispose, readonly, ref, shallowRef, watch } from 'vue'
import type { WorkOrderGateway, WorkOrderStatus, WorkOrderSummary } from './contracts'
import WorkOrderFilter from './WorkOrderFilter.vue'

const props = defineProps<{ gateway: WorkOrderGateway }>()
const emit = defineEmits<{ select: [payload: { workOrderId: string }] }>()

// Responsibility: render the public loading/error/empty/list states for one cancellable query.
const status = ref<WorkOrderStatus>('CREATED')
const orders = shallowRef<readonly WorkOrderSummary[]>([])
const loading = ref(false)
const error = shallowRef<Error | null>(null)
const retryToken = ref(0)
let generation = 0

const stop = watch([status, retryToken], async ([nextStatus], _previous, onCleanup) => {
  const controller = new AbortController()
  const mine = ++generation
  loading.value = true
  error.value = null
  // Important side effect: invalidate the network call when filter, retry, or owner scope changes.
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

onScopeDispose(stop)

function retry() { retryToken.value += 1 }
function selectOrder(workOrderId: string) { emit('select', { workOrderId }) }

// Data source: expose readonly bindings only for optional parent instrumentation; tests use the DOM contract.
defineExpose({ status: readonly(status), loading: readonly(loading) })
</script>

<template>
  <section aria-labelledby="search-title">
    <h2 id="search-title">工单查询</h2>
    <WorkOrderFilter v-model="status" />
    <p v-if="loading" role="status">正在查询工单</p>
    <div v-else-if="error" role="alert">
      <p>{{ error.message }}</p>
      <button type="button" @click="retry">重试查询</button>
    </div>
    <p v-else-if="orders.length === 0" data-testid="empty-state">没有符合条件的工单</p>
    <ul v-else aria-label="工单结果">
      <li v-for="order in orders" :key="order.id">
        <span>{{ order.id }} · {{ order.title }}</span>
        <button type="button" @click="selectOrder(order.id)">打开工单 {{ order.id }}</button>
      </li>
    </ul>
  </section>
</template>
