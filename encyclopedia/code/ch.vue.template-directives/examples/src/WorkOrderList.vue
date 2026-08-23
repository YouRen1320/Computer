<script setup lang="ts">
import { ref } from 'vue'
import type { WorkOrderListItem, WorkOrderStatus } from './work-orders'

type StatusFilter = 'ALL' | WorkOrderStatus

// props 是可替换测试数据源；本章只观察模板，不展开组件通信合同。
const props = defineProps<{ orders: WorkOrderListItem[] }>()
const activeStatus = ref<StatusFilter>('ALL')
const selectedId = ref<string | null>(null)

const statusOptions: Array<{ value: StatusFilter; label: string }> = [
  { value: 'ALL', label: '全部' },
  { value: 'CREATED', label: '已创建' },
  { value: 'IN_PROGRESS', label: '处理中' },
  { value: 'CLOSED', label: '已关闭' },
]

// 标签映射以公共合同枚举为数据源，中文只属于呈现层。
const statusLabels: Record<WorkOrderStatus, string> = {
  CREATED: '已创建',
  IN_PROGRESS: '处理中',
  CLOSED: '已关闭',
}

function visibleOrders(): WorkOrderListItem[] {
  return activeStatus.value === 'ALL'
    ? props.orders
    : props.orders.filter((order) => order.status === activeStatus.value)
}

function chooseStatus(next: StatusFilter): void {
  // 筛选是用户动作；同步清除选择，避免详情仍指向不可见工单。
  activeStatus.value = next
  selectedId.value = null
}

function selectOrder(id: string): void {
  // 选择只更新本地呈现状态，不调用状态迁移 API。
  selectedId.value = id
}

function selectedNumber(): string {
  return props.orders.find((order) => order.id === selectedId.value)?.number ?? '无'
}
</script>

<template>
  <section class="work-orders" aria-labelledby="orders-title">
    <h1 id="orders-title">FactoryCare 工单</h1>

    <div class="filters" role="group" aria-label="工单状态筛选">
      <button
        v-for="option in statusOptions"
        :key="option.value"
        type="button"
        :data-filter="option.value"
        :aria-pressed="activeStatus === option.value"
        @click="chooseStatus(option.value)"
      >
        {{ option.label }}
      </button>
    </div>

    <p v-if="visibleOrders().length === 0" data-testid="empty">当前筛选没有工单。</p>
    <ul v-else aria-label="工单列表">
      <li
        v-for="order in visibleOrders()"
        :key="order.id"
        class="work-order"
        :class="{ 'work-order--critical': order.priority === 'CRITICAL' }"
        :data-order-id="order.id"
      >
        <strong>{{ order.number }}</strong>
        <span>状态：{{ statusLabels[order.status] }}</span>
        <span>优先级：{{ order.priority }}</span>
        <button
          type="button"
          :data-select-id="order.id"
          :aria-label="`选择工单 ${order.number}`"
          :aria-pressed="selectedId === order.id"
          @click="selectOrder(order.id)"
        >
          选择
        </button>
      </li>
    </ul>

    <p data-testid="selected" aria-live="polite" v-show="selectedId !== null">
      已选择：{{ selectedNumber() }}
    </p>
  </section>
</template>

<style scoped>
.work-orders { max-width: 56rem; margin-inline: auto; padding: 1.5rem; color: #172033; }
.filters { display: flex; flex-wrap: wrap; gap: 0.5rem; }
button { min-block-size: 44px; padding-inline: 1rem; border: 1px solid #536174; border-radius: 0.5rem; background: #fff; color: #172033; }
button[aria-pressed='true'] { border-color: #176b47; background: #dff4e9; font-weight: 700; }
button:focus-visible { outline: 3px solid #185c9d; outline-offset: 2px; }
.work-order { display: grid; gap: 0.5rem; margin-block: 0.75rem; padding: 1rem; border-inline-start: 0.25rem solid #6d7785; background: #f7f9fc; }
.work-order--critical { border-inline-start-color: #a12727; }
</style>
