// Responsibility: verify the privacy-audit model from local declarations; assertion failure is the only side effect.
import assert from 'node:assert/strict'
import { auditPrivacy, containsSentinel, safeEvent } from './privacy-audit.mjs'
const input = {
  codeCapabilities: ['scan', 'choose-media', 'location'],
  declarations: ['scan', 'choose-media', 'location'],
  inventory: [
    { capability: 'scan', purpose: 'fill-device-code', source: 'user-action', retention: 'normalized-only', deletion: 'with-draft', owner: 'reporter-team' },
    { capability: 'choose-media', purpose: 'repair-evidence', source: 'user-action', retention: 'policy-fixture', deletion: 'attachment-flow', owner: 'reporter-team' },
    { capability: 'location', purpose: 'optional-arrival-help', source: 'user-action', retention: 'short-fixture', deletion: 'location-flow', owner: 'reporter-team' }
  ],
  denialCases: [
    { capability: 'scan', optional: true, coreFlowAvailable: true },
    { capability: 'choose-media', optional: true, coreFlowAvailable: true },
    { capability: 'location', optional: true, coreFlowAvailable: true }
  ]
}
assert.deepEqual(auditPrivacy(input), { valid: true, problems: [] })
assert.equal(auditPrivacy({ ...input, declarations: ['scan'] }).valid, false)
assert.equal(auditPrivacy({ ...input, denialCases: [{ capability: 'location', optional: true, coreFlowAvailable: false }] }).problems[0], 'DENIAL_BLOCKS_CORE:location')

const sentinel = '31.123456,118.654321'
const event = safeEvent({ event: 'LOCATION_FAILED', target: 'mp-weixin', errorCode: 'DENIED', coordinates: sentinel, body: sentinel })
assert.equal(containsSentinel(event, [sentinel]), false)
assert.equal(Object.hasOwn(event, 'coordinates'), false)
console.log('UNIAPP_PRIVACY_REVIEW_EXAMPLE_PASS checks=5 evidence=offline-declaration-log-audit')
