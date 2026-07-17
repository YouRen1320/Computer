<script setup lang="ts">
import { ref } from 'vue'
import type { WorkOrderListItem, WorkOrderStatus } from './work-orders'

type StatusFilter = 'ALL' | WorkOrderStatus
const props = defineProps<{ orders: WorkOrderListItem[] }>()
const activeStatus = ref<StatusFilter>('ALL')
const selectedId = ref<string | null>(null)
const detailId = ref<string | null>(null)

const filters: Array<{ value: StatusFilter; label: string }> = [
  { value: 'ALL', label: '全部' },
  { value: 'CREATED', label: '已创建' },
  { value: 'IN_PROGRESS', label: '处理中' },
  { value: 'CLOSED', label: '已关闭' },
]

// 显式映射来自 FactoryCare 状态合同，不把后端枚举直接当中文文案。
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

function chooseFilter(next: StatusFilter): void {
  // 筛选会改变可见集合，因此同步清除选择和详情，避免残留指向隐藏实体。
  activeStatus.value = next
  selectedId.value = null
  detailId.value = null
}

function selectOrder(id: string): void {
  // 卡片选择只更新本地 UI，不直接修改工单状态。
  selectedId.value = id
}

function openDetails(id: string): void {
  // 详情按钮的独立动作由 .stop 与卡片选择隔离。
  detailId.value = id
}

function numberFor(id: string | null): string {
  return props.orders.find((order) => order.id === id)?.number ?? '无'
}
</script>

<template>
  <section class="board" aria-labelledby="board-title">
    <h1 id="board-title">FactoryCare 调度工单</h1>

    <div class="filters" role="group" aria-label="工单状态筛选">
      <button
        v-for="filter in filters"
        :key="filter.value"
        type="button"
        :data-filter="filter.value"
        :aria-pressed="activeStatus === filter.value"
        @click="chooseFilter(filter.value)"
      >{{ filter.label }}</button>
    </div>

    <p v-if="visibleOrders().length === 0" data-testid="empty">
      当前筛选没有工单，请切换筛选。
    </p>
    <ul v-else aria-label="工单列表">
      <li
        v-for="order in visibleOrders()"
        :key="order.id"
        class="order-card"
        :class="{ 'order-card--critical': order.priority === 'CRITICAL' }"
        :data-order-id="order.id"
        @click="selectOrder(order.id)"
      >
        <strong>{{ order.number }}</strong>
        <span>状态：{{ statusLabels[order.status] }}</span>
        <span>优先级：{{ order.priority }}</span>
        <button
          type="button"
          :data-detail-id="order.id"
          :aria-label="`查看工单 ${order.number} 详情`"
          @click.stop="openDetails(order.id)"
        >查看详情</button>
      </li>
    </ul>

    <p data-testid="selected" aria-live="polite" v-show="selectedId !== null">
      已选择：{{ numberFor(selectedId) }}
    </p>
    <p data-testid="details" v-if="detailId !== null">
      详情目标：{{ numberFor(detailId) }}
    </p>
  </section>
</template>

<style scoped>
.board { max-width: 58rem; margin-inline: auto; padding: 1.5rem; color: #172033; }
.filters { display: flex; flex-wrap: wrap; gap: 0.5rem; margin-block-end: 1rem; }
button { min-block-size: 44px; padding-inline: 1rem; border: 1px solid #536174; border-radius: 0.5rem; background: #fff; color: #172033; }
button[aria-pressed='true'] { border-color: #176b47; background: #dff4e9; font-weight: 700; }
button:focus-visible { outline: 3px solid #185c9d; outline-offset: 2px; }
.order-card { display: grid; gap: 0.5rem; margin-block: 0.75rem; padding: 1rem; border-inline-start: 0.25rem solid #6d7785; background: #f7f9fc; }
.order-card--critical { border-inline-start-color: #a12727; }
</style>
