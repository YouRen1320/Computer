// 职责：把平台权限与设备结果归一化成页面可穷尽处理的领域状态。
export function reducePermission(state, event) {
  if (event.type === 'CHECK') {
    if (!event.capabilityAvailable) return { kind: 'unavailable', reason: 'capability' }
    if (event.current === 'granted') return { kind: 'granted' }
    if (event.current === 'blocked') return { kind: 'settings-required', canAskAgain: false }
    return { kind: 'requestable' }
  }
  if (event.type === 'REQUEST' && state.kind === 'requestable') return { kind: 'requesting' }
  if (event.type === 'GRANTED' && state.kind === 'requesting') return { kind: 'granted' }
  if (event.type === 'DENIED' && state.kind === 'requesting') {
    return event.canAskAgain
      ? { kind: 'denied', canAskAgain: true }
      : { kind: 'settings-required', canAskAgain: false }
  }
  if (event.type === 'RETURNED_FROM_SETTINGS') {
    return event.current === 'granted'
      ? { kind: 'granted' }
      : { kind: 'settings-required', canAskAgain: false }
  }
  throw new Error(`INVALID_PERMISSION_TRANSITION:${state.kind}:${event.type}`)
}

export function parseScannedDevice(raw) {
  const normalized = String(raw).trim().toUpperCase()
  if (!/^DEV-[A-Z0-9]{6,20}$/.test(normalized)) return { kind: 'failed', code: 'INVALID_DEVICE_CODE', retryable: false }
  return { kind: 'ok', value: { deviceCode: normalized } }
}

export function validateLocation(value) {
  const valid = Number.isFinite(value.latitude) && value.latitude >= -90 && value.latitude <= 90 &&
    Number.isFinite(value.longitude) && value.longitude >= -180 && value.longitude <= 180 &&
    ['wgs84', 'gcj02'].includes(value.coordinateSystem)
  return valid
    ? { kind: 'ok', value }
    : { kind: 'failed', code: 'INVALID_LOCATION', retryable: false }
}

export function reduceSubmission(state, event) {
  // 映射：附件上传与工单提交是两个阶段，避免把 upload 绿灯当成业务完成。
  if (event.type === 'UPLOAD_STARTED') return { kind: 'uploading', operationId: event.operationId }
  if (event.type === 'UPLOAD_COMPLETED' && state.kind === 'uploading') {
    return { kind: 'attachment-ready', attachmentId: event.attachmentId, operationId: state.operationId }
  }
  if (event.type === 'COMMIT_STARTED' && state.kind === 'attachment-ready') {
    return { kind: 'committing', attachmentId: state.attachmentId, idempotencyKey: event.idempotencyKey }
  }
  if (event.type === 'COMMIT_FAILED' && state.kind === 'committing') {
    return {
      kind: 'commit-failed', attachmentId: state.attachmentId,
      idempotencyKey: state.idempotencyKey, retryable: event.retryable
    }
  }
  if (event.type === 'COMMIT_SUCCEEDED' && state.kind === 'committing') {
    return { kind: 'completed', workOrderId: event.workOrderId, attachmentId: state.attachmentId }
  }
  throw new Error(`INVALID_SUBMISSION_TRANSITION:${state.kind}:${event.type}`)
}
