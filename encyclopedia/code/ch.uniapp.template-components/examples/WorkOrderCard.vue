<script setup lang="ts">
import { computed } from 'vue'

type CardValue = {
  id: string
  title: string
  status: 'ASSIGNED' | 'IN_PROGRESS' | 'CLOSED'
}

const props = defineProps<{ value: CardValue; selected: boolean }>()
const emit = defineEmits<{
  open: [id: string]
  'update:selected': [selected: boolean]
}>()

// 非显然映射：服务端状态码在一个位置转换为用户文本。
const statusLabel = computed(() => ({
  ASSIGNED: '待处理',
  IN_PROGRESS: '处理中',
  CLOSED: '已关闭'
}[props.value.status]))

function toggleSelection() {
  // 组件副作用：只发新值，不直接修改父状态或请求后端。
  emit('update:selected', !props.selected)
}
</script>

<template>
  <view class="work-order-card">
    <text class="work-order-card__title">{{ value.id }} · {{ value.title }}</text>
    <text class="work-order-card__status">{{ statusLabel }}</text>
    <button type="default" @click="emit('open', value.id)">查看详情</button>
    <button type="default" @click="toggleSelection">切换选择</button>
  </view>
</template>

<style scoped>
.work-order-card {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
  padding: 24rpx;
  border: 1rpx solid #d7dce2;
}
</style>
