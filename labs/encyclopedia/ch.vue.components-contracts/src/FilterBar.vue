<script setup lang="ts">
import type { Filter } from './contracts'

// Data source: the model ref is a controlled view of the parent-owned filter.
const filter = defineModel<Filter>({ required: true })
</script>

<template>
  <label for="lab-contract-filter">状态筛选</label>
  <select id="lab-contract-filter" v-model="filter" data-testid="filter">
    <option value="ALL">全部</option>
    <option value="CREATED">已创建</option>
    <option value="IN_PROGRESS">处理中</option>
    <option value="RESOLVED">已完成</option>
  </select>
</template>

