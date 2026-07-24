// 职责：在不模拟真实网络的前提下，表达报修端跨边界输入与副作用准入条件。
const statuses = new Set(['CREATED', 'TRIAGED', 'ASSIGNED', 'ACCEPTED', 'IN_PROGRESS', 'PENDING_PARTS', 'PENDING_APPROVAL', 'RESOLVED', 'VERIFIED', 'CLOSED', 'REOPENED', 'CANCELLED'])

export function resolveDeviceResponse(response) {
  const keys = Object.keys(response).sort()
  if (keys.join(',') !== 'assetId,displayName') throw new Error('ANONYMOUS_ASSET_FIELD_DRIFT')
  return { assetId: response.assetId, displayName: response.displayName }
}

export function buildCreateCommand({ operationId, idempotencyKey, form, attachments, release }) {
  if (!operationId || !idempotencyKey) throw new Error('MISSING_OPERATION_IDENTITY')
  if (!release.buildId || !release.contractDigest) throw new Error('MISSING_RELEASE_EVIDENCE')
  if (form.description.length < 10) throw new Error('DESCRIPTION_TOO_SHORT')
  if (attachments.some((item) => item.state !== 'ready' || item.draftId !== form.draftId)) throw new Error('ATTACHMENT_NOT_BINDABLE')
  return {
    operationId,
    idempotencyKey,
    buildId: release.buildId,
    payload: {
      assetId: form.assetId,
      category: form.category,
      description: form.description,
      priority: form.priority,
      contact: form.contact ?? null,
      attachmentIds: attachments.map((item) => item.attachmentId)
    }
  }
}

// FACTORYCARE_UI_GROUP: COMPLETED <- VERIFIED|CLOSED。
// 这是报修人文案分组，不是 WorkOrderStatus，不创造或回写第十三个领域状态。
export function presentStatus(status) {
  if (!statuses.has(status)) return { group: 'UNKNOWN', action: 'REFRESH_OR_UPGRADE' }
  if (['CREATED', 'TRIAGED', 'ASSIGNED', 'ACCEPTED'].includes(status)) return { group: 'ACCEPTED', action: 'WAIT' }
  if (['IN_PROGRESS', 'PENDING_PARTS', 'PENDING_APPROVAL'].includes(status)) return { group: 'PROCESSING', action: 'WAIT' }
  if (status === 'RESOLVED') return { group: 'AWAITING_VERIFICATION', action: 'VERIFY_OR_REJECT' }
  if (['VERIFIED', 'CLOSED'].includes(status)) return { group: 'COMPLETED', action: 'VIEW' }
  if (status === 'REOPENED') return { group: 'PROCESSING', action: 'WAIT' }
  return { group: 'CANCELLED', action: 'VIEW' }
}

export function replay(queueItem, serverResult) {
  if (queueItem.idempotencyKey !== serverResult.idempotencyKey) throw new Error('IDEMPOTENCY_KEY_CHANGED')
  return { state: 'confirmed', reportId: serverResult.reportId, workOrderId: serverResult.workOrderId }
}
