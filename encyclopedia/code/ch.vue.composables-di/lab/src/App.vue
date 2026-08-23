<script setup lang="ts">
import QueryPanel from './QueryPanel.vue'
import { fixtureOrders } from './contracts'
import { createImmediateRepository } from './controlled-repository'
import { provideRepository } from './injection'

// Responsibility: choose the production-facing dependency once at the composition root.
provideRepository(createImmediateRepository(fixtureOrders))
</script>

<template><main><h1>Composable DI 实验</h1><QueryPanel panel-id="A"/><QueryPanel panel-id="B"/></main></template>

