<script setup lang="ts">
import { ref } from 'vue'

// Data source: the corrected local field explicitly permits a parsed number or an empty input.
const symptomDurationMinutes = ref<number | ''>('')
</script>

<template>
  <label for="duration">症状持续分钟（仅本地观察）</label>
  <!-- Mapping: convert parseable number input at the v-model boundary. -->
  <input id="duration" v-model.number="symptomDurationMinutes" type="number" min="0">
  <output>{{ symptomDurationMinutes }}</output>
</template>

