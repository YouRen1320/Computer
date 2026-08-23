import assert from 'node:assert/strict'
import { auditRelease, createSafeEvent } from './release-audit.mjs'

// 数据来源：固定候选、灰度和事件 fixture；副作用仅为断言与终端证据，不连接平台。
const candidate = {
  productVersion: '2.4.0', buildId: '20260717.3', commit: '0123456789abcdef', target: 'mp-weixin',
  environment: 'production', apiOrigin: 'https://api.factorycare.example', configDigest: 'sha256:config',
  contractDigest: 'sha256:contract', artifactDigest: 'sha256:artifact'
}
const grayPlan = {
  buildId: candidate.buildId, scope: 'internal-reporters', baseline: 'previous-7-day-window',
  successCondition: 'submit-success-within-budget', stopCondition: 'two-window-failure-guardrail',
  rollbackCondition: 'any-privacy-or-cross-tenant-event', decisionOwner: 'release-owner', rollbackBuildId: '20260710.2'
}
const event = createSafeEvent({
  eventName: 'report_submit_failed', severity: 'error', buildId: candidate.buildId,
  routeTemplate: '/pages/report/create', operation: 'create_report', errorCode: 'NETWORK_TIMEOUT',
  requestId: 'req-opaque-1', occurredAt: '2026-07-17T10:02:03Z', token: 'must-not-pass-through'
})

assert.deepEqual(auditRelease({ candidate, grayPlan, events: [event] }), { valid: true, problems: [] })
assert.equal(Object.hasOwn(event, 'token'), false)
assert.equal(auditRelease({ candidate: { ...candidate, apiOrigin: 'http://localhost:8080' }, grayPlan, events: [event] }).problems[0], 'PRODUCTION_LOCALHOST')
assert.equal(auditRelease({ candidate, grayPlan: { ...grayPlan, stopCondition: '' }, events: [event] }).valid, false)
console.log('UNIAPP_RELEASE_MONITORING_EXAMPLE_PASS checks=4 evidence=offline-release-contract')
