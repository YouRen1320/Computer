<script setup lang="ts">
import WorkOrderQueryPanel from './WorkOrderQueryPanel.vue'
import { demoOrders } from './contracts'
import { provideWorkOrderRepository } from './injection'
import { createImmediateRepository } from './repository'

// Responsibility: the composition root chooses the repository implementation for this subtree.
provideWorkOrderRepository(createImmediateRepository(demoOrders))
</script>

<template>
  <main>
    <h1>FactoryCare 工单查询</h1>
    <div class="panels">
      <WorkOrderQueryPanel panel-id="left" initial-status="CREATED" />
      <WorkOrderQueryPanel panel-id="right" initial-status="IN_PROGRESS" />
    </div>
  </main>
</template>

<style scoped>
main { max-width: 72rem; margin: 0 auto; padding: 2rem; font-family: system-ui, sans-serif; color: #172033; }
.panels { display: grid; grid-template-columns: repeat(auto-fit, minmax(18rem, 1fr)); gap: 1rem; }
section { border: 1px solid #c7d2e3; border-radius: .5rem; padding: 1rem; }
button, select { min-height: 2.75rem; margin: .5rem; }
button:focus-visible, select:focus-visible { outline: 3px solid #1d4ed8; outline-offset: 2px; }
button:disabled { cursor: not-allowed; opacity: .55; }
</style>
