<script setup lang="ts">
import { ref } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()
const loadedId = ref('')

// Data source: this starter incorrectly snapshots the first route param only once.
const firstId = String(route.params.workOrderId)

// Responsibility: load the detail corresponding to every current workOrderId param.
async function loadWorkOrder(workOrderId: string) {
  loadedId.value = workOrderId
}

void loadWorkOrder(firstId)
</script>

<template><main><h1>工单 {{ loadedId }}</h1></main></template>

