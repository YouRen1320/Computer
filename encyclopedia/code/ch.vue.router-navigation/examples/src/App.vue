<script setup lang="ts">
import { nextTick, ref, watch } from 'vue'
import { RouterLink, RouterView, useRoute } from 'vue-router'

const route = useRoute()
const main = ref<HTMLElement | null>(null)

// Important side effect: after a route change, move programmatic focus to the new page heading.
watch(() => route.fullPath, async () => {
  await nextTick()
  main.value?.querySelector<HTMLElement>('[data-page-title]')?.focus()
}, { immediate: true, flush: 'post' })
</script>

<template>
  <a class="skip-link" href="#main-content">跳到主要内容</a>
  <header>
    <strong>FactoryCare</strong>
    <nav aria-label="主要导航">
      <RouterLink :to="{ name: 'work-order-list', query: { status: 'CREATED' } }">工单</RouterLink>
    </nav>
  </header>
  <main id="main-content" ref="main"><RouterView /></main>
</template>

<style>
:root { font-family: Inter, system-ui, sans-serif; color: #172033; background: #f5f7fb; }
body { margin: 0; }
header { display: flex; align-items: center; justify-content: space-between; padding: 1rem; background: #fff; border-bottom: 1px solid #cbd5e1; }
a { color: #1d4ed8; min-height: 2.75rem; display: inline-flex; align-items: center; padding: 0 .5rem; }
a:focus-visible, [data-page-title]:focus-visible { outline: 3px solid #1d4ed8; outline-offset: 3px; }
.router-link-active { color: #172033; text-decoration-thickness: .2rem; }
.skip-link { position: absolute; transform: translateY(-150%); background: #fff; }
.skip-link:focus { transform: translateY(0); }
main { max-width: 64rem; margin: 0 auto; padding: 1.5rem; }
</style>

