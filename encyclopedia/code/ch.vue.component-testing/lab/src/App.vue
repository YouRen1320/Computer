<script setup lang="ts">
import { ref } from 'vue'
import WorkOrderSearch from './WorkOrderSearch.vue'
import type { WorkOrderGateway } from './contracts'

const staffId = ref('')
const authenticated = ref(false)
const selectedOrderId = ref<string | null>(null)

// Data source: the browser path stubs these HTTP boundaries; component tests inject a gateway directly.
const gateway: WorkOrderGateway = {
  async list(status, signal) {
    const response = await fetch(`/api/work-orders?status=${encodeURIComponent(status)}`, { signal })
    if (!response.ok) throw new Error(`查询失败：${response.status}`)
    return response.json()
  },
}

async function login() {
  // Important side effect: cross the session boundary before exposing authenticated work-order UI.
  const response = await fetch('/api/session', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ staffId: staffId.value }),
  })
  if (!response.ok) throw new Error('登录失败')
  authenticated.value = true
}
</script>

<template>
  <main>
    <form v-if="!authenticated" aria-labelledby="login-heading" @submit.prevent="login">
      <h1 id="login-heading">FactoryCare 登录</h1>
      <label for="staff-id">工号</label>
      <input id="staff-id" v-model="staffId" autocomplete="username">
      <button type="submit">登录</button>
    </form>
    <template v-else>
      <WorkOrderSearch :gateway="gateway" @select="selectedOrderId = $event.workOrderId" />
      <h2 v-if="selectedOrderId">工单详情 {{ selectedOrderId }}</h2>
    </template>
  </main>
</template>
