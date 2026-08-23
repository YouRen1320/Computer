import assert from 'node:assert/strict'
import { buildCreateCommand, presentStatus, replay, resolveDeviceResponse } from './reporter-flow.mjs'

// 数据来源：项目合同的最小 fixture；断言不会调用真实 FactoryCare 或平台 API。
assert.deepEqual(resolveDeviceResponse({ assetId: 'asset-1', displayName: '一号泵' }), { assetId: 'asset-1', displayName: '一号泵' })
assert.throws(() => resolveDeviceResponse({ assetId: 'asset-1', displayName: '一号泵', tenantId: 'secret' }), /FIELD_DRIFT/)
const command = buildCreateCommand({
  operationId: 'op-1', idempotencyKey: 'idem-1',
  form: { draftId: 'draft-1', assetId: 'asset-1', category: 'LEAK', description: '泵体底部持续渗漏并伴随异响', priority: 'HIGH' },
  attachments: [{ attachmentId: 'att-1', draftId: 'draft-1', state: 'ready' }],
  release: { buildId: '20260717.3', contractDigest: 'sha256:contract' }
})
assert.equal(command.payload.attachmentIds[0], 'att-1')
assert.deepEqual(replay(command, { idempotencyKey: 'idem-1', reportId: 'report-1', workOrderId: 'wo-1' }), { state: 'confirmed', reportId: 'report-1', workOrderId: 'wo-1' })
assert.deepEqual(presentStatus('RESOLVED'), { group: 'AWAITING_VERIFICATION', action: 'VERIFY_OR_REJECT' })
assert.deepEqual(presentStatus('NEW_SERVER_STATE'), { group: 'UNKNOWN', action: 'REFRESH_OR_UPGRADE' })
console.log('UNIAPP_FACTORYCARE_REPORTER_EXAMPLE_PASS checks=6 evidence=offline-integration-contract')
