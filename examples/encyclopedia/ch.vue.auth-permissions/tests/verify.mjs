// Responsibility: verify bootstrap, return path, route/UI, 401/403, and direct server-deny matrices.
// Data source: deterministic session fixtures plus server-owned subject and work-order records.
// Mapping: each auth scenario maps to exact state, navigation, presentation, and API status assertions.
// Side effects: executes in-memory policy functions only and prints one PASS line.

import assert from 'node:assert/strict'
import {
  createAuthClient,
  createPolicyServer,
  handleApiStatus,
  permissionPresentation,
  routeDecision,
  safeReturnPath,
} from '../src/auth-contract.mjs'

let settleBootstrap
const pendingSession = new Promise((resolve) => { settleBootstrap = resolve })
const pendingAuth = createAuthClient(() => pendingSession)
const pendingRun = pendingAuth.bootstrap()
assert.equal(pendingAuth.state().tag, 'bootstrapping')
assert.equal(pendingAuth.sensitiveVisible(), false)
settleBootstrap({ status: 200, subject: { id: 'admin', tenantId: 'T1' }, capabilities: ['work-order.delete'] })
await pendingRun
assert.equal(pendingAuth.state().tag, 'authenticated')

const anonymous = createAuthClient(async () => ({ status: 401 }))
const anonymousRoute = await routeDecision(anonymous, { fullPath: '/work-orders/WO-1', public: false })
assert.deepEqual(anonymousRoute, { kind: 'sign-in', path: '/sign-in', returnTo: '/work-orders/WO-1' })
assert.equal(anonymous.state().tag, 'anonymous')

assert.equal(safeReturnPath('/work-orders/WO-1?tab=history'), '/work-orders/WO-1?tab=history')
for (const malicious of ['https://evil.example/x', '//evil.example/x', '\\evil.example', '/sign-in', 'javascript:alert(1)', null]) {
  assert.equal(safeReturnPath(malicious), '/work-orders')
}

const operator = createAuthClient(async () => ({
  status: 200,
  subject: { id: 'operator', tenantId: 'T1' },
  capabilities: ['work-order.read'],
}))
const forbiddenRoute = await routeDecision(operator, {
  fullPath: '/work-orders/WO-1/delete',
  public: false,
  capability: 'work-order.delete',
})
assert.equal(forbiddenRoute.kind, 'forbidden')
assert.deepEqual(permissionPresentation(operator, 'work-order.delete'), { visible: false, reason: 'missing-capability' })

const server = createPolicyServer({
  subjects: {
    viewer: { tenantId: 'T1', capabilities: ['work-order.read'] },
    admin: { tenantId: 'T1', capabilities: ['work-order.delete'] },
  },
  orders: {
    'WO-1': { tenantId: 'T1', status: 'CREATED' },
    'WO-2': { tenantId: 'T2', status: 'CREATED' },
    'WO-3': { tenantId: 'T1', status: 'RESOLVED' },
  },
})
assert.equal(server.deleteWorkOrder({ subjectId: null, workOrderId: 'WO-1' }).status, 401)
assert.equal(server.deleteWorkOrder({ subjectId: 'viewer', workOrderId: 'WO-1' }).status, 403)
assert.equal(server.deleteWorkOrder({ subjectId: 'admin', workOrderId: 'WO-2' }).status, 403)
assert.equal(server.deleteWorkOrder({ subjectId: 'admin', workOrderId: 'WO-3' }).status, 403)
assert.equal(server.deleteWorkOrder({ subjectId: 'admin', workOrderId: 'WO-1' }).status, 204)

const auth401 = createAuthClient(async () => ({
  status: 200,
  subject: { id: 'admin', tenantId: 'T1' },
  capabilities: ['work-order.delete'],
}))
await auth401.bootstrap()
const expired = handleApiStatus(auth401, 401, '/work-orders/WO-1')
assert.equal(auth401.state().tag, 'anonymous')
assert.deepEqual(expired, { kind: 'sign-in', returnTo: '/work-orders/WO-1' })

const auth403 = createAuthClient(async () => ({
  status: 200,
  subject: { id: 'viewer', tenantId: 'T1' },
  capabilities: ['work-order.read'],
}))
await auth403.bootstrap()
assert.equal(handleApiStatus(auth403, 403, '/work-orders/WO-1').kind, 'forbidden')
assert.equal(auth403.state().tag, 'authenticated')

console.log('VUE_AUTH_PERMISSIONS_EXAMPLE_PASS scenarios=8 direct-api-deny=yes real-rbac=unverified')
