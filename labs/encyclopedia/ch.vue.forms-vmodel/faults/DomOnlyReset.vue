<script setup lang="ts">
import { ref } from 'vue'

// Data source: description remains Vue-owned even when the fault mutates only the DOM.
const description = ref('')
const inputElement = ref<HTMLInputElement | null>(null)

function resetDomOnly() {
  // Injected side effect: direct DOM reset bypasses v-model and creates deterministic drift.
  if (inputElement.value) inputElement.value.value = ''
}
</script>

<template>
  <form>
    <label for="fault-description">描述</label>
    <input id="fault-description" ref="inputElement" v-model="description" name="description">
    <button type="button" @click="resetDomOnly">故障重置</button>
    <output data-testid="fault-model">{{ description }}</output>
  </form>
</template>
