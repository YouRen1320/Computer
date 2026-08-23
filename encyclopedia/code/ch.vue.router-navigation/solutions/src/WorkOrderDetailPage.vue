<script setup lang="ts">
import { ref, watch } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()
const loadedId = ref('')

// Responsibility: load the detail corresponding to the current route param.
async function loadWorkOrder(workOrderId: string) {
  loadedId.value = workOrderId
}

// Important side effect: Router can reuse this instance, so each param transition triggers a reload.
watch(() => route.params.workOrderId, (nextId) => {
  // Mapping: normalized route params may be string/array; this route contract expects one string.
  void loadWorkOrder(String(nextId))
}, { immediate: true })
</script>

<template><main><h1>工单 {{ loadedId }}</h1></main></template>

