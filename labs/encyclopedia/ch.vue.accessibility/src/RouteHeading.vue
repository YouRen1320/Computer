<script setup lang="ts">
import { nextTick, ref, watch } from 'vue'
const props = defineProps<{ routeKey: string; text: string }>()
const heading = ref<HTMLHeadingElement | null>(null)

// Responsibility: provide a reliable context target after a route-controlled conditional render.
watch(() => props.routeKey, async () => { await nextTick(); heading.value?.focus() })
</script>

<template><h1 :key="routeKey" ref="heading" tabindex="-1">{{ text }}</h1></template>
