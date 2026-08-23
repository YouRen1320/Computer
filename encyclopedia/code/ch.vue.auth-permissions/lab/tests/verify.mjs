// Responsibility: rerun the repaired auth/permission matrix against the three recorded security faults.
// Data source: fault-records.json, controlled bootstrap Promise, malicious paths, and server-owned fixtures.
// Mapping: each fault id maps to a specific negative assertion and the same fixed policy oracle.
// Side effects: reads one local JSON file; no browser, token, API, or database is contacted.

import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { createPolicyServer, createSession, guard, handleStatus, safeReturnPath } from '../src/auth-policy.mjs'

const records = JSON.parse(await readFile(new URL('../fault-records.json', import.meta.url), 'utf8'))
assert.deepEqual(records.faults.map((fault) => fault.id), ['open-redirect', 'client-side-authorization-only', 'sensitive-ui-flash'])
assert.ok(records.faults.every((fault) => fault.first_evidence.length > 20 && fault.fix.length > 20))
assert.equal(records.same_oracle_rerun, true)
for (const key of ['real_browser_recorded', 'real_cookie_or_token_recorded', 'real_backend_rbac_recorded', 'real_security_test_recorded']) {
  assert.equal(records[key], false)
}

let resolveBootstrap
const bootstrap = new Promise((resolve) => { resolveBootstrap = resolve })
const pending = createSession(() => bootstrap)
const pendingRun = pending.bootstrap()
assert.equal(pending.state().tag, 'bootstrapping')
assert.equal(pending.sensitiveVisible(), false)
resolveBootstrap({ status: 200, subject: { id: 'admin', tenantId: 'T1' }, capabilities: ['work-order.delete'] })
await pendingRun
assert.equal(pending.sensitiveVisible(), true)

for (const bad of ['https://evil.example', '//evil.example', '\\evil.example', '/sign-in', 'javascript:alert(1)']) {
  assert.equal(safeReturnPath(bad), '/work-orders')
}
assert.equal(safeReturnPath('/work-orders/WO-1?tab=history'), '/work-orders/WO-1?tab=history')

const anonymous = createSession(async () => ({ status: 401 }))
assert.equal((await guard(anonymous, { fullPath: '/work-orders/WO-1' })).kind, 'sign-in')

const viewer = createSession(async () => ({
  status: 200,
  subject: { id: 'viewer', tenantId: 'T1' },
  capabilities: ['work-order.read'],
}))
assert.equal((await guard(viewer, { fullPath: '/work-orders/WO-1/delete', capability: 'work-order.delete' })).kind, 'forbidden')

const server = createPolicyServer(
  {
    viewer: { tenantId: 'T1', capabilities: ['work-order.read'] },
    admin: { tenantId: 'T1', capabilities: ['work-order.delete'] },
  },
  {
    'WO-1': { tenantId: 'T1' },
    'WO-2': { tenantId: 'T2' },
  },
)
assert.equal(server.deleteOrder(null, 'WO-1'), 401)
assert.equal(server.deleteOrder('viewer', 'WO-1'), 403)
assert.equal(server.deleteOrder('admin', 'WO-2'), 403)
assert.equal(server.deleteOrder('admin', 'WO-1'), 204)

const active = createSession(async () => ({
  status: 200,
  subject: { id: 'viewer', tenantId: 'T1' },
  capabilities: ['work-order.read'],
}))
await active.bootstrap()
assert.equal(handleStatus(active, 403, '/work-orders').kind, 'forbidden')
assert.equal(active.state().tag, 'authenticated')
assert.equal(handleStatus(active, 401, '/work-orders').kind, 'sign-in')
assert.equal(active.state().tag, 'anonymous')

console.log('VUE_AUTH_PERMISSIONS_LAB_PASS faults=3 matrix=complete real-rbac=unverified')
