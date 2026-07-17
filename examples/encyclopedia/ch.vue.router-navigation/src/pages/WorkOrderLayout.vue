<script setup lang="ts">
import { RouterLink, RouterView } from 'vue-router'

// Responsibility: keep work-order section navigation and the nested page outlet together.
</script>

<template>
  <section aria-labelledby="work-orders-section-title">
    <header>
      <p id="work-orders-section-title">工单中心</p>
      <RouterLink :to="{ name: 'work-order-list' }">返回工单列表</RouterLink>
    </header>
    <RouterView />
  </section>
</template>

