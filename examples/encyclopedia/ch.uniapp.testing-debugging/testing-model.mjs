// 职责：提供可在普通 Node 环境验证的领域规则和证据完整性判据。
export function validateRepairDraft(input) {
  const errors = {}
  if (!/^DEV-[A-Z0-9]{6,20}$/.test(input.deviceCode)) errors.deviceCode = 'INVALID_DEVICE_CODE'
  if (input.description.trim().length < 10) errors.description = 'DESCRIPTION_TOO_SHORT'
  return { valid: Object.keys(errors).length === 0, errors }
}

export function mapUploadHostResponse(response) {
  const status = Number(response.statusCode)
  if (!Number.isInteger(status)) return { kind: 'contract-error' }
  if (status === 401) return { kind: 'unauthenticated' }
  if (status < 200 || status >= 300) return { kind: 'http-error', status }
  try {
    // 映射：真实宿主可返回 JSON 字符串；运行时解析后仍需最小 schema。
    const body = typeof response.data === 'string' ? JSON.parse(response.data) : response.data
    if (!body || !/^ATT-[0-9]+$/.test(body.attachmentId)) return { kind: 'contract-error' }
    return { kind: 'ok', value: { attachmentId: body.attachmentId } }
  } catch {
    return { kind: 'contract-error' }
  }
}

export function acceptLatest(currentOperationId, response) {
  return response.operationId === currentOperationId
    ? { accepted: true, value: response.value }
    : { accepted: false }
}

export function validateReproBundle(bundle) {
  const required = ['commit', 'target', 'runtimeVersion', 'device', 'os', 'buildId', 'artifactChecksum', 'steps', 'expected', 'actual']
  const missing = required.filter((key) => !bundle[key] || (Array.isArray(bundle[key]) && bundle[key].length === 0))
  if (bundle.claim === 'device-passed' && bundle.carrier !== 'physical-device') missing.push('physical-device-evidence')
  if (bundle.mapBuildId && bundle.mapBuildId !== bundle.buildId) missing.push('source-map-build-id')
  return { valid: missing.length === 0, missing }
}
