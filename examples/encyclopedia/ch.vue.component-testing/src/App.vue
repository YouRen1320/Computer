<script setup lang="ts">
import { computed, ref } from 'vue'
import { httpWorkOrderGateway, type WorkOrderSummary } from './contracts'
import WorkOrderDetail from './WorkOrderDetail.vue'
import WorkOrderSearch from './WorkOrderSearch.vue'

const authenticated = ref(false)
const email = ref('')
const password = ref('')
const loginBusy = ref(false)
const loginError = ref('')
const selectedOrderId = ref<string | null>(null)
const selectedOrder = computed<WorkOrderSummary | null>(() => selectedOrderId.value ? {
  id: selectedOrderId.value,
  title: '主轴振动复核',
  status: 'CREATED',
} : null)

// Important side effect: the E2E boundary stubs this session request, not Vue implementation details.
async function login() {
  loginBusy.value = true
  loginError.value = ''
  try {
    const response = await fetch('/api/session', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: email.value, password: password.value }),
    })
    if (!response.ok) throw new Error('登录失败，请检查凭据')
    authenticated.value = true
  } catch (cause) {
    loginError.value = cause instanceof Error ? cause.message : String(cause)
  } finally {
    loginBusy.value = false
  }
}
</script>

<template>
  <main>
    <h1>FactoryCare</h1>
    <form v-if="!authenticated" aria-labelledby="login-title" @submit.prevent="login">
      <h2 id="login-title">登录</h2>
      <label for="email">电子邮箱</label><input id="email" v-model="email" type="email" autocomplete="username">
      <label for="password">密码</label><input id="password" v-model="password" type="password" autocomplete="current-password">
      <button type="submit" :disabled="loginBusy">{{ loginBusy ? '登录中' : '登录' }}</button>
      <p v-if="loginError" role="alert">{{ loginError }}</p>
    </form>
    <template v-else>
      <WorkOrderSearch :gateway="httpWorkOrderGateway" @select="selectedOrderId = $event.workOrderId" />
      <WorkOrderDetail v-if="selectedOrder" :order="selectedOrder" />
    </template>
  </main>
</template>

<style>
:root { font-family: Inter, system-ui, sans-serif; color: #172033; background: #f8fafc; }
main { max-width: 64rem; margin: 0 auto; padding: 1.5rem; }
form, section, article { display: grid; gap: .75rem; padding: 1rem; border: 1px solid #94a3b8; border-radius: .5rem; }
button, input, select { min-height: 2.75rem; font: inherit; }
button:focus-visible, input:focus-visible, select:focus-visible { outline: 3px solid #1d4ed8; outline-offset: 2px; }
button:disabled { cursor: not-allowed; opacity: .55; }
</style>
