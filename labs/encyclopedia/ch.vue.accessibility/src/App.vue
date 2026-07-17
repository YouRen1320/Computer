<script setup lang="ts">
import { ref } from 'vue'
import RouteHeading from './RouteHeading.vue'
import WorkOrderDialog from './WorkOrderDialog.vue'

const open = ref(false)
const routeKey = ref('queue')
// Data source: the lab demo deliberately uses a deterministic local save boundary.
async function save() { await Promise.resolve() }
function changeRoute() { routeKey.value = routeKey.value === 'queue' ? 'history' : 'queue' }
</script>

<template><main><RouteHeading :route-key="routeKey" :text="routeKey === 'queue' ? '工单队列' : '工单历史'" /><button type="button" @click="changeRoute">切换页面</button><button type="button" @click="open = true">登记工单</button><WorkOrderDialog :open="open" :save="save" @close="open = false" /></main></template>
