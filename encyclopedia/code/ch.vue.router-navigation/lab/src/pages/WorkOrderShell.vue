<script setup lang="ts">
import { RouterLink, RouterView } from 'vue-router'

// Responsibility: own the work-order section layout and its child route outlet.
</script>

<template><section><p data-testid="layout">工单中心布局</p><RouterLink :to="{ name: 'orders' }">工单列表</RouterLink><RouterView/></section></template>

