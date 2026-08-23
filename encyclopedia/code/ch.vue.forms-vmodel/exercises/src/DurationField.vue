<script setup lang="ts">
import { ref } from 'vue'

// Data source: this UI-only field must become number | '' and never enter the report payload.
const symptomDurationMinutes = ref<number | string>('')
</script>

<template>
  <label for="duration">症状持续分钟（仅本地观察）</label>
  <!-- Injected mapping fault: the starter leaves number-like DOM input as a string. -->
  <input id="duration" v-model="symptomDurationMinutes" type="number" min="0">
  <output>{{ symptomDurationMinutes }}</output>
</template>

