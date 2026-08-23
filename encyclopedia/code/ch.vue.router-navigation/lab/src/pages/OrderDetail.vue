<script setup lang="ts">
import { ref, watch } from 'vue'

const props = defineProps<{ workOrderId: string }>()
const loadedId = ref('')
const loadCount = ref(0)

// Important side effect: reload when Router reuses this component for a changed param.
watch(() => props.workOrderId, (next) => {
  loadedId.value = next
  loadCount.value += 1
}, { immediate: true })
</script>

<template><article><h1>工单 {{ loadedId }}</h1><p data-testid="loaded-id">{{ loadedId }}</p><p data-testid="load-count">{{ loadCount }}</p><p data-testid="auth-boundary">服务端必须再次授权</p></article></template>

