<script setup lang="ts">
import { RouterLink, RouterView } from 'vue-router'

// Responsibility: expose semantic primary navigation and the top-level route outlet.
</script>

<template><header><nav aria-label="主要导航"><RouterLink :to="{ name: 'orders' }">工单</RouterLink></nav></header><main><RouterView/></main></template>

