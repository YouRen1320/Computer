<script setup lang="ts">
import { ref, watch } from 'vue'
const props = defineProps<{ open: boolean }>()
const field = ref<HTMLInputElement | null>(null)

// Injected fault: focus runs before the conditional subtree has committed.
watch(() => props.open, (open) => { if (open) field.value?.focus() })
</script>
<template><input v-if="open" ref="field"></template>
