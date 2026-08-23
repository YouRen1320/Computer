<script setup lang="ts">
import { reactive, watch } from 'vue'

// Data source: query is reactive, but the injected fault passes its current string value to watch.
const query = reactive({ status: 'ALL' })
let runs = 0

watch(query.status as never, () => {
  // Injected side effect: this callback never receives later property changes.
  runs += 1
})

function selectCreated() {
  query.status = 'CREATED'
}

// Responsibility: expose the callback count without changing the faulty source expression.
defineExpose({ getRuns: () => runs })
</script>

<template>
  <button type="button" @click="selectCreated">切换到已创建</button>
  <p data-testid="wrong-source">{{ query.status }}</p>
</template>
