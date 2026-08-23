<script setup lang="ts">
import type { StatusFilter } from './work-order'

// Data source: this compiler-backed ref is the parent's required controlled filter value.
const filter = defineModel<StatusFilter>({ required: true })
</script>

<template>
  <label for="contract-filter">状态筛选</label>
  <select id="contract-filter" v-model="filter" data-testid="filter-editor">
    <option value="ALL">全部</option>
    <option value="CREATED">已创建</option>
    <option value="IN_PROGRESS">处理中</option>
    <option value="RESOLVED">已完成</option>
  </select>
</template>

