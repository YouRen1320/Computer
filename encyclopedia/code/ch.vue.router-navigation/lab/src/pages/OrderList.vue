<script setup lang="ts">
import { RouterLink } from 'vue-router'
import type { StatusFilter } from '../contracts'

// Data source: route-record props provide the normalized URL filter.
defineProps<{ status: StatusFilter }>()
</script>

<template><article><h1>工单列表</h1><p data-testid="filter">{{ status }}</p><RouterLink :to="{ name: 'order-detail', params: { workOrderId: 'WO-4001' } }">查看 WO-4001</RouterLink></article></template>

