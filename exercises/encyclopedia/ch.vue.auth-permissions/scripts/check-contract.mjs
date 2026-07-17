// Responsibility: detect open redirect, sensitive bootstrap flash, client-only authorization, and 403 logout.
// Data source: the candidate auth module plus deterministic session and server-policy fixtures.
// Mapping: four adversarial inputs map to four stable error messages or one green result.
// Side effects: runs only local Promises/policy calls and prints deterministic output.

import { createAuthClient, createPolicyServer, handleStatus, safeReturnPath } from '../src/auth-policy.mjs'

const errors = []
if (safeReturnPath('https://evil.example/phish') !== '/work-orders') {
  errors.push('untrusted external return URL was accepted')
}

let resolveBootstrap
const pending = new Promise((resolve) => { resolveBootstrap = resolve })
const auth = createAuthClient(() => pending)
if (auth.sensitiveVisible()) errors.push('sensitive UI is visible before bootstrap resolves')
const bootstrapRun = auth.bootstrap()
resolveBootstrap({ status: 200, subject: { id: 'viewer', tenantId: 'T1' }, capabilities: ['work-order.read'] })
await bootstrapRun

const server = createPolicyServer({
  subjects: { viewer: { tenantId: 'T1', capabilities: ['work-order.read'] } },
  orders: { 'WO-1': { tenantId: 'T1' } },
})
const bypassStatus = server.deleteOrder({ subjectId: 'viewer', orderId: 'WO-1', clientAllowed: true })
if (bypassStatus !== 403) errors.push('direct API trusted a forged client authorization flag')

handleStatus(auth, 403, '/work-orders/WO-1')
if (auth.state().tag !== 'authenticated') errors.push('403 incorrectly expired an authenticated session')

if (errors.length > 0) {
  for (const error of errors) console.log(`ERROR: ${error}`)
  console.log(`VUE_AUTH_PERMISSIONS_EXERCISE=FAIL (${errors.length} violations)`)
  process.exit(1)
}

console.log('VUE_AUTH_PERMISSIONS_EXERCISE=PASS redirect=internal bootstrap=sealed server=authoritative status=classified')
