<script setup lang="ts">
import { ref } from 'vue'
import AccessibleWorkOrderDialog from './AccessibleWorkOrderDialog.vue'
import RouteFocusRegion from './RouteFocusRegion.vue'

const dialogOpen = ref(false)
const pageKey = ref('queue')
const heading = ref('待处理工单')

// Data source: this demo gateway models an asynchronous save; production replaces only this boundary.
const gateway = { async save() { await Promise.resolve() } }

function changeRoute() {
  const queue = pageKey.value === 'queue'
  pageKey.value = queue ? 'history' : 'queue'
  heading.value = queue ? '工单历史' : '待处理工单'
}
</script>

<template>
  <a class="skip-link" href="#main-content">跳到主要内容</a>
  <header><strong>FactoryCare</strong><button type="button" @click="changeRoute">切换页面</button></header>
  <main id="main-content">
    <RouteFocusRegion :page-key="pageKey" :heading="heading">
      <p>使用键盘打开弹层，验证焦点进入、环绕、退出与恢复。</p>
      <button type="button" @click="dialogOpen = true">新建工单</button>
    </RouteFocusRegion>
  </main>
  <AccessibleWorkOrderDialog :open="dialogOpen" :gateway="gateway" @close="dialogOpen = false" />
</template>

<style>
:root { font-family: Inter, ui-sans-serif, system-ui, sans-serif; color: #172033; background: #f7f9fc; }
* { box-sizing: border-box; }
body { margin: 0; }
header, main { max-width: 64rem; margin: 0 auto; padding: 1rem; }
header { display: flex; justify-content: space-between; align-items: center; }
button, input { min-height: 44px; font: inherit; }
button { padding: .65rem 1rem; border: 2px solid #174ea6; border-radius: .5rem; background: #174ea6; color: #fff; }
input { width: 100%; padding: .65rem; border: 2px solid #5c677d; border-radius: .4rem; }
:focus-visible { outline: 3px solid #ff8a00; outline-offset: 3px; }
.skip-link { position: absolute; left: .5rem; top: -5rem; padding: .75rem; background: #fff; color: #092e6e; z-index: 20; }
.skip-link:focus { top: .5rem; }
.backdrop { position: fixed; inset: 0; display: grid; place-items: center; padding: 1rem; background: rgb(11 20 35 / 72%); z-index: 10; }
.dialog { width: min(32rem, 100%); padding: 1.5rem; border-radius: .75rem; background: #fff; box-shadow: 0 1rem 3rem rgb(0 0 0 / 30%); }
.dialog label { display: block; margin-block: 1rem .35rem; font-weight: 700; }
.actions { display: flex; gap: .75rem; margin-top: 1rem; }
[role="alert"] { padding-left: .75rem; border-left: 4px solid #b42318; color: #8a1c13; font-weight: 700; }
.status { min-height: 1.5rem; }
@media (prefers-reduced-motion: reduce) { *, *::before, *::after { scroll-behavior: auto !important; transition-duration: .01ms !important; animation-duration: .01ms !important; } }
</style>
