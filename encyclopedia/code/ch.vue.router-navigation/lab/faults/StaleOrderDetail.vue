<script setup lang="ts">
const props = defineProps<{ workOrderId: string }>()

// Injected fault: captures the first param-derived prop and never reacts when the instance is reused.
const firstLoadedId = props.workOrderId
</script>

<template><p data-testid="faulty-loaded-id">{{ firstLoadedId }}</p></template>

