<script setup lang="ts">
import { nextTick, ref, watch } from 'vue'

const props = defineProps<{ pageKey: string; heading: string }>()
const headingElement = ref<HTMLHeadingElement | null>(null)

// Responsibility: restore route-change context at a programmatically focusable page heading.
watch(() => props.pageKey, async () => {
  await nextTick()
  // Important side effect: move focus only after the new conditional subtree has committed.
  headingElement.value?.focus()
})
</script>

<template>
  <section :key="pageKey" aria-labelledby="route-heading">
    <h1 id="route-heading" ref="headingElement" tabindex="-1">{{ heading }}</h1>
    <slot />
  </section>
</template>
